import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/navigation/app_routes.dart';
import 'package:mobile_app/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestApp({String initialRoute = AppRoutes.home}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }

  testWidgets('home dashboard renders core sections and actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('PoseTrack'), findsOneWidget);
    expect(find.text('System Overview'), findsOneWidget);
    expect(find.text('Recent Session'), findsOneWidget);
    expect(find.text('Connect Device'), findsOneWidget);
    expect(find.text('Start Capture'), findsOneWidget);
    expect(find.text('View Results'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('dashboard actions navigate to placeholder routes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Capture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Capture'));
    await tester.pumpAndSettle();

    expect(find.text('Start Capture screen'), findsOneWidget);
    expect(
      find.text(
        'Camera preview, timer controls, and recording actions will live on this mobile screen.',
      ),
      findsOneWidget,
    );
  });
}
