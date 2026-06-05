import 'package:flutter/material.dart';

import '../models/preview_frame_metadata.dart';

/// Web stub: hiển thị placeholder vì browser không hỗ trợ raw TCP socket.
class PiPreviewSocketView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D0D1A),
            const Color(0xFF1A1A2E),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 14),
              Text(
                'Live preview không khả dụng trên PWA',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Browser không hỗ trợ TCP socket.\n'
                'Dùng app native (Android/Windows)\n'
                'trên cùng mạng LAN với Raspberry Pi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
