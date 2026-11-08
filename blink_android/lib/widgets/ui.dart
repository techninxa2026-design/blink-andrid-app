
import 'package:flutter/material.dart';
import 'blink_full_drawer.dart';

import '../core/theme.dart';
import '../core/nav.dart';
import '../core/data.dart';

// ========================================
// OFFICIAL BLINK BRAND LOGO
// ========================================

class BlinkLogo extends StatelessWidget {
  final double fontSize;
  final double? maxWidth;
  final Color? color;

  const BlinkLogo({
    super.key,
    this.fontSize = 27,
    this.maxWidth,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // The official final.png is intentionally wide. An unconstrained Image in
    // an AppBar/Row previously forced siblings off-screen on compact devices.
    final proposed = MediaQuery.sizeOf(context).width * .48;
    final limit = maxWidth ?? 160.0;
    final width = proposed > limit ? limit : proposed;
    return Image.asset(
      'assets/branding/final.png',
      width: width,
      height: fontSize,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Blink official logo',
    );
  }
}

/// Consistent Blink branding on feature pages without losing page context.
/// Uses the same immutable final.png logo as Home, auth and Capture.
class BlinkBrandedTitle extends StatelessWidget {
  const BlinkBrandedTitle(this.page, {super.key});
  final String page;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const BlinkLogo(fontSize: 23, maxWidth: 72),
      const SizedBox(width: 10),
      Container(width: 1, height: 20, color: BlinkColors.line),
      const SizedBox(width: 10),
      Flexible(child: Text(page, overflow: TextOverflow.ellipsis,
        maxLines: 1, style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 15, color: BlinkColors.ink))),
    ],
  );
}

/// A segmented filter that stays usable at narrow widths and larger text
/// scales rather than forcing the screen into a horizontal RenderFlex overflow.
class BlinkAdaptiveSegments<T> extends StatelessWidget {
  const BlinkAdaptiveSegments({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: SegmentedButton<T>(
          showSelectedIcon: false,
          segments: segments,
          selected: selected,
          onSelectionChanged: onChanged,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
      ),
    ),
  );
}

// ========================================
// SHARED SCREEN LAYOUT
// ========================================

class BlinkScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final bool bottom;
  final String active;
  final Widget? trailing;
  final bool showBack;
  final bool logoTitle;
  final Color? background;
  final Widget? floatingActionButton;

  const BlinkScreen({
    super.key,
    required this.title,
    required this.child,
    this.bottom = true,
    this.active = '',
    this.trailing,
    this.showBack = true,
    this.logoTitle = true,
    this.background,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final canBack = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: background ?? Theme.of(context).scaffoldBackgroundColor,
      drawer: const BlinkFullDrawer(),
      appBar: AppBar(
        title: logoTitle
            ? BlinkBrandedTitle(title)
            : Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        leading: showBack && canBack
            ? IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
              )
            : Builder(builder: (scaffoldContext) => IconButton(
                tooltip: 'Open Blink navigation',
                onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                icon: const Icon(Icons.menu_rounded, size: 23),
              )),
        actions: [
          trailing ??
              IconButton(
                onPressed: () => go(context, '/notifications'),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  size: 23,
                ),
              ),
          const SizedBox(width: 3),
        ],
      ),
      body: child,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar:
      bottom ? BlinkBottomBar(active: active) : null,
    );
  }
}

// ========================================
// PROFESSIONAL BOTTOM NAVIGATION
// ========================================

class BlinkBottomBar extends StatelessWidget {
  final String active;

