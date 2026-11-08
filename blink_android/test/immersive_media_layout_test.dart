import 'package:blink_android/core/blink_home_api.dart';
import 'package:blink_android/core/theme.dart';
import 'package:blink_android/screens/reels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reel = BlinkReel(
    id: 'layout-check-reel',
    authorId: 'creator',
    authorName: 'An especially long Blink creator profile name',
    videoUrl: 'https://example.invalid/layout-video.mp4',
    thumbnailUrl: 'https://example.invalid/layout-cover.jpg',
    caption: 'A well-written long Reel caption should never take over the '
        'whole video or collide with the gesture controls. '
        'People should be able to read more or collapse it.',
    reactionCount: 125,
    commentCount: 32,
    views: 1000,
  );

  for (final width in <double>[280, 320, 390]) {
    testWidgets('media-first Reel controls fit ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        theme: blinkTheme(),
        home: const Scaffold(body: ReelFullScreen(
          reel: reel,
          myUserId: 'viewer',
          active: false,
        )),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('blink-reel-immersive-media')),
          findsOneWidget);
      expect(find.byTooltip('Mute Reel'), findsOneWidget);
      expect(find.text('Read more'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Read more'));
      await tester.pump();
      expect(find.text('Show less'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
