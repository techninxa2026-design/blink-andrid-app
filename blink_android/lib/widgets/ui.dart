
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
  final Color? color;

  const BlinkLogo({
    super.key,
    this.fontSize = 27,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/final.png',
      height: fontSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Blink',
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
      const BlinkLogo(fontSize: 23),
      const SizedBox(width: 10),
      Container(width: 1, height: 20, color: BlinkColors.line),
      const SizedBox(width: 10),
      Flexible(child: Text(page, overflow: TextOverflow.ellipsis,
        maxLines: 1, style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 15, color: BlinkColors.ink))),
    ],
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
            ? const BlinkLogo()
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
          height: 74,
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
                        const Text(
                          'Capture',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
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
    return SizedBox(
      width: double.infinity,
      height: height,
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
            Text(text),
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

  const SectionHeading(
      this.title, {
        super.key,
        this.subtitle,
        this.action,
      });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.45,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BlinkColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
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
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: BlinkColors.line,
        ),
      ),
      padding: padding,
      child: child,
    );
  }
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