  const BlinkBottomBar({
    super.key,
    this.active = '',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BlinkColors.orangeDark,
      elevation: 10,
      shadowColor: const Color(0x44000000),
      child: SafeArea(
        top: false,
        child: SizedBox(
          // Preserve the camera label even at large accessibility text scales.
          height: MediaQuery.textScalerOf(context).scale(10) > 10
              ? 74 + (MediaQuery.textScalerOf(context).scale(10) - 10)
              : 74,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                title: 'Home',
                route: '/home',
                selected: active == 'home',
              ),
              _NavItem(
                icon: Icons.smart_display_outlined,
                title: 'Reels',
                route: '/reels',
                selected: active == 'reels',
              ),

              // CENTER CAPTURE BUTTON
              Expanded(
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
                          width: 48,
                          height: 48,
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
                                blurRadius: 9,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            color: BlinkColors.orangeDark,
                            size: 25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Capture', maxLines: 1, softWrap: false,
                              style: TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Inbox',
                route: '/inbox',
                selected: active == 'inbox',
              ),
              _NavItem(
                icon: Icons.explore_outlined,
                title: 'Space',
                route: '/explore',
                selected: active == 'explore' || active == 'space',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================
// SINGLE NAV ITEM COMPONENT
// ========================================

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final bool selected;

  const _NavItem({
    required this.icon,
    required this.title,
    required this.route,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: title,
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => go(
            context,
            route,
            replace: true,
          ),
          splashColor: Colors.white24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(
                  milliseconds: 180,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x33FFFFFF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================
// BUTTON
// ========================================

class BlinkButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool outline;
  final IconData? icon;
  final double height;

  const BlinkButton(
      this.text, {
        super.key,
        required this.onPressed,
        this.outline = false,
        this.icon,
        this.height = 47,
      });

  @override
  Widget build(BuildContext context) {
    final scaledMinHeight = MediaQuery.textScalerOf(context).scale(14) * 2 + 18;
    return SizedBox(
      width: double.infinity,
      height: scaledMinHeight > height ? scaledMinHeight : height,
      child: outline
          ? OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: BlinkColors.orange,
          ),
          foregroundColor: BlinkColors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        icon: icon == null
            ? const SizedBox.shrink()
            : Icon(icon, size: 17),
        label: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      )
          : FilledButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 7),
            ],
            Flexible(child: Text(text, maxLines: 2,
              overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

// ========================================
// NETWORK PHOTO
// ========================================

class BlinkPhoto extends StatelessWidget {
  final int id;
  final double? height;
  final double? width;
  final BorderRadius? radius;
  final BoxFit fit;

  const BlinkPhoto({
    super.key,
    required this.id,
    this.height,
    this.width,
    this.radius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(14),
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: Image.network(
          'https://picsum.photos/id/$id/900/1100',
          fit: fit,
          errorBuilder: (context, error, stack) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFA069),
                  Color(0xFF8DC1D2),
                  Color(0xFF465A90),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.landscape_rounded,
              color: Colors.white70,
              size: 68,
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================
// USER AVATAR
// ========================================

class BlinkAvatar extends StatelessWidget {
  final DemoPerson person;
  final double size;
  final bool ring;

  const BlinkAvatar({
    super.key,
    required this.person,
    this.size = 42,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? 2.5 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring
            ? Border.all(
          color: BlinkColors.orange,
          width: 2,
        )
            : null,
      ),
      child: ClipOval(
        child: Image.network(
          'https://i.pravatar.cc/150?img=${person.avatar}',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
            color: BlinkColors.orangeSoft,
            alignment: Alignment.center,
            child: Text(
              person.name.substring(0, 1),
              style: TextStyle(
                color: BlinkColors.orange,
                fontSize: size * .43,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================
// USER LIST ROW
// ========================================

class BlinkUserLine extends StatelessWidget {
  final DemoPerson person;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool ring;

  const BlinkUserLine({
    super.key,
    required this.person,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 2,
      ),
      leading: BlinkAvatar(
        person: person,
        ring: ring,
      ),
      title: Text(
        person.name,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle ?? person.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.5,
          color: BlinkColors.muted,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// ========================================
// SECTION HEADING
// ========================================

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeading(this.title, {
    super.key,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(17, 18, 17, 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 4, height: subtitle == null ? 43 : 65,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [BlinkColors.orange, Color(0xFFFFB17E)]),
          borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(width: 11),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, color: BlinkColors.orange,
              size: 11),
            SizedBox(width: 5),
            Text('YOUR BLINK SPACE',
              style: TextStyle(color: BlinkColors.orangeDark,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3, fontSize: 9)),
          ]),
          const SizedBox(height: 4),
          Text(title,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -.55, color: BlinkColors.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BlinkColors.muted, fontSize: 11.5, height: 1.4)),
          ],
        ],
      )),
      if (action != null) ...[
        const SizedBox(width: 7),
        action!,
      ],
    ]),
  );
}

// ========================================
// PANEL
// ========================================

class BlinkPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;

  const BlinkPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final standard = color == Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: standard ? null : color,
        gradient: standard ? const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFFFAF7)]) : null,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: standard ? const Color(0xFFFFDAC6) : BlinkColors.line,
        ),
        boxShadow: standard ? const [
          BoxShadow(color: Color(0x105A2A10),
            blurRadius: 17, offset: Offset(0, 7)),
        ] : null,
      ),
      padding: padding,
      child: child,
    );
  }
}

// ========================================
// BLINK EDITORIAL SYSTEM — VISUAL IDENTITIES BY FEATURE
// ========================================

enum BlinkMood { studio, community, business, exchange, adventure, rewards }

class BlinkMoodColors {
  static Color primary(BlinkMood mood) {
    switch (mood) {
      case BlinkMood.community: return const Color(0xFFEE3264);
      case BlinkMood.business: return const Color(0xFF1A5564);
      case BlinkMood.exchange: return const Color(0xFF4C61B8);
      case BlinkMood.adventure: return const Color(0xFF007E9C);
      case BlinkMood.rewards: return const Color(0xFFAF6913);
      case BlinkMood.studio: return BlinkColors.orangeDark;
    }
  }

  static List<Color> gradient(BlinkMood mood) {
    switch (mood) {
      case BlinkMood.community:
        return const [Color(0xFF391831), Color(0xFF872B57), Color(0xFFE85C5B)];
      case BlinkMood.business:
        return const [Color(0xFF102B38), Color(0xFF164B58), Color(0xFF2B6E69)];
      case BlinkMood.exchange:
        return const [Color(0xFF222243), Color(0xFF4C4280), Color(0xFFDC754B)];
      case BlinkMood.adventure:
        return const [Color(0xFF083E4E), Color(0xFF126E81), Color(0xFFEE8B5B)];
      case BlinkMood.rewards:
        return const [Color(0xFF382413), Color(0xFF975415), Color(0xFFE2A342)];
      case BlinkMood.studio:
        return const [Color(0xFF271D22), Color(0xFFA83B24), BlinkColors.orange];
    }
  }

  static BlinkMood infer(String? eyebrow) {
    final label = (eyebrow ?? '').toUpperCase();
    if (label.contains('BUSINESS') || label.contains('PROFESSION') ||
        label.contains('NETWORK') || label.contains('MEETING')) {
      return BlinkMood.business;
    }
    if (label.contains('EXCHANGE') || label.contains('NEGOTIAT') ||
        label.contains('OFFER')) return BlinkMood.exchange;
    if (label.contains('IRL') || label.contains('PLAN') ||
        label.contains('MEETUP')) return BlinkMood.adventure;
    if (label.contains('BP') || label.contains('REWARD') ||
        label.contains('WALLET')) return BlinkMood.rewards;
    if (label.contains('HEART') || label.contains('CONNECTION') ||
        label.contains('FRIEND') || label.contains('CHECK') ||
        label.contains('PEOPLE')) return BlinkMood.community;
    return BlinkMood.studio;
  }
}

/// An editorial masthead with typographic hierarchy, non-rectangular
/// ornamental forms and feature-specific hues. It is intentionally different
/// from a generic Card with a shadow. All icons/actions remain accessible.
class BlinkFeatureHero extends StatelessWidget {
  const BlinkFeatureHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.mood = BlinkMood.studio,
    this.action,
    this.margin = const EdgeInsets.fromLTRB(14, 13, 14, 18),
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final BlinkMood mood;
  final Widget? action;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final palette = BlinkMoodColors.gradient(mood);
    return Container(
      margin: margin,
      constraints: const BoxConstraints(minHeight: 158),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: palette),
        boxShadow: [
          BoxShadow(color: palette[1].withValues(alpha: .22),
            blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(right: -48, top: -84,
          child: Container(width: 201, height: 201,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: .17),
                width: 29),
              shape: BoxShape.circle))),
        Positioned(right: -12, bottom: -70,
          child: Transform.rotate(
            angle: -.28,
            child: Container(width: 158, height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(40))))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 19, 18, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(30)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                        child: Text(eyebrow.toUpperCase(),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5, letterSpacing: 1.3,
                            color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white,
                        fontSize: 24, height: 1.09, letterSpacing: -.65,
                        fontWeight: FontWeight.w900)),
                  ],
                )),
                const SizedBox(width: 10),
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .30)),
                    borderRadius: BorderRadius.circular(18)),
                  child: Icon(icon, size: 28, color: Colors.white)),
              ]),
              const SizedBox(height: 10),
              Text(subtitle,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFAF0EC), fontSize: 12,
                  height: 1.45)),
              if (action != null) ...[
                const SizedBox(height: 14),
                action!,
              ],
            ]),
        ),
      ]),
    );
  }
}

