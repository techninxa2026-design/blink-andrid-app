import 'package:blink_android/core/theme.dart';
import 'package:blink_android/widgets/ui.dart';
import 'package:blink_android/widgets/blink_heart_flight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[280, 320, 360, 412]) {
    testWidgets('editorial heroes, identities and cards fit ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(MaterialApp(
          theme: blinkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(body: SingleChildScrollView(
            child: Column(children: const [
              BlinkFeatureHero(
                eyebrow: 'DISCOVER PEOPLE · MAKE CONNECTIONS',
                title: 'People. Purpose. Possibility.',
                subtitle: 'Meet the community and collaborate on meaningful opportunities.',
                icon: Icons.business_center_outlined,
                mood: BlinkMood.business,
              ),
              BlinkProfileMasthead(
                name: 'An extraordinarily long professional profile name',
                bio: 'An introduction that should wrap and remain readable '
                  'on smaller screens with larger system text.',
                avatar: CircleAvatar(child: Icon(Icons.person)),
                stats: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('240 Followers'),
                    Text('12 Friends'),
                  ]),
              ),
              BlinkProListCard(
                icon: Icons.work_outlined,
                eyebrow: 'BUSINESS NETWORK',
                title: 'New opportunity in your community',
                subtitle: 'A description with enough content to test layouts.',
                badges: [
                  BlinkInfoPill('International networking',
                    icon: Icons.public_outlined),
                ],
              ),
            ]),
          )),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
  }

  testWidgets('red heart particle flight paints without gesture interception',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: BlinkHeartFlight(
            progress: AlwaysStoppedAnimation<double>(.45),
            origin: Offset(90, 290),
            destination: Offset(281, 178),
          )),
          const Center(child: Text('Moment media')),
        ]),
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey('blink-moment-heart-flight')),
        findsOneWidget);
      expect(find.text('Moment media'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
}
