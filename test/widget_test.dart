import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yoga_day_app/main.dart';
import 'package:yoga_day_app/providers/language_provider.dart';

void main() {
  testWidgets('Yoga App Splash Screen Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const YogaApp(),
      ),
    );

    // Verify splash screen renders title or key widgets
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