// ========================================
// PREMIUM CARD DESIGN SYSTEM
// ========================================

/// Shared elevated surface used across the real, API-backed Blink modules.
/// The glass-warm gradient, subtle border and orange shadow are consistent
/// with the existing Blink Orange design system. Nested actions still work.
class BlinkProCard extends StatelessWidget {
  const BlinkProCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(17),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.mood = BlinkMood.studio,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BlinkMood mood;

  @override
  Widget build(BuildContext context) {
    final accent = BlinkMoodColors.primary(mood);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: .20), width: 1.05),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .085),
            blurRadius: 23, offset: const Offset(0, 10)),
          const BoxShadow(color: Color(0x08000000),
            blurRadius: 7, offset: Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: IgnorePointer(
          child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color.lerp(Colors.white, accent, .035)!,
                Color.lerp(Colors.white, accent, .075)!,
              ],
              stops: const [0, .62, 1],
            ),
          )),
        )),
        Positioned(
          right: -30, top: -42,
          child: IgnorePointer(child: Container(
            width: 94, height: 94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: .085), width: 19)),
          )),
        ),
        Positioned(left: 0, top: 0, bottom: 0,
          child: Container(
            width: 3.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [accent, accent.withValues(alpha: .10)]),
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ]),
    );
  }
}

/// Compact premium metadata label. Wrap multiple chips rather than putting
/// them inside an overflowing fixed-width Row.
class BlinkInfoPill extends StatelessWidget {
  const BlinkInfoPill(this.label, {
    super.key,
    this.icon,
    this.highlight = false,
  });

