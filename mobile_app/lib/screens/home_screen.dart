import 'package:flutter/material.dart';
import '../components/app_button.dart';
import '../components/screen_container.dart';
import '../components/section_title.dart';
import '../components/status_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenContainer(
      appBar: AppBar(
        title: const Text('PoseTrack'),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'System Status',
              subtitle: 'Current connection state of devices',
            ),
            const SizedBox(height: 16),
            const StatusCard(
              title: 'Raspberry Pi 4',
              subtitle: 'Connected via WebSocket',
              icon: Icons.memory,
              isConnected: true,
            ),
            const SizedBox(height: 12),
            const StatusCard(
              title: 'AI Server (FastAPI)',
              subtitle: 'YOLOv8 Pose Estimation Active',
              icon: Icons.cloud_done,
              isConnected: true,
            ),
            const SizedBox(height: 32),
            const SectionTitle(
              title: 'Controls',
              subtitle: 'Manage streaming and detection',
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Start Video Stream',
              onPressed: () {
                // Action to start stream
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              text: 'Stop Stream',
              isSecondary: true,
              onPressed: () {
                // Action to stop stream
              },
            ),
          ],
        ),
      ),
    );
  }
}
