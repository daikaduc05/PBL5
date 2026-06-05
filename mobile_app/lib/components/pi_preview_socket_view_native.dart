import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/preview_frame_metadata.dart';

/// Native implementation: kết nối TCP socket đến Pi agent để nhận live preview.
/// Chỉ được compile khi build native (Windows, Android, iOS, Linux, macOS).
class PiPreviewSocketView extends StatefulWidget {
  final String? raspberryPiIp;
  final int port;
  final ValueChanged<PreviewFrameMetadata?>? onMetadataChanged;

  const PiPreviewSocketView({
    super.key,
    required this.raspberryPiIp,
    required this.port,
    this.onMetadataChanged,
  });

  @override
  State<PiPreviewSocketView> createState() => _PiPreviewSocketViewState();
}

class _PiPreviewSocketViewState extends State<PiPreviewSocketView> {
  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSubscription;
  Timer? _reconnectTimer;
  final List<int> _buffer = <int>[];
  Uint8List? _frameBytes;
  bool _isConnecting = false;
  bool _handshakeComplete = false;
  String? _statusMessage;
  int _reconnectAttempt = 0;

  @override
  void initState() {
    super.initState();
    _connectIfPossible();
  }

  @override
  void didUpdateWidget(covariant PiPreviewSocketView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raspberryPiIp != widget.raspberryPiIp ||
        oldWidget.port != widget.port) {
      _resetConnection();
      _connectIfPossible();
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _closeSocket();
    super.dispose();
  }

  void _connectIfPossible() {
    final raspberryPiIp = widget.raspberryPiIp?.trim();
    if (raspberryPiIp == null || raspberryPiIp.isEmpty) {
      widget.onMetadataChanged?.call(null);
      setState(() {
        _statusMessage =
            'Set the Raspberry Pi IP in Settings so the app can open the live preview socket.';
      });
      return;
    }
    _connect();
  }