  final String label;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: highlight ? BlinkColors.orangeSoft : Colors.white,
      border: Border.all(
        color: highlight
          ? const Color(0xFFFFC7A7) : const Color(0xFFF0E3DB)),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 14, color: BlinkColors.orangeDark),
        const SizedBox(width: 5),
      ],
      ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .62),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: BlinkColors.ink,
          ),
        ),
      ),
    ]),
  );
}

/// Styled title, avatar/icon and subtitle plus optional tags, action rows.
/// It makes ordinary ListTiles a polished product card without changing
/// their existing onTap, menus, edit actions or backend interactions.
class BlinkProListCard extends StatelessWidget {
  const BlinkProListCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.badges = const [],
    this.footer,
    this.onTap,
    this.leading,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.mood,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> badges;
  final Widget? footer;
  final VoidCallback? onTap;
  final Widget? leading;
  final EdgeInsetsGeometry margin;
  final BlinkMood? mood;

  @override
  Widget build(BuildContext context) {
    final tone = mood ?? BlinkMoodColors.infer(eyebrow);
    final accent = BlinkMoodColors.primary(tone);
    return BlinkProCard(
    mood: tone,
    onTap: onTap,
    margin: margin,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              accent.withValues(alpha: .20),
              accent.withValues(alpha: .055),
            ]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(9),
              topRight: Radius.circular(19),
              bottomLeft: Radius.circular(19),
              bottomRight: Radius.circular(9)),
            border: Border.all(color: accent.withValues(alpha: .23)),
          ),
          child: Center(child: leading ?? Icon(icon,
            color: accent, size: 25)),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null && eyebrow!.isNotEmpty) ...[
              Text(eyebrow!.toUpperCase(), maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, letterSpacing: 0.9,
                  fontWeight: FontWeight.w800,
                  color: accent)),
              const SizedBox(height: 5),
            ],
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900,
                fontSize: 16, height: 1.23, color: BlinkColors.ink)),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle!.trim(), maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: BlinkColors.muted,
                  height: 1.4, fontSize: 12.5)),
            ],
          ],
        )),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing!,
        ] else if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.arrow_outward_rounded,
            color: accent, size: 20),
        ],
      ]),
      if (badges.isNotEmpty) ...[
        const SizedBox(height: 15),
        Wrap(spacing: 7, runSpacing: 7, children: badges),
      ],
      if (footer != null) ...[
        const SizedBox(height: 13),
        const Divider(height: 1),
        const SizedBox(height: 10),
        footer!,
      ],
    ]),
  );
  }
}

