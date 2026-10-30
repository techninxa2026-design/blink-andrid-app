
import 'package:flutter/material.dart';

import 'blink_auth_api.dart';
import 'theme.dart';

class BlinkStartupGate extends StatefulWidget {
  final Widget splash;

  const BlinkStartupGate({
    super.key,
    required this.splash,
  });

  @override
  State<BlinkStartupGate> createState() =>
      _BlinkStartupGateState();
}

class _BlinkStartupGateState extends State<BlinkStartupGate> {
  late Future<Map<String, dynamic>?> _session =
  BlinkAuthApi.currentUser();

  void _retry() {
    setState(() {
      _session = BlinkAuthApi.currentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AuthLoading();
        }

        if (snapshot.hasError) {
          return _AuthConnectionError(
            onRetry: _retry,
            onSignIn: () async {
              await BlinkAuthApi.logout();
              if (!context.mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(
                '/login',
                    (_) => false,
              );
            },
          );
        }

        if (snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context)
                .pushNamedAndRemoveUntil(
              '/home',
                  (_) => false,
            );
          });

          return const _AuthLoading();
        }

        // New user / signed-out user:
        // Show the user's original Splash design.
        return widget.splash;
      },
    );
  }
}

class BlinkProtected extends StatefulWidget {
  final Widget child;

  const BlinkProtected({
    super.key,
    required this.child,
  });

  @override
  State<BlinkProtected> createState() =>
      _BlinkProtectedState();
}

class _BlinkProtectedState extends State<BlinkProtected>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>?> _session =
  BlinkAuthApi.currentUser();

  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retry();
    }
  }

  void _retry() {
    if (!mounted || _redirecting) return;

    setState(() {
      _session = BlinkAuthApi.currentUser();
    });
  }

  void _goToLogin() {
    if (_redirecting) return;
    _redirecting = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
            (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AuthLoading();
        }

        if (snapshot.hasError) {
          return _AuthConnectionError(
            onRetry: _retry,
            onSignIn: () async {
              await BlinkAuthApi.logout();

              if (!context.mounted) return;

              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                    (_) => false,
              );
            },
          );
        }

        if (snapshot.data == null) {
          _goToLogin();
          return const _AuthLoading();
        }

        // Valid session verified by NestJS.
        // Only now display the requested page.
        return widget.child;
      },
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BlinkColors.canvas,
      body: Center(
        child: CircularProgressIndicator(
          color: BlinkColors.orange,
        ),
      ),
    );
  }
}

class _AuthConnectionError extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onSignIn;

  const _AuthConnectionError({
    required this.onRetry,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlinkColors.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 50,
                  color: BlinkColors.orange,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Connection unavailable',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: BlinkColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Blink could not verify your session. '
                      'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BlinkColors.muted,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
                TextButton(
                  onPressed: onSignIn,
                  child: const Text('Sign In Instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
