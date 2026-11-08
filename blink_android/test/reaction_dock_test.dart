import 'package:blink_android/widgets/blink_reaction_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[280, 320, 390]) {
    testWidgets('tap reaction dock remains usable at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 620);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        String? selected;
        await tester.pumpWidget(MaterialApp(home: Scaffold(
          body: Center(child: BlinkReactionDock(
            onSelected: (value) => selected = value,
            child: const SizedBox(width: 50, height: 50,
              child: Icon(Icons.favorite_border_rounded)),
          )),
        )));
        await tester.tap(find.byIcon(Icons.favorite_border_rounded));
        await tester.pumpAndSettle();
        expect(find.text('❤️'), findsOneWidget);
        expect(find.text('😂'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('😂'));
        await tester.pumpAndSettle();
        expect(selected, '😂');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('hold, slide to emoji, release selects reaction',
    (tester) async {
      tester.view.physicalSize = const Size(360, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      String? selected;
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: Center(child: BlinkReactionDock(
          onSelected: (value) => selected = value,
          child: const SizedBox(width: 50, height: 50,
            child: Icon(Icons.favorite_border_rounded)),
        )),
      )));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.favorite_border_rounded)));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('🔥'), findsOneWidget);
      await gesture.moveTo(tester.getCenter(find.text('🔥')));
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, '🔥');
      expect(tester.takeException(), isNull);
    });
}
