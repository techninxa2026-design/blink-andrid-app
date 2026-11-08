import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Motion semantics shared by *authenticated* Blink screens only.
///
/// Short entrances give spatial continuity, press feedback confirms actions,
/// and platform "remove animations" disables nonessential movement.
class BlinkMotion {
  static bool reduced(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration duration(BuildContext context, {int ms = 360}) =>
    reduced(context) ? Duration.zero : Duration(milliseconds: ms);
}

/// Small, one-shot fade-and-rise. Does not animate the whole scroll tree on
/// each rebuild; it is intentionally limited to high-value content sections.
class BlinkReveal extends StatelessWidget {
  const BlinkReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.distance = 14,
  });

  final Widget child;
  final Duration delay;
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (BlinkMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      duration: BlinkMotion.duration(context, ms: 340) + delay,
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      child: child,
      builder: (context, progress, child) => Opacity(
        opacity: progress.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, distance * (1 - progress)),
          child: child,
        ),
      ),
    );
  }
}

/// Tactile, rounded surface with a generous tap target. Uses only opacity,
/// transform and Material ink, keeping existing navigation/action callbacks.
class BlinkPressable extends StatefulWidget {
  const BlinkPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 22,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final String? semanticLabel;

  @override
  State<BlinkPressable> createState() => _BlinkPressableState();
}

class _BlinkPressableState extends State<BlinkPressable> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final disabledMotion = BlinkMotion.reduced(context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed && !disabledMotion ? .977 : 1,
        duration: BlinkMotion.duration(context, ms: 135),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (pressed) {
              if (mounted && _pressed != pressed) {
                setState(() => _pressed = pressed);
              }
            },
            borderRadius: BorderRadius.circular(widget.radius),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Compact editorial hierarchy for functional sub-sections, with a distinct
/// accent stripe. Avoids repeating a giant banner before every list.
class BlinkSectionBand extends StatelessWidget {
  const BlinkSectionBand({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.icon,
    this.mood = BlinkMood.studio,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 10),
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final IconData? icon;
  final BlinkMood mood;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(mood);
    return BlinkReveal(child: Padding(
      padding: padding,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 4, height: 43,
          decoration: BoxDecoration(
            color: tone, borderRadius: BorderRadius.circular(8))),
        const SizedBox(width: 11),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) Text(eyebrow!.toUpperCase(),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.2, letterSpacing: 1.4,
                fontWeight: FontWeight.w900, color: tone)),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21,
                letterSpacing: -.55, height: 1.15,
                color: BlinkColors.ink, fontWeight: FontWeight.w900)),
            if (subtitle != null) Text(subtitle!,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.3,
                color: BlinkColors.muted)),
          ],
        )),
        if (trailing != null) trailing!
        else if (icon != null)
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, size: 21, color: tone)),
      ]),
    ));
  }
}

/// Actionable loading/empty/error treatment, used with real backend results.
class BlinkExperienceState extends StatelessWidget {
  const BlinkExperienceState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
    this.actionLabel,
    this.mood = BlinkMood.studio,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? action;
  final String? actionLabel;
  final BlinkMood mood;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(mood);
    return BlinkReveal(child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 74, height: 74,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: .10),
            border: Border.all(color: tone.withValues(alpha: .18)),
            borderRadius: BorderRadius.circular(26)),
          child: Icon(icon, color: tone, size: 33)),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center,
          style: const TextStyle(color: BlinkColors.ink,
            fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(subtitle, textAlign: TextAlign.center,
          style: const TextStyle(color: BlinkColors.muted,
            height: 1.5, fontSize: 12.5)),
        if (action != null && actionLabel != null) ...[
          const SizedBox(height: 17),
          FilledButton.icon(
            onPressed: action,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(actionLabel!)),
        ],
      ]),
    )));
  }
}

Color _tone(BlinkMood mood) {
  switch (mood) {
    case BlinkMood.studio: return BlinkColors.orangeDark;
    case BlinkMood.community: return const Color(0xFFE83F6D);
    case BlinkMood.business: return const Color(0xFF1A6470);
    case BlinkMood.exchange: return const Color(0xFF574DB3);
    case BlinkMood.adventure: return const Color(0xFF047F93);
    case BlinkMood.rewards: return const Color(0xFFB1721D);
  }
}