/// Shared visual layout for existing Blink create/edit pages.
/// It adds no routes or screens: editors keep their existing navigation and
/// save logic. The body stays scrollable when the keyboard is open, while the
/// primary action is consistently reachable above the system navigation bar.
class BlinkCreateLayout extends StatelessWidget {
  const BlinkCreateLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
    required this.primaryLabel,
    required this.onSubmit,
    this.busy = false,
    this.progress,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget content;
  final String primaryLabel;
  final VoidCallback? onSubmit;
  final bool busy;
  final Widget? progress;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BlinkColors.canvas,
    resizeToAvoidBottomInset: true,
    appBar: AppBar(title: BlinkBrandedTitle(title)),
    body: SafeArea(
      bottom: false,
      child: LayoutBuilder(builder: (context, size) =>
        SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BlinkFeatureHero(
                    margin: EdgeInsets.zero,
                    eyebrow: 'CREATE ON BLINK',
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    mood: BlinkMood.studio,
                  ),
                  const SizedBox(height: 16),
                  content,
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: BlinkColors.line)),
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (progress != null) ...[
                  progress!,
                  const SizedBox(height: 9),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onSubmit,
                    icon: busy
                        ? const SizedBox(width: 17, height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(primaryLabel,
                        maxLines: 1, softWrap: false,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Consistent compact form dialog for existing in-place create actions.
/// It is intentionally a widget, not a new route or an extra page.
class BlinkFormDialog extends StatelessWidget {
  const BlinkFormDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.actions,
    this.icon = Icons.edit_note_rounded,
  });

  final String title;
  final String subtitle;
  final Widget content;
  final List<Widget> actions;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    titlePadding: const EdgeInsets.fromLTRB(19, 18, 19, 0),
    contentPadding: const EdgeInsets.fromLTRB(19, 14, 19, 8),
    actionsPadding: const EdgeInsets.fromLTRB(15, 5, 15, 14),
    title: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 41, height: 41,
          decoration: BoxDecoration(
            color: BlinkColors.orangeSoft,
            borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: BlinkColors.orange, size: 23),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18,
                fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(
              fontSize: 12, color: BlinkColors.muted)),
          ],
        )),
      ],
    ),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 510),
      child: content,
    ),
    actions: actions,
  );
}

/// White, softly bordered grouping for related inputs in Blink editors.
class BlinkFormSection extends StatelessWidget {
  const BlinkFormSection({
    super.key,
    required this.heading,
    required this.children,
    this.helper,
  });
  final String heading;
  final String? helper;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => BlinkPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children:[
          Container(width:29,height:29,
            decoration:BoxDecoration(
              color:BlinkColors.orangeSoft,
              borderRadius:BorderRadius.circular(10)),
            child:const Icon(Icons.tune_rounded,
              size:17,color:BlinkColors.orangeDark)),
          const SizedBox(width:9),
          Expanded(child:Text(heading,
            style:const TextStyle(
              fontSize:15, fontWeight:FontWeight.w900,
              color:BlinkColors.ink))),
        ]),
        if (helper != null) ...[
          const SizedBox(height: 3),
          Text(helper!, style: const TextStyle(
            color: BlinkColors.muted, fontSize: 12)),
        ],
        const SizedBox(height: 15),
        ...children,
      ],
    ),
  );
}

// ========================================
// FORM FIELD
// ========================================

