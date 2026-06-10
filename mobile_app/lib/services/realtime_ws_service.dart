import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/result_models.dart';
import '../config/backend_config.dart';
import 'api_service.dart';

class RealtimeWsService {
  WebSocketChannel? _channel;
  StreamController<FrameResultDetail>? _controller;
  String? _currentSessionId;
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  Stream<FrameResultDetail> subscribe(String sessionId) {
    _isDisposed = false;
    _currentSessionId = sessionId;
    _controller?.close();
    _channel?.sink.close();
    _reconnectTimer?.cancel();

    _controller = StreamController<FrameResultDetail>.broadcast();
    
    _connect(sessionId);

    return _controller!.stream;
  }

  Future<void> _connect(String sessionId) async {
    if (_isDisposed || _currentSessionId != sessionId) return;

    try {
      final apiService = ApiService();
      final settings = await apiService.getSettings();
      
      var host = settings.serverAddress.trim();
      if (host.isEmpty) {
        host = BackendConfig.defaultServerAddress;
      }
      
      // Parse host into WS URL
      if (!host.startsWith('http')) {
        host = 'http://$host';
      }
      final uri = Uri.parse(host);
      final wsHost = uri.host;
      final wsPort = uri.port > 0 ? uri.port : 8002;
      
      final wsUrl = Uri.parse('ws://$wsHost:$wsPort/ws/realtime/$sessionId');
      print('Connecting to Realtime WS at: $wsUrl');
      
      _channel = WebSocketChannel.connect(wsUrl);
      
      _channel!.stream.listen(
        (message) {
          try {
            final jsonMap = jsonDecode(message);
            // Ignore server-side keepalive pings
            if (jsonMap is Map && jsonMap['type'] == 'ping') return;
            final detail = FrameResultDetail.fromJson(sessionId, 0, jsonMap);
            _controller?.add(detail);
          } catch (e) {
            print('Error parsing realtime WS message: $e');
          }
        },
        onError: (error) {
          print('Realtime WS Error: $error');
          _scheduleReconnect(sessionId);
        },
        onDone: () {
          print('Realtime WS Closed (Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason})');
          _scheduleReconnect(sessionId);
        },
      );
    } catch (e) {
      print('Error connecting to Realtime WS: $e');
      _scheduleReconnect(sessionId);
    }
  }

  void _scheduleReconnect(String sessionId) {
    if (_isDisposed || _currentSessionId != sessionId) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      print('Realtime WS Reconnecting...');
      _connect(sessionId);
    });
  }

  void disconnect() {
    _isDisposed = true;
    _currentSessionId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _controller?.close();
    _controller = null;
    _channel?.sink.close();
    _channel = null;
  }
}
