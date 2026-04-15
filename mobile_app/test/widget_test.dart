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

    await tester.ensureVisible(find.text('Connect Device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect Device'));
    await tester.pumpAndSettle();

    expect(find.text('Device Connection'), findsOneWidget);
    expect(find.text('IoT Link Matrix'), findsOneWidget);
    expect(find.text('Raspberry Pi 4B'), findsOneWidget);
    expect(find.text('Inference Server'), findsOneWidget);
    expect(find.text('Scan'), findsNWidgets(2));
    expect(find.text('Connect'), findsNWidgets(2));
    expect(find.text('Reconnect'), findsNWidgets(2));
  });

  testWidgets('capture route opens the mobile control screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Capture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Capture'));
    await tester.pumpAndSettle();

    expect(find.text('Capture Control'), findsOneWidget);
    expect(find.text('Capture Mode'), findsOneWidget);
    expect(find.text('Recording Duration'), findsOneWidget);
    expect(find.text('Start Recording'), findsOneWidget);
    expect(find.text('Stop Recording'), findsOneWidget);
    expect(find.text('Capture Image'), findsOneWidget);
    expect(find.text('5s'), findsOneWidget);
    expect(find.text('10s'), findsAtLeastNWidgets(1));
    expect(find.text('15s'), findsOneWidget);
  });

  testWidgets('results, history, and settings routes are available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View Results'));
    await tester.tap(find.text('View Results'));
    await tester.pumpAndSettle();

    expect(find.text('Pose Result'), findsOneWidget);
    expect(find.text('Analysis Summary'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Session Timeline'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Network Endpoints'), findsOneWidget);
    expect(find.text('Save Settings'), findsOneWidget);
  });
}