class BlinkField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final int lines;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  const BlinkField({
    super.key,
    required this.label,
    this.hint = '',
    this.icon,
    this.obscure = false,
    this.lines = 1,
    this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: obscure,
          maxLines: obscure ? 1 : lines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null
                ? null
                : Icon(
              icon,
              size: 19,
              color: BlinkColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ========================================
// FILTER CHIPS
// ========================================

class BlinkChips extends StatefulWidget {
  final List<String> labels;
  final ValueChanged<int>? onChanged;
  final int initial;

  const BlinkChips({
    super.key,
    required this.labels,
    this.initial = 0,
    this.onChanged,
  });

  @override
  State<BlinkChips> createState() => _BlinkChipsState();
}

class _BlinkChipsState extends State<BlinkChips> {
  late int current;

  @override
  void initState() {
    super.initState();
    current = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          widget.labels.length,
              (i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => current = i);
                widget.onChanged?.call(i);
              },
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 160,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: i == current
                      ? BlinkColors.orange
                      : const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  widget.labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: i == current
                        ? Colors.white
                        : const Color(0xFF6D6F76),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================
// OPTION ROW
// ========================================

class BlinkOptionRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final String? detail;
  final Color color;

  const BlinkOptionRow({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.detail,
    this.color = BlinkColors.orange,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 8,
        ),
        child: Row(
          children: [
            Container(
              width: 33,
              height: 33,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (detail != null)
              Text(
                detail!,
                style: const TextStyle(
                  fontSize: 11,
                  color: BlinkColors.muted,
                ),
              ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: BlinkColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================
// SEARCH
// ========================================

class BlinkSearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;

  const BlinkSearchBox({
    super.key,
    this.hint = 'Search people, places, tags...',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 10,
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: const InputDecoration(
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: BlinkColors.muted,
          ),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            vertical: 12,
          ),
        ).copyWith(hintText: hint),
      ),
    );
  }
}

// ========================================
// MOMENT POST CARD
// ========================================

class BlinkPostCard extends StatefulWidget {
  final DemoPost post;

  const BlinkPostCard({
    super.key,
    required this.post,
  });

  @override
  State<BlinkPostCard> createState() =>
      _BlinkPostCardState();
}

class _BlinkPostCardState extends State<BlinkPostCard> {
  bool liked = false;
  bool saved = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: BlinkColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 9, 7),
            child: BlinkUserLine(
              person: people[widget.post.author],
              subtitle: '2h ago',
              trailing: IconButton(
                onPressed: () =>
                    demoToast(context, 'Post options'),
                icon: const Icon(
                  Icons.more_horiz_rounded,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => go(context, '/moment/view'),
            child: BlinkPhoto(
              id: widget.post.photo,
              height: 295,
              radius: BorderRadius.zero,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: liked
                      ? BlinkColors.orange
                      : BlinkColors.ink,
                ),
                onPressed: () {
                  setState(() => liked = !liked);
                },
              ),
              Text(
                widget.post.likes,
                style: const TextStyle(fontSize: 11),
              ),
              IconButton(
                icon: const Icon(
                  Icons.mode_comment_outlined,
                  size: 22,
                ),
                onPressed: () =>
                    go(context, '/moment/comments'),
              ),
              Text(
                widget.post.comments,
                style: const TextStyle(fontSize: 11),
              ),
              IconButton(
                icon: const Icon(
                  Icons.send_outlined,
                  size: 21,
                ),
                onPressed: () => go(context, '/share'),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
                onPressed: () {
                  setState(() => saved = !saved);
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              0,
              14,
              14,
            ),
            child: Text(
              widget.post.caption,
              style: const TextStyle(
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================
// COUNTERS
// ========================================

class BlinkCount extends StatelessWidget {
  final String number;
  final String label;

  const BlinkCount(
      this.number,
      this.label, {
        super.key,
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 19,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: BlinkColors.muted,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

// ========================================
// TAG
// ========================================

class DemoTag extends StatelessWidget {
  final String text;
  final Color color;

  const DemoTag(
      this.text, {
        super.key,
        this.color = BlinkColors.orange,
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ========================================
// SCREEN LIST
// ========================================

class ScreenList extends StatelessWidget {
  final List<Widget> children;

  const ScreenList({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        3,
        16,
        24,
      ),
      children: children,
    );
  }
}

// ========================================
// INFORMATION NOTICE
// ========================================

class DemoNotice extends StatelessWidget {
  final String text;

  const DemoNotice(
      this.text, {
        super.key,
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BlinkColors.orangeSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 17,
            color: BlinkColors.orange,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: BlinkColors.orangeDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
