
import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'core/nav.dart';
import 'core/blink_auth_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await blinkAppearance.load();
  runApp(const BlinkApp());
}

class BlinkApp extends StatelessWidget {
  const BlinkApp({super.key});

  // Public pages do not require a login.
  static const Set<String> publicRoutes = {
    '/',
    '/onboarding',
    '/login',
    '/register',
    '/forgot',
  };

  // Main swipe navigation follows the current
  // Home / Connections / Reels / Explore arrangement.
  // Capture opens as a separate page.
  static const List<String> mainTabs = [
    '/home',
    '/people',
    '/reels',
    '/explore',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: blinkAppearance,
      builder: (context, child) => MaterialApp(
      title: 'Blink — Your people. Your moments.',
      debugShowCheckedModeBanner: false,
      theme: blinkTheme(),
      themeMode: ThemeMode.light,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final route = settings.name ?? '/';
        final builder = BlinkRoutes.pages[route];

        if (builder == null) {
          return null;
        }

        final fromLeft =
        _NavigationMotion.consumeFromLeft();

        return PageRouteBuilder<void>(
          settings: settings,
          transitionDuration:
          const Duration(milliseconds: 350),
          reverseTransitionDuration:
          const Duration(milliseconds: 280),

          pageBuilder: (
              context,
              animation,
              secondaryAnimation,
              ) {
            final originalPage = builder(context);

            // STARTUP
            // Check saved JWT with NestJS.
            // Valid -> Home
            // Missing/expired -> original Splash screen.
            if (route == '/') {
              return BlinkStartupGate(
                splash: originalPage,
              );
            }

            // Authentication pages remain public.
            if (publicRoutes.contains(route)) {
              return originalPage;
            }

            // Every other route requires real login.
            final protectedPage = BlinkProtected(
              child: originalPage,
            );

            if (mainTabs.contains(route)) {
              return _SwipeNavigation(
                route: route,
                child: protectedPage,
              );
            }

            return protectedPage;
          },

          transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
              ) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final slide = Tween<Offset>(
              begin: Offset(
                fromLeft ? -0.18 : 0.18,
                0,
              ),
              end: Offset.zero,
            ).animate(curved);

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: slide,
                child: child,
              ),
            );
          },
        );
      },
    ),
    );
  }
}

class _NavigationMotion {
  static bool _fromLeft = false;

  static void enterFromLeft() {
    _fromLeft = true;
  }

  static bool consumeFromLeft() {
    final value = _fromLeft;
    _fromLeft = false;
    return value;
  }
}

class _SwipeNavigation extends StatefulWidget {
  final String route;
  final Widget child;

  const _SwipeNavigation({
    required this.route,
    required this.child,
  });

  @override
  State<_SwipeNavigation> createState() =>
      _SwipeNavigationState();
}

class _SwipeNavigationState
    extends State<_SwipeNavigation> {
  double _distance = 0;
  bool _navigating = false;

  void _finishSwipe(double velocity) {
    if (_navigating) return;

    if (_distance.abs() < 75 &&
        velocity.abs() < 650) {
      return;
    }

    final current =
    BlinkApp.mainTabs.indexOf(widget.route);

    if (current < 0) return;

    final direction = _distance.abs() >= 75
        ? (_distance < 0 ? 1 : -1)
        : (velocity < 0 ? 1 : -1);

    final next = current + direction;

    if (next < 0 ||
        next >= BlinkApp.mainTabs.length) {
      return;
    }

    _navigating = true;

    if (direction < 0) {
      _NavigationMotion.enterFromLeft();
    }

    // Preserve back navigation to the previous page.
    go(context, BlinkApp.mainTabs[next]);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _distance = 0;
      },
      onHorizontalDragUpdate: (details) {
        _distance += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        _finishSwipe(details.primaryVelocity ?? 0);
      },
      child: widget.child,
    );
  }
}
