
import 'package:flutter/material.dart';

import '../core/nav.dart';
import '../core/theme.dart';
import 'ui.dart';
import 'blink_motion.dart';

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

  // Keep the legacy Home entrypoint visually and behaviorally consistent with
  // the same five-destination navigation used by the live authenticated app.
  @override
  Widget build(BuildContext context) =>
    const BlinkBottomBar(active: 'home');
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
  const BlinkHomeCheckins({super.key, this.activeCount = 0});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return BlinkReveal(
      child: Container(
        margin: const EdgeInsets.fromLTRB(13, 9, 13, 0),
        padding: const EdgeInsets.fromLTRB(13, 12, 12, 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFFF5EC)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFD7BE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0CC96B36),
              blurRadius: 18,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFAC68), Color(0xFFEF672A)]),
                  borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 22),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Check-Ins',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: BlinkColors.ink,
                        fontSize: 16,
                        letterSpacing: -.2,
                        fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('Share what is happening.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: BlinkColors.muted, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8D9),
                  borderRadius: BorderRadius.circular(15)),
                child: Text('$activeCount ACTIVE',
                  style: const TextStyle(
                    color: BlinkColors.orangeDark,
                    fontSize: 9.2,
                    letterSpacing: .5,
                    fontWeight: FontWeight.w900)),
              ),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => go(context, '/checkin/create'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BlinkColors.orangeSoft,
                    foregroundColor: BlinkColors.orangeDark,
                    elevation: 0,
                    minimumSize: const Size(0, 41),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 19),
                  label: const Text('Write a note',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => go(context, '/checkins'),
                style: TextButton.styleFrom(
                  foregroundColor: BlinkColors.orangeDark,
                  minimumSize: const Size(0, 41),
                  padding: const EdgeInsets.symmetric(horizontal: 9)),
                icon: const Icon(Icons.arrow_outward_rounded, size: 15),
                label: const Text('See all',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