  Future<void> _connect() async {
    if (_isConnecting || _socket != null) return;

    final raspberryPiIp = widget.raspberryPiIp?.trim();
    if (raspberryPiIp == null || raspberryPiIp.isEmpty) return;

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to the Raspberry Pi preview socket...';
    });

    try {
      final socket = await Socket.connect(
        raspberryPiIp,
        widget.port,
        timeout: const Duration(seconds: 2),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      unawaited(socket.done.catchError((Object _) {}));
      socket.add(utf8.encode('POSETRACK_PREVIEW 1\n'));
      await socket.flush();

      _socket = socket;
      _socketSubscription = socket.listen(
        _handleSocketData,
        onDone: _handleSocketDisconnected,
        onError: _handleSocketError,
        cancelOnError: true,
      );

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _reconnectAttempt = 0;
          _statusMessage =
              'Connected to the Pi preview socket. Waiting for the first frame...';
        });
      }
    } on SocketException {
      _handlePreviewFailure(
        _frameBytes == null
            ? 'Preview socket unavailable.'
            : 'Preview link interrupted.',
      );
    } on TimeoutException {
      _handlePreviewFailure(
        _frameBytes == null
            ? 'Preview socket timed out before the first frame arrived.'
            : 'Preview stream timed out.',
      );
    }
  }

  void _handleSocketData(Uint8List data) {
    _buffer.addAll(data);

    while (true) {
      if (!_handshakeComplete) {
        final newlineIndex = _buffer.indexOf(10);
        if (newlineIndex == -1) return;

        final line = utf8.decode(_buffer.sublist(0, newlineIndex)).trim();
        _buffer.removeRange(0, newlineIndex + 1);

        if (line != 'POSETRACK_PREVIEW_OK') {
          _handlePreviewFailure('Unexpected preview handshake response: $line');
          return;
        }

        if (!mounted) return;
        setState(() {
          _handshakeComplete = true;
          _statusMessage =
              'Preview socket connected. Waiting for the first camera frame...';
        });
      }

      if (_buffer.length < 4) return;

      final metadataLength = (_buffer[0] << 24) |
          (_buffer[1] << 16) |
          (_buffer[2] << 8) |
          _buffer[3];

      if (_buffer.length < 4 + metadataLength + 4) return;

      final metadataStart = 4;
      final metadataEnd = metadataStart + metadataLength;
      PreviewFrameMetadata metadata;
      try {
        final metadataJson = utf8.decode(_buffer.sublist(metadataStart, metadataEnd));
        final metadataPayload = json.decode(metadataJson);
        if (metadataPayload is! Map) {
          _handlePreviewFailure('Invalid preview metadata payload.');
          return;
        }
        metadata = PreviewFrameMetadata.fromJson(
            Map<String, dynamic>.from(metadataPayload));
      } on FormatException {
        _handlePreviewFailure('Invalid preview metadata packet.');
        return;
      }

      final imageLengthStart = metadataEnd;
      final imageDataStart = imageLengthStart + 4;
      final imageLength = (_buffer[imageLengthStart] << 24) |
          (_buffer[imageLengthStart + 1] << 16) |
          (_buffer[imageLengthStart + 2] << 8) |
          _buffer[imageLengthStart + 3];

      if (_buffer.length < imageDataStart + imageLength) return;

      final frameBytes = Uint8List.fromList(
          _buffer.sublist(imageDataStart, imageDataStart + imageLength));
      _buffer.removeRange(0, imageDataStart + imageLength);

      if (!mounted) return;
      setState(() {
        _frameBytes = frameBytes;
        _reconnectAttempt = 0;
        _statusMessage = null;
      });
      widget.onMetadataChanged?.call(metadata);
    }
  }

  void _handleSocketDisconnected() {
    _handlePreviewFailure(
        'Preview socket disconnected. Reconnecting to the Raspberry Pi...');
  }

  void _handleSocketError(Object error) {
    _handlePreviewFailure('Preview socket error.');
  }

  void _handlePreviewFailure(String message) {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _closeSocket();
    widget.onMetadataChanged?.call(null);

    if (!mounted) return;

    final reconnectDelay = _nextReconnectDelay();
    setState(() {
      _isConnecting = false;
      _handshakeComplete = false;
      _statusMessage =
          '$message Reconnecting in ${reconnectDelay.inSeconds}s...';
    });
    _scheduleReconnect(reconnectDelay);
  }

  Duration _nextReconnectDelay() {
    _reconnectAttempt += 1;
    if (_reconnectAttempt <= 1) return const Duration(seconds: 1);
    if (_reconnectAttempt == 2) return const Duration(seconds: 2);
    if (_reconnectAttempt == 3) return const Duration(seconds: 4);
    if (_reconnectAttempt == 4) return const Duration(seconds: 8);
    return const Duration(seconds: 12);
  }

  void _scheduleReconnect(Duration delay) {
    if (_reconnectTimer != null) return;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _connectIfPossible();
    });
  }

  void _resetConnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _closeSocket();
    _buffer.clear();
    _frameBytes = null;
    _isConnecting = false;
    _handshakeComplete = false;
    _reconnectAttempt = 0;
    _statusMessage = null;
    widget.onMetadataChanged?.call(null);
  }

  void _closeSocket() {
    final socket = _socket;
    _socket = null;
    if (socket == null) return;
    try {
      socket.destroy();
    } catch (_) {
      // Ignore socket shutdown errors during reconnect/dispose.
    }
  }

  @override
  Widget build(BuildContext context) {
    final raspberryPiIp = widget.raspberryPiIp?.trim();
    if (raspberryPiIp == null || raspberryPiIp.isEmpty) {
      return const _PreviewPlaceholder(
        icon: Icons.videocam_off_rounded,
        title: 'Preview unavailable',
        message:
            'Set the Raspberry Pi IP in Settings so the app can open the live preview socket.',
      );
    }

    if (_frameBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _frameBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          ),
          if (_statusMessage != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: _StatusBar(
                message: _statusMessage!,
                isConnecting: _isConnecting,
              ),
            ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _PreviewPlaceholder(
          icon: _isConnecting
              ? Icons.wifi_tethering_rounded
              : Icons.wifi_find_rounded,
          title: _isConnecting
              ? 'Connecting to Pi preview'
              : 'Waiting for Pi preview',
          message: _statusMessage ??
              'The Raspberry Pi preview socket has not delivered the first frame yet.',
        ),
        if (_isConnecting)
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
      ],
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PreviewPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.white54),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String message;
  final bool isConnecting;

  const _StatusBar({required this.message, required this.isConnecting});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isConnecting
                  ? Icons.sync_rounded
                  : Icons.wifi_tethering_error_rounded,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
