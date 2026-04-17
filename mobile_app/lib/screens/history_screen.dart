import 'package:flutter/material.dart';

import 'result_sessions_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResultSessionsScreen(
      title: 'History',
      subtitle:
          'Browse processed backend sessions that are already stored and ready for mobile review.',
    );
  }
}
