import 'package:blink_android/core/theme.dart';
import 'package:blink_android/screens/blink_vector_lenses.dart';
import 'package:blink_android/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('appearance choice persists and restores exactly like Web theme', () async {
    SharedPreferences.setMockInitialValues({});
    await blinkAppearance.load();
    expect(blinkAppearance.mode, ThemeMode.light);
    await blinkAppearance.choose(ThemeMode.dark);
    expect(blinkAppearance.mode, ThemeMode.dark);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('blink-theme'), 'dark');
    await blinkAppearance.load();
    expect(blinkAppearance.mode, ThemeMode.dark);
    await blinkAppearance.choose(ThemeMode.light);
    expect(stored.getString('blink-theme'), 'light');
  });

  for (final lens in [
    'cat', 'dog', 'butterfly', 'heart', 'crown',
    'glasses', 'cyber', 'blush', 'party'
  ]) {
    testWidgets('vector Moment lens $lens paints safely', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: SizedBox(width: 320,height: 540,
          child: CustomPaint(painter: BlinkVectorLens(
            face: const Rect.fromLTRB(.2,.2,.8,.65),
            lens: lens))),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [280.0, 320.0, 390.0]) {
    testWidgets('dark-mode shared cards remain responsive at $width',
      (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        theme: blinkTheme(),
        darkTheme: blinkDarkTheme(),
        themeMode: ThemeMode.dark,
        home: Scaffold(body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: const [
              BlinkProListCard(
                title: 'Your Blink business network',
                subtitle: 'Real meetings and connection requests',
                icon: Icons.handshake_outlined),
              BlinkFormSection(
                heading: 'Secret answer options',
                children: [
                  TextField(decoration: InputDecoration(labelText:'Answer')),
                ]),
            ]),
          ))),
      ));
      await tester.pump();
      expect(find.text('Your Blink business network'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
