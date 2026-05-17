import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'navigation/app_routes.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent google_fonts from fetching fonts over the network.
  // This avoids a black/blank screen on devices without internet.
  // Fonts will fall back to the device's default if not bundled in assets.
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const PoseTrackApp());
}

class PoseTrackApp extends StatelessWidget {
  const PoseTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PoseTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
