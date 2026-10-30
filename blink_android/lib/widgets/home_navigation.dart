
import 'package:flutter/material.dart';

import '../core/nav.dart';
import '../core/theme.dart';
import 'ui.dart';

// =====================================================
// BLINK BRAND COLORS
// =====================================================

const Color _softOrange = Color(0xFFFFEEE3);
const Color _textMuted = BlinkColors.muted;

// =====================================================
// HOME BOTTOM NAVIGATION
//
// Original design preserved:
// - Deep orange background
// - Curved top-left and top-right corners
// - White icons and labels
// - White circular Capture camera button
// - Compact 64px height
// - Subtle selected-tab highlight
//
// Home | Connections | Capture | Reels | Explore
//
// Only shown on Home.
// =====================================================

class BlinkHomeBottomBar extends StatelessWidget {
  const BlinkHomeBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BlinkColors.orangeDark,
      elevation: 8,
      shadowColor: const Color(0x44000000),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _HomeNavItem(
                title: 'Home',
                icon: Icons.home_rounded,
                route: '/home',
                selected: true,
              ),

              _HomeNavItem(
                title: 'Connections',
                icon: Icons.people_alt_outlined,
                route: '/people',
              ),

              _CaptureNavItem(),

              _HomeNavItem(
                title: 'Reels',
                icon: Icons.smart_display_outlined,
                route: '/reels',
              ),

              // UPDATED: IRL -> EXPLORE
              _HomeNavItem(
                title: 'Explore',
                icon: Icons.explore_outlined,
                route: '/explore',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// NORMAL NAVBAR ITEM
// Original design unchanged
// =====================================================

class _HomeNavItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final bool selected;

  const _HomeNavItem({
    required this.title,
    required this.icon,
    required this.route,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: title,
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () {
            if (route != '/home') {
              go(context, route);
            }
          },
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(
                  milliseconds: 180,
                ),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x33FFFFFF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 21,
                ),
              ),

              const SizedBox(height: 4),

              SizedBox(
                width: double.infinity,
                height: 13,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// CENTER CAPTURE BUTTON
// Original design unchanged
// =====================================================

class _CaptureNavItem extends StatelessWidget {
  const _CaptureNavItem();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: 'Capture a moment',
        button: true,
        child: InkWell(
          onTap: () => go(context, '/capture'),
          splashColor: Colors.white24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFB089),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 7,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: BlinkColors.orangeDark,
                  size: 21,
                ),
              ),

              const SizedBox(height: 2),

              const Text(
                'Capture',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// LEFT DRAWER NAVIGATION
//
// Removed items available inside Explore page:
// - Moments
// - Secrets
// - Hearts
// - Check-ins
// - IRL Plans
// - Blink Exchange
// - Creator Tasks
// - Business Match
// - Inbox & Messages
// - BP Wallet
//
// Drawer now contains:
// - Explore All
// - Connections
// - My Profile
// - Settings
//
// Original drawer design preserved.
// =====================================================

class BlinkExploreDrawer extends StatelessWidget {
  const BlinkExploreDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // BRAND LOGO HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                15,
                16,
                17,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BlinkLogo(
                        fontSize: 39,
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  20,
                ),
                children: const [
                  // EXPLORE SECTION
                  _DrawerHeading(
                    'EXPLORE BLINK',
                  ),

                  _DrawerEntry(
                    title: 'Explore all',
                    icon: Icons.explore_rounded,
                    route: '/explore',
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    child: Divider(height: 1),
                  ),

                  // ACCOUNT SECTION
                  _DrawerHeading(
                    'MY BLINK',
                  ),

                  _DrawerEntry(
                    title: 'Connections',
                    icon: Icons.people_outline_rounded,
                    route: '/people',
                  ),

                  _DrawerEntry(
                    title: 'My Profile',
                    icon: Icons.person_outline_rounded,
                    route: '/profile',
                  ),

                  _DrawerEntry(
                    title: 'Settings',
                    icon: Icons.settings_outlined,
                    route: '/settings',
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

// =====================================================
// DRAWER SECTION HEADING
// Original design unchanged
// =====================================================

class _DrawerHeading extends StatelessWidget {
  final String title;

  const _DrawerHeading(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        13,
        10,
        13,
        10,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w900,
          color: BlinkColors.orange,
        ),
      ),
    );
  }
}

// =====================================================
// DRAWER ITEM
// Original design unchanged
// =====================================================

class _DrawerEntry extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;

  const _DrawerEntry({
    required this.title,
    required this.icon,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 3,
      ),
      child: ListTile(
        dense: true,
        minTileHeight: 48,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _softOrange,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: BlinkColors.orange,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 19,
          color: _textMuted,
        ),
        onTap: () {
          final navigator = Navigator.of(context);
          navigator.pop();
          navigator.pushNamed(route);
        },
      ),
    );
  }
}

