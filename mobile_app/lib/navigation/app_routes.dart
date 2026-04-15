import 'package:flutter/material.dart';
import '../screens/device_connection_screen.dart';
import '../screens/feature_placeholder_screen.dart';
import '../screens/home_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String deviceConnection = '/device-connection';
  static const String capture = '/capture';
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
        return MaterialPageRoute(
          builder: (_) => const FeaturePlaceholderScreen(
            title: 'Start Capture',
            description:
                'Camera preview, timer controls, and recording actions will live on this mobile screen.',
            icon: Icons.play_circle_fill_rounded,
          ),
        );
      case results:
        return MaterialPageRoute(
          builder: (_) => const FeaturePlaceholderScreen(
            title: 'View Results',
            description:
                'Processed pose overlays, confidence analytics, and saved outputs are scaffolded for this route.',
            icon: Icons.analytics_rounded,
          ),
        );
      case history:
        return MaterialPageRoute(
          builder: (_) => const FeaturePlaceholderScreen(
            title: 'History',
            description:
                'Session timeline cards and quick access to older captures will be connected here.',
            icon: Icons.history_rounded,
          ),
        );
      case settings:
        return MaterialPageRoute(
          builder: (_) => const FeaturePlaceholderScreen(
            title: 'Settings',
            description:
                'Network settings, default capture preferences, and upload options can be added on this screen.',
            icon: Icons.settings_suggest_rounded,
          ),
        );
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
}
