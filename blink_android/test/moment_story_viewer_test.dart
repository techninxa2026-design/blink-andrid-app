import 'package:blink_android/core/blink_home_api.dart';
import 'package:blink_android/screens/blink_moment_story_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final moments = <BlinkMoment>[
    BlinkMoment(
      id: 'one',
      senderId: 'author-one',
      mediaUrl: 'https://example.com/one.jpg',
      mediaType: 'photo',
      createdAt: DateTime.utc(2026, 11, 7),
      author: 'First member',
    ),
    BlinkMoment(
      id: 'two',
      senderId: 'author-two',
      mediaUrl: 'https://example.com/two.jpg',
      mediaType: 'photo',
      createdAt: DateTime.utc(2026, 11, 7),
      author: 'Second member',
    ),
  ];

  for (final size in [
    const Size(280, 568),
    const Size(320, 640),
    const Size(390, 844),
  ]) {
    testWidgets('Moment strip fits ${size.width.toInt()}px mobile screen',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        int? chosen;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(children: [
              const Text('Moments'),
              BlinkMomentStoryStrip(
                moments: moments,
                onOpen: (index) => chosen = index,
              ),
            ]),
          ),
        ));
        await tester.pump();
        expect(find.byKey(const ValueKey('blink-moment-story-strip')),
          findsOneWidget);
        expect(find.byKey(const ValueKey('story-one')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('story-one')));
        expect(chosen, 0);
      },
    );
  }

  testWidgets('full-screen Moment viewer provides all five actions',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(MaterialApp(
          home: BlinkMomentViewer(
            moments: moments,
            viewerId: 'another-member',
          ),
        ));
        await tester.pump();
        expect(find.byTooltip('Like Moment'), findsOneWidget);
        expect(find.byTooltip('Comments'), findsOneWidget);
        expect(find.byTooltip('Give Blink Points'), findsOneWidget);
        expect(find.byTooltip('Share'), findsOneWidget);
        expect(find.byTooltip('React'), findsOneWidget);
        expect(find.byTooltip('Close Moments'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
}
