import 'package:flutter/material.dart';
import '../services/mock_pose_tracking_service.dart';
import '../screens/capture_control_screen.dart';
import '../screens/device_connection_screen.dart';
import '../screens/feature_placeholder_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/processing_status_screen.dart';
import '../screens/result_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String deviceConnection = '/device-connection';
  static const String capture = '/capture';
  static const String processing = '/processing';
  static const String results = '/results';
  static const String history = '/history';
  static const String settings = '/settings';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case deviceConnection:
        return MaterialPageRoute(
          builder: (_) => const DeviceConnectionScreen(),
        );
      case capture:
        return MaterialPageRoute(builder: (_) => const CaptureControlScreen());
      case processing:
        final draft = routeSettings.arguments;
        if (draft is CaptureSessionDraft) {
          return MaterialPageRoute(
            builder: (_) => ProcessingStatusScreen(draft: draft),
          );
        }
        return _missingArgumentRoute('Capture session draft');
      case results:
        final result = routeSettings.arguments;
        return MaterialPageRoute(
          builder: (_) => ResultScreen(
            initialResult: result is PoseAnalysisResult ? result : null,
          ),
        );
      case history:
        return MaterialPageRoute(builder: (_) => const HistoryScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${routeSettings.name}'),
            ),
          ),
        );
    }
  }

  static MaterialPageRoute<void> _missingArgumentRoute(String label) {
    return MaterialPageRoute(
      builder: (_) => FeaturePlaceholderScreen(
        title: 'Route Error',
        description: '$label was required to open this screen.',
        icon: Icons.error_outline_rounded,
      ),
    );
  }
}
