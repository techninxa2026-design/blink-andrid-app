import 'package:blink_android/core/theme.dart';
import 'package:blink_android/widgets/blink_motion.dart';
import 'package:blink_android/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in <Size>[
    const Size(280, 610),
    const Size(320, 640),
    const Size(412, 850),
  ]) {
    testWidgets('authenticated motion and action surfaces fit '
      '${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var actionTaps = 0;
      var cardTaps = 0;

      await tester.pumpWidget(MaterialApp(
        theme: blinkTheme(),
        home: Scaffold(
          bottomNavigationBar: const BlinkBottomBar(active: 'explore'),
          body: SingleChildScrollView(
            child: Column(children: [
              const BlinkSectionBand(
                eyebrow: 'THE BLINK COMMUNITY',
                title: 'Something meaningful to explore',
                subtitle: 'Stay in control as you discover your people.',
                mood: BlinkMood.community,
                icon: Icons.people_alt_outlined),
              BlinkProListCard(
                icon: Icons.handshake_outlined,
                eyebrow: 'YOUR CONNECTIONS',
                title: 'A new opportunity',
                subtitle: 'A real Blink feature to open',
                onTap: () => cardTaps++),
              BlinkExperienceState(
                title: 'Nothing here yet',
                subtitle: 'Choose an action to get started.',
                icon: Icons.auto_awesome_outlined,
                action: () => actionTaps++,
                actionLabel: 'Take action'),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Capture'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);

      await tester.tap(find.text('A new opportunity'));
      await tester.pumpAndSettle();
      expect(cardTaps, 1);

      await tester.ensureVisible(find.text('Take action'));
      await tester.tap(find.text('Take action'));
      await tester.pumpAndSettle();
      expect(actionTaps, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion disables nonessential entrance transforms',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Builder(
          builder: (context) {
            expect(BlinkMotion.reduced(context), isTrue);
            expect(BlinkMotion.duration(context), Duration.zero);
            return const BlinkReveal(child: Text('Accessible motion'));
          },
        )),
      )));
      await tester.pump();
      expect(find.text('Accessible motion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
}
