import 'package:blink_android/core/blink_home_api.dart';
import 'package:blink_android/screens/blink_moment_story_gallery.dart';
import 'package:flutter/material.dart';
import 'package:blink_android/widgets/blink_heart_flight.dart';
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
    testWidgets('four Moment tiles per row in a vertical page at ${size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final many = List<BlinkMoment>.generate(28, (index) => BlinkMoment(
          id: 'moment-$index',
          senderId: 'author-$index',
          mediaUrl: 'https://example.com/$index.jpg',
          mediaType: 'photo',
          createdAt: DateTime.utc(2026, 11, 7),
          author: 'Member $index',
        ));
        int? chosen;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: Text('Moments')),
                BlinkMomentStoryGrid(
                  moments: many,
                  onOpen: (index) => chosen = index,
                ),
              ],
            ),
          ),
        ));
        await tester.pump();
        expect(find.byKey(const ValueKey('blink-moment-story-grid')),
          findsOneWidget);
        final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, 4);
        expect(tester.widgetList<Scrollable>(find.byType(Scrollable))
          .every((s) => s.axisDirection == AxisDirection.down), isTrue);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('story-moment-0')));
        expect(chosen, 0);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
        await tester.pump();
        expect(tester.takeException(), isNull);
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
        final viewer = tester.widget<PageView>(
          find.byKey(const ValueKey('blink-moment-story-viewer')));
        expect(viewer.scrollDirection, Axis.vertical);
        expect(tester.takeException(), isNull);
      },
    );

  testWidgets('tap a grid Moment, swipe up/down and double-tap to love',
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
          viewerId: 'some-other-member',
        ),
      ));
      await tester.pump();
      expect(find.text('1 / 2'), findsOneWidget);
      final pages = find.byKey(const ValueKey('blink-moment-story-viewer'));
      await tester.drag(pages, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.drag(pages, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);

      // The media owns the double tap; single-tap is not required to react.
      // Use the left-center photo area, away from the action rail.
      const mediaPoint = Offset(114, 295);
      await tester.tapAt(mediaPoint);
      await tester.pump(const Duration(milliseconds: 75));
      await tester.tapAt(mediaPoint);
      // The first frame starts the AnimationController ticker; the second
      // frame advances it. A single pump may still report opacity=0.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));

      final flight = find.byKey(
        const ValueKey('blink-moment-heart-flight'));
      expect(flight, findsOneWidget);
      final burst = tester.widget<BlinkHeartFlight>(
        find.ancestor(of: flight, matching: find.byType(BlinkHeartFlight)).first);
      expect(burst.progress.value, greaterThan(0));
      expect(burst.progress.value, lessThan(1));
      expect(burst.origin.dx, closeTo(mediaPoint.dx, 18));
      // The particles move to the right-side Like action, not a random spot.
      expect(burst.destination.dx, greaterThan(210));
      expect(tester.takeException(), isNull);
    },
  );
}