// =====================================================
// COLORFUL BLINK MESSAGING BUTTON
// Original design unchanged
// =====================================================

class BlinkMessageButton extends StatelessWidget {
  const BlinkMessageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Messages',
      onPressed: () => go(
        context,
        '/inbox',
      ),
      icon: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E8),
          borderRadius: BorderRadius.circular(13),
        ),
        child: CustomPaint(
          size: const Size(29, 29),
          painter: _BlinkChatPainter(),
        ),
      ),
    );
  }
}

// =====================================================
// CUSTOM COLORFUL CHAT BUBBLE
// Original design unchanged
// =====================================================

class _BlinkChatPainter extends CustomPainter {
  const _BlinkChatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFA120),
        Color(0xFFFF5900),
        Color(0xFFED3473),
      ],
    );

    final outline = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(
        size.width * .20,
        size.height * .19,
      )
      ..cubicTo(
        size.width * .37,
        size.height * .04,
        size.width * .66,
        size.height * .04,
        size.width * .81,
        size.height * .19,
      )
      ..cubicTo(
        size.width * .99,
        size.height * .36,
        size.width * .91,
        size.height * .65,
        size.width * .76,
        size.height * .76,
      )
      ..lineTo(
        size.width * .94,
        size.height * .94,
      )
      ..quadraticBezierTo(
        size.width * .71,
        size.height * .91,
        size.width * .58,
        size.height * .82,
      )
      ..cubicTo(
        size.width * .30,
        size.height * .88,
        size.width * .10,
        size.height * .73,
        size.width * .09,
        size.height * .49,
      )
      ..cubicTo(
        size.width * .07,
        size.height * .36,
        size.width * .11,
        size.height * .27,
        size.width * .20,
        size.height * .19,
      )
      ..close();

    canvas.drawPath(path, outline);

    final dots = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    for (final x in <double>[
      .34,
      .50,
      .66,
    ]) {
      canvas.drawCircle(
        Offset(
          size.width * x,
          size.height * .49,
        ),
        2.1,
        dots,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant _BlinkChatPainter oldDelegate,
      ) {
    return false;
  }
}

// =====================================================
// HOME CHECK-INS CARD
// Original design unchanged
// =====================================================

class BlinkHomeCheckins extends StatelessWidget {
  final int activeCount;

  const BlinkHomeCheckins({
    super.key,
    this.activeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        14,
        13,
        14,
        8,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFFFDCC7),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🧡',
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),

                  SizedBox(width: 7),

                  Text(
                    'Check-Ins',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: BlinkColors.ink,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 5),

              Text(
                "What's happening now?",
                style: TextStyle(
                  fontSize: 12,
                  color: BlinkColors.muted,
                ),
              ),
            ],
          );

          final seeAll = TextButton(
            onPressed: () => go(
              context,
              '/checkins',
            ),
            child: Text(
              '$activeCount active · See all →',
              style: const TextStyle(
                fontSize: 11,
                color: BlinkColors.orange,
                fontWeight: FontWeight.w800,
              ),
            ),
          );

          final writeNote = TextButton(
            onPressed: () => go(
              context,
              '/checkin/create',
            ),
            style: TextButton.styleFrom(
              backgroundColor: _softOrange,
              foregroundColor: const Color(0xFFD74A00),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              '+ Write note',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          );

          // Mobile layout prevents overlapping labels.
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: heading,
                    ),
                    Flexible(
                      child: seeAll,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                writeNote,
              ],
            );
          }

          // Wider screen layout.
          return Row(
            children: [
              heading,
              const SizedBox(width: 24),
              writeNote,
              const Spacer(),
              seeAll,
            ],
          );
        },
      ),
    );
  }
}
