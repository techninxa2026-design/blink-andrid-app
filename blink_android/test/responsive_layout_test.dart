import 'package:blink_android/core/theme.dart';
import 'package:blink_android/screens/blink_real_capture.dart';
import 'package:blink_android/screens/auth.dart';
import 'package:blink_android/widgets/blink_full_drawer.dart';
import 'package:blink_android/widgets/home_navigation.dart';
import 'package:blink_android/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geometry regression tests: Flutter throws a rendering exception whenever
/// a RenderFlex overflows, so these exercise compact Android viewports and
/// larger accessibility text rather than relying on a visual mockup alone.
void main() {
  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // Preserve the real View's width/insets while overriding font scaling.
  // A MediaQueryData constructed with no size would incorrectly report 0px.
  Widget app(Widget child, {double scale = 1}) => MaterialApp(
    theme: blinkTheme(),
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale)),
      child: page ?? const SizedBox.shrink(),
    ),
    home: child,
  );

  for (final width in [280.0, 320.0, 360.0, 412.0]) {
    testWidgets('main navigation and Check-In tile fit at ${width.toInt()}px',
        (tester) async {
      await setViewport(tester, Size(width, 680));
      await tester.pumpWidget(app(
        Scaffold(
          bottomNavigationBar: const BlinkBottomBar(active: 'home'),
          body: SingleChildScrollView(
            child: Column(children: [
              const BlinkHomeCheckins(activeCount: 12345),
              const SizedBox(height: 12),
              const BlinkAdaptiveSegments<String>(
                segments: [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'friends', label: Text('Friends')),
                  ButtonSegment(value: 'mine', label: Text('Mine')),
                ],
                selected: {'all'},
                onChanged: _noopSegments,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: BlinkButton(
                  'Publish Check-In with a longer label',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {},
                ),
              ),
            ]),
          ),
        ),
        scale: 1.7,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('five-tab home bar and drawer adapt to compact screen',
      (tester) async {
    await setViewport(tester, const Size(280, 610));
    final key = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(app(
      Scaffold(
        key: key,
        drawer: const BlinkFullDrawer(),
        bottomNavigationBar: const BlinkHomeBottomBar(),
        body: const Center(child: Text('Home')),
      ),
      scale: 1.8,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    key.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Your world, one moment at a time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Capture controls do not overflow compact viewport', (tester) async {
    await setViewport(tester, const Size(320, 568));
    await tester.pumpWidget(app(
      const BlinkRealCaptureScreen(),
      scale: 1.5,
    ));
    // The camera plugin is not available in widget tests. The fallback UI
    // must remain stable and usable without a camera.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Photo'), findsWidgets);
    expect(find.text('Video'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash and onboarding never overflow on a compact phone',
      (tester) async {
    await setViewport(tester, const Size(280, 520));
    await tester.pumpWidget(app(const SplashScreen(), scale: 1.6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(const OnboardingScreen(), scale: 1.6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('branded AppBar title handles long page names at 280px',
      (tester) async {
    await setViewport(tester, const Size(280, 568));
    await tester.pumpWidget(app(
      Scaffold(
        appBar: AppBar(
          title: const BlinkBrandedTitle('Business Professional Dashboard'),
          actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert))],
        ),
        body: const SizedBox.shrink(),
      ),
      scale: 1.7,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void _noopSegments(Set<String> selected) {}
