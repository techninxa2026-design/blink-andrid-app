
import 'package:flutter/material.dart';

import '../core/blink_auth_api.dart';
import '../core/theme.dart';
import '../core/nav.dart';
import '../widgets/ui.dart';

const _orange = BlinkColors.orange;
const _darkOrange = BlinkColors.orangeDark;
const _cream = Color(0xFFFFF8F3);

// =====================================================
// ANIMATION HELPERS
// =====================================================

class _Entrance extends StatelessWidget {
  final Widget child;
  final int delay;

  const _Entrance({
    required this.child,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 650 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 28 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _OrangeButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final IconData? icon;

  const _OrangeButton({
    required this.title,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: _orange.withValues(alpha: .25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 10),
              Icon(icon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// =====================================================
// GET STARTED / SPLASH SCREEN
// =====================================================


class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF9A24),
              Color(0xFFFF6500),
              Color(0xFFDF4100),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -105,
              child: _OutlineCircle(size: 290),
            ),
            Positioned(
              left: -135,
              bottom: 100,
              child: _OutlineCircle(size: 310),
            ),
            const Positioned(
              top: 150,
              left: 27,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Color(0x88FFFFFF),
                size: 33,
              ),
            ),
            const Positioned(
              right: 34,
              bottom: 210,
              child: Icon(
                Icons.star_rounded,
                color: Color(0x99FFFFFF),
                size: 27,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  26, 12, 26, 24,
                ),
                child: Column(
                  children: [
                    const Spacer(),

                    _Entrance(
                      child: Column(
                        children: [
                          // OFFICIAL BLINK LOGO
                          // Transparent background.
                          // No white container.
                          // Slightly bigger.
                          Image.asset(
                            'assets/branding/final.png',
                            height: 95,
                            width: MediaQuery.sizeOf(context)
                                .width *
                                0.78,
                            fit: BoxFit.contain,
                            filterQuality:
                            FilterQuality.high,
                          ),

                          const SizedBox(height: 28),

                          const Text(
                            'Your people.\nYour moments.\nYour Blink.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              height: 1.28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -.5,
                            ),
                          ),

                          const SizedBox(height: 17),

                          const Text(
                            'Connect. Create. Explore. Earn.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xE8FFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    _Entrance(
                      delay: 150,
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: FilledButton(
                              onPressed: () => go(
                                context,
                                '/onboarding',
                                replace: true,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                Colors.white,
                                foregroundColor:
                                _darkOrange,
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(17),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight:
                                      FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          TextButton(
                            onPressed: () => go(
                              context,
                              '/login',
                              replace: true,
                            ),
                            child: const Text(
                              'Already have an account? Sign in',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _OutlineCircle extends StatelessWidget {
  final double size;
  const _OutlineCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0x40FFFFFF),
          width: 2,
        ),
      ),
    );
  }
}

// =====================================================
// ONBOARDING
// =====================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 2) {
      go(context, '/register');
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                24, 14, 24, 6,
              ),
              child: Row(
                children: [
                  const BlinkLogo(fontSize: 34),
                  const Spacer(),
                  if (_page != 2)
                    TextButton(
                      onPressed: () => go(
                        context,
                        '/login',
                        replace: true,
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: _darkOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (value) {
                  setState(() => _page = value);
                },
                children: const [
                  _OnboardPage(
                    title: 'Real connections.\nReal moments.',
                    subtitle:
                    'Share your world, discover your people, '
                        'and make every moment count.',
                    illustration: _FriendsArtwork(),
                    caption: 'Good vibes, together',
                  ),
                  _OnboardPage(
                    title: 'More than just\na social app.',
                    subtitle:
                    'Moments, Reels, Hearts, Secrets and '
                        'opportunities — all in one place.',
                    illustration: _FeaturesArtwork(),
                    caption: 'Everything in your world',
                  ),
                  _OnboardPage(
                    title: 'Connect. Create.\nExplore. Earn.',
                    subtitle:
                    'Discover experiences, join creator tasks '
                        'and earn Blink Points.',
                    illustration: _JourneyArtwork(),
                    caption: 'Your journey begins here',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                25, 6, 25, 14,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final active = index == _page;

                      return AnimatedContainer(
                        duration:
                        const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        width: active ? 29 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? _orange
                              : const Color(0xFFFFD2BA),
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  _OrangeButton(
                    title: _page == 2
                        ? 'Create Your Account'
                        : 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => go(
                      context,
                      '/login',
                      replace: true,
                    ),
                    child: const Text(
                      'Already on Blink? Sign in',
                      style: TextStyle(
                        color: _darkOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget illustration;
  final String caption;

  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24, 18, 24, 4,
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -.8,
              color: BlinkColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: BlinkColors.muted,
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 330,
                  height: 310,
                  child: illustration,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                caption,
                style: const TextStyle(
                  color: BlinkColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================
// ORANGE ILLUSTRATIONS — NO IMAGE ASSETS
// =====================================================

class _FriendsArtwork extends StatelessWidget {
  const _FriendsArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 24,
          top: 22,
          child: Container(
            width: 278,
            height: 258,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFDEC9),
                width: 1.6,
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 20,
          child: Transform.rotate(
            angle: .13,
            child: Container(
              width: 176,
              height: 215,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(27),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F6A3200),
                    blurRadius: 25,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFFB46B),
                            Color(0xFFFF8A3D),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 31,
                      right: 30,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFEDC3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -15,
                      left: -30,
                      child: Transform.rotate(
                        angle: -.5,
                        child: Container(
                          width: 150,
                          height: 100,
                          color: const Color(0xFFE95800),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      right: -20,
                      child: Transform.rotate(
                        angle: .5,
                        child: Container(
                          width: 150,
                          height: 120,
                          color: const Color(0xFFCE4200),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 72,
          child: Transform.rotate(
            angle: -.11,
            child: Container(
              width: 246,
              height: 209,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x206A3200),
                    blurRadius: 23,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                      BorderRadius.circular(20),
                      child: Container(
                        color: const Color(0xFFFFB980),
                        child: const Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment:
                          CrossAxisAlignment.end,
                          children: [
                            _PersonIllustration(
                              skin: Color(0xFF9C6448),
                              shirt: Color(0xFF694534),
                              size: 1,
                            ),
                            _PersonIllustration(
                              skin: Color(0xFFB87955),
                              shirt: Color(0xFFFF6500),
                              size: 1.08,
                            ),
                            _PersonIllustration(
                              skin: Color(0xFFAF7353),
                              shirt: Color(0xFF674335),
                              size: 1,
                            ),
                            _PersonIllustration(
                              skin: Color(0xFFB87955),
                              shirt: Color(0xFFE66C28),
                              size: 1.12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Good vibes, together',
                    style: TextStyle(
                      color: BlinkColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          top: 24,
          left: 17,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: _orange,
            size: 25,
          ),
        ),
        const Positioned(
          right: 3,
          bottom: 22,
          child: Icon(
            Icons.auto_awesome_outlined,
            color: _orange,
            size: 27,
          ),
        ),
      ],
    );
  }
}

class _PersonIllustration extends StatelessWidget {
  final Color skin;
  final Color shirt;
  final double size;

  const _PersonIllustration({
    required this.skin,
    required this.shirt,
    this.size = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46 * size,
      height: 137 * size,
      child: Column(
        children: [
          Container(
            width: 30 * size,
            height: 30 * size,
            decoration: BoxDecoration(
              color: skin,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Container(
              width: 39 * size,
              decoration: BoxDecoration(
                color: shirt,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18 * size),
                  topRight: Radius.circular(18 * size),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesArtwork extends StatelessWidget {
  const _FeaturesArtwork();

  @override
  Widget build(BuildContext context) {
    const features = [
      ('Moments', Icons.camera_alt_rounded),
      ('Reels', Icons.play_circle_fill_rounded),
      ('Secrets', Icons.lock_rounded),
      ('Hearts', Icons.favorite_rounded),
      ('IRL Plans', Icons.people_alt_rounded),
      ('Earn BP', Icons.stars_rounded),
    ];

    return Stack(
      children: [
        Positioned(
          right: 10,
          top: 5,
          child: Container(
            width: 160,
            height: 160,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE9D8),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          left: 14,
          top: 17,
          right: 14,
          bottom: 16,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E6),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFFFFDAC1),
              ),
            ),
            padding: const EdgeInsets.all(13),
            child: Column(
              children: [
                for (int row = 0; row < 3; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (int col = 0; col < 2; col++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: _FeatureTile(
                                title: features[row * 2 + col].$1,
                                icon: features[row * 2 + col].$2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Positioned(
          top: 0,
          right: 4,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: _orange,
            size: 29,
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String title;
  final IconData icon;

  const _FeatureTile({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C7B3400),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5D5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: _orange,
              size: 21,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyArtwork extends StatelessWidget {
  const _JourneyArtwork();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Connect', Icons.people_alt_rounded),
      ('Create', Icons.camera_alt_rounded),
      ('Explore', Icons.explore_rounded),
      ('Earn', Icons.stars_rounded),
    ];

    return Stack(
      children: [
        Positioned(
          top: 15,
          left: 33,
          child: Container(
            width: 255,
            height: 255,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEADB),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 25,
          left: 32,
          right: 32,
          bottom: 18,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(29),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x147A3400),
                  blurRadius: 22,
                  offset: Offset(0, 9),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: i == 3
                                ? _darkOrange
                                : const Color(0xFFFFE9DB),
                            borderRadius:
                            BorderRadius.circular(14),
                          ),
                          child: Icon(
                            steps[i].$2,
                            color: i == 3
                                ? Colors.white
                                : _orange,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            steps[i].$1,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(
                          i == 3
                              ? Icons.stars_rounded
                              : Icons.check_circle_rounded,
                          color: _orange,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Positioned(
          right: 5,
          top: 1,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 26,
            color: _orange,
          ),
        ),
      ],
    );
  }
}

// =====================================================
// SHARED AUTHENTICATION LAYOUT
// =====================================================

class _AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _AuthLayout({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        keyboardDismissBehavior:
        ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            _AuthHero(
              title: title,
              subtitle: subtitle,
            ),
            _Entrance(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  18, 20, 18, 30,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    19, 24, 19, 23,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: const Color(0xFFFFE9D9),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C8A3800),
                        blurRadius: 26,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AuthHero({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        22, topInset + 7, 22, 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF8627),
            Color(0xFFFF5900),
            Color(0xFFE44B00),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  } else {
                    go(
                      context,
                      '/onboarding',
                      replace: true,
                    );
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              const Text(
                'YOUR PEOPLE. YOUR BLINK.',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const BlinkLogo(fontSize: 32),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// FORM COMPONENT
// =====================================================

class _AuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AuthInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: BlinkColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            validator: validator,
            autovalidateMode:
            AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFFFFAF7),
              prefixIcon: Icon(
                icon,
                size: 20,
                color: _orange,
              ),
              suffixIcon: suffix,
              contentPadding:
              const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFFE5D5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFFE5D5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: _orange,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'This field is required';
  }
  return null;
}

String? _email(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Email is required';

  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
      .hasMatch(text)) {
    return 'Enter a valid email address';
  }
  return null;
}

class _AuthFooter extends StatelessWidget {
  final String message;
  final String action;
  final VoidCallback onPressed;

  const _AuthFooter({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          message,
          style: const TextStyle(
            fontSize: 12,
            color: BlinkColors.muted,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(
            action,
            style: const TextStyle(
              color: _darkOrange,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// SIGN IN
// =====================================================


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identity = TextEditingController();
  final _password = TextEditingController();

  bool _showPassword = false;
  bool _busy = false;

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB42318),
      ),
    );
  }

  // ================================================
  // REAL SIGN IN
  // ================================================

  Future<void> _signIn() async {
    if (_busy) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
    });

    try {
      final user = await BlinkAuthApi.login(
        email: _identity.text.trim(),
        password: _password.text,
      );

      if (!mounted) return;

      // The API must return a real authenticated user.
      if (user['id'] is! String) {
        _showError('Login failed. Please try again.');
        return;
      }

      // Only valid backend credentials can reach here.
      go(
        context,
        '/home',
        replace: true,
      );
    } on BlinkAuthException catch (error) {
      // Unknown email and wrong password both return 401.
      // User stays on the login screen.
      _showError(error.message);
    } catch (_) {
      _showError(
        'Unable to sign in. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      title: 'Welcome back!',
      subtitle:
      'Sign in and pick up right where you left off.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign in to Blink',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your world is ready for you.',
              style: TextStyle(
                color: BlinkColors.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 25),

            // The existing backend accepts EMAIL,
            // not username, for authentication.
            _AuthInput(
              controller: _identity,
              label: 'Email address',
              hint: 'Enter your email address',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: _email,
            ),

            _AuthInput(
              controller: _password,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              obscure: !_showPassword,
              validator: _required,
              suffix: IconButton(
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => go(context, '/forgot'),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: _darkOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 13),

            // Same button styling.
            // Repeated requests are blocked by _busy.
            _OrangeButton(
              title: _busy ? 'Signing In...' : 'Sign In',
              icon: Icons.arrow_forward_rounded,
              onPressed: _signIn,
            ),

            const SizedBox(height: 23),

            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  child: Text(
                    'OR CONTINUE WITH',
                    style: TextStyle(
                      color: BlinkColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Google authentication is not enabled '
                            'on the Blink server.',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Color(0xFFFFE2CF),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),
                icon: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _orange,
                  ),
                ),
                label: const Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: BlinkColors.ink,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            _AuthFooter(
              message: "Don't have an account?",
              action: 'Create account',
              onPressed: () => go(
                context,
                '/register',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// SIGN UP
// =====================================================

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _password = TextEditingController();

  bool _showPassword = false;
  bool _accepted = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _emailController.dispose();
    _phoneNumber.dispose();
    _password.dispose();
    super.dispose();
  }

  String _normalizedPhone(String input) {
    return input.trim().replaceAll(
      RegExp(r'[\s()-]'),
      '',
    );
  }

  void _showMessage(
      String message, {
        bool success = false,
      }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success
            ? const Color(0xFF258047)
            : const Color(0xFFB42318),
      ),
    );
  }

  // ================================================
  // REAL REGISTRATION
  // ================================================

  Future<void> _createAccount() async {
    if (_busy) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_accepted) {
      _showMessage(
        'Please accept the Terms and Privacy Policy.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
    });

    final name = _name.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _normalizedPhone(_phoneNumber.text);
    final password = _password.text;

    bool registered = false;

    try {
      // Creates a real MySQL user via NestJS.
      await BlinkAuthApi.register(
        name: name,
        email: email,
        phoneNumber: phone,
        password: password,
      );

      registered = true;

      // The current backend does not return a JWT
      // from /auth/register, so log in immediately.
      await BlinkAuthApi.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created successfully! Please sign in.',
          ),
          backgroundColor: BlinkColors.orange,
        ),
      );

      go(context, '/login', replace: true);
      return;
    } on BlinkAuthException catch (error) {
      if (!mounted) return;

      if (registered) {
        // Registration succeeded but login failed.
        // Do not retry registration and cause a
        // duplicate-email error.
        _showMessage(
          'Account created successfully. '
              'Please sign in to continue.',
          success: true,
        );

        go(context, '/login', replace: true);
        return;
      }

      if (error.statusCode == 409) {
        // Existing email or phone cannot register again.
        _showMessage(error.message);
      } else if (error.statusCode == null) {
        // A network interruption cannot guarantee whether
        // registration completed on the server.
        _showMessage(
          'Could not confirm registration. '
              'Try signing in before registering again.',
        );
      } else {
        _showMessage(error.message);
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Something went wrong. '
            'Please check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      title: 'Join Blink.',
      subtitle:
      'Create your space. Discover your people.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create your account',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              "Let's make something amazing together.",
              style: TextStyle(
                fontSize: 12,
                color: BlinkColors.muted,
              ),
            ),

            const SizedBox(height: 23),

            _AuthInput(
              controller: _name,
              label: 'Full name',
              hint: 'Enter your full name',
              icon: Icons.badge_outlined,
              validator: (value) {
                final name = value?.trim() ?? '';

                if (name.length < 2) {
                  return 'Name must be at least 2 characters';
                }

                if (name.length > 80) {
                  return 'Name must be 80 characters or less';
                }

                return null;
              },
            ),

            _AuthInput(
              controller: _emailController,
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final error = _email(value);
                if (error != null) return error;

                if ((value?.trim().length ?? 0) > 254) {
                  return 'Email address is too long';
                }

                return null;
              },
            ),

            _AuthInput(
              controller: _phoneNumber,
              label: 'Phone number',
              hint: 'Enter your phone number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                final phone =
                _normalizedPhone(value ?? '');

                if (phone.isEmpty) {
                  return 'Phone number is required';
                }

                if (!RegExp(
                  r'^\+?[0-9]{10,15}$',
                ).hasMatch(phone)) {
                  return 'Use 10-15 digits, optionally starting with +';
                }

                return null;
              },
            ),

            _AuthInput(
              controller: _password,
              label: 'Password',
              hint: 'Create a strong password',
              icon: Icons.lock_outline_rounded,
              obscure: !_showPassword,
              suffix: IconButton(
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: (value) {
                final password = value ?? '';

                if (password.length < 8) {
                  return 'Use at least 8 characters';
                }

                if (password.length > 72) {
                  return 'Password must be 72 characters or less';
                }

                return null;
              },
            ),

            // Original Terms and Privacy design.
            InkWell(
              onTap: () {
                setState(() {
                  _accepted = !_accepted;
                });
              },
              child: Row(
                children: [
                  Checkbox(
                    value: _accepted,
                    activeColor: _orange,
                    onChanged: (value) {
                      setState(() {
                        _accepted = value ?? false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'I agree to the Terms of Service and '
                          'Privacy Policy',
                      style: TextStyle(
                        fontSize: 11,
                        color: BlinkColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            _OrangeButton(
              title: _busy
                  ? 'Creating Account...'
                  : 'Create Account',
              icon: Icons.arrow_forward_rounded,
              onPressed: _createAccount,
            ),

            const SizedBox(height: 17),

            _AuthFooter(
              message: 'Already a member?',
              action: 'Sign in',
              onPressed: () => go(
                context,
                '/login',
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// =====================================================
// FORGOT PASSWORD
// =====================================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      title: 'Reset password',
      subtitle:
      "We'll help you get back to your people.",
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEADB),
                borderRadius: BorderRadius.circular(29),
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: _orange,
                size: 56,
              ),
            ),
            const SizedBox(height: 21),
            const Text(
              'Forgot your password?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter your registered email to request '
                  'a password reset link.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: BlinkColors.muted,
              ),
            ),
            const SizedBox(height: 27),
            _AuthInput(
              controller: _emailController,
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType:
              TextInputType.emailAddress,
              validator: _email,
            ),
            const SizedBox(height: 8),
            _OrangeButton(
              title: 'Send Reset Link',
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                if (!_formKey.currentState!.validate()) {
                  return;
                }

                demoToast(
                  context,
                  'Connect Blink password reset API to send the link.',
                );
              },
            ),
            const SizedBox(height: 17),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).canPop()
                    ? Navigator.pop(context)
                    : go(context, '/login', replace: true);
              },
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 17,
              ),
              label: const Text(
                'Back to Sign In',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
