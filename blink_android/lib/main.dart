
import 'dart:async';
import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'core/nav.dart';
import 'core/blink_auth_guard.dart';
import 'core/blink_auth_api.dart';
import 'core/live_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await blinkAppearance.load();
  runApp(const BlinkApp());
}

class BlinkApp extends StatefulWidget {
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
  State<BlinkApp> createState() => _BlinkAppState();
}

class _BlinkAppState extends State<BlinkApp> with WidgetsBindingObserver {
  Timer? _presenceTimer;
  bool _foreground = true;
  bool _pinging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_pingPresence());
    });
    _presenceTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(_pingPresence());
    });
  }

  // A heartbeat belongs to the whole foreground app, not only the Inbox:
  // friends appear online while using Moments, Reels or other Blink screens.
  Future<void> _pingPresence() async {
    if (!_foreground || _pinging) return;
    _pinging = true;
    try {
      final token = await BlinkAuthApi.getToken();
      if (token != null && token.isNotEmpty) {
        await LiveApi.call('POST', '/inbox/presence/ping');
      }
    } catch (_) {
      // Presence is optional metadata; old API deployments must not break UI.
    } finally {
      _pinging = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_pingPresence());
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
            if (BlinkApp.publicRoutes.contains(route)) {
              return originalPage;
            }

            // Every other route requires real login.
            final protectedPage = BlinkProtected(
              child: originalPage,
            );

            if (BlinkApp.mainTabs.contains(route)) {
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
