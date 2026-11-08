import 'package:blink_android/widgets/home_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[280, 320, 390, 440]) {
    testWidgets('Home Check-Ins stays usable and unclipped at ${width.toInt()}px',
      (tester) async {
      tester.view.physicalSize = Size(width, 660);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlinkHomeCheckins(activeCount: 3)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Check-Ins'), findsOneWidget);
      expect(find.text('3 ACTIVE'), findsOneWidget);
      expect(find.text('Write a note'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
    });
  }
}
