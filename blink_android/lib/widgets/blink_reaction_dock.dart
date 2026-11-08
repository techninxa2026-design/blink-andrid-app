import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Familiar press-hold-and-slide reactions with an accessible tap alternative.
/// Long-press to reveal, glide over an emoji, then release to select it.
/// Tapping opens the same floating palette so one-handed use works too.
class BlinkReactionDock extends StatefulWidget {
  const BlinkReactionDock({
    super.key,
    required this.child,
    required this.onSelected,
    this.reactions = const ['❤️', '🧡', '😂', '😮', '🔥', '👏'],
    this.currentReaction,
    this.enabled = true,
    this.allowRemove = false,
  });

  final Widget child;
  final ValueChanged<String> onSelected;
  final List<String> reactions;
  final String? currentReaction;
  final bool enabled;
  final bool allowRemove;

  @override
  State<BlinkReactionDock> createState() => _BlinkReactionDockState();
}

class _BlinkReactionDockState extends State<BlinkReactionDock> {
  OverlayEntry? _entry;
  Rect? _barRect;
  int _highlighted = -1;
  bool _dragging = false;

  List<String> get _choices => [
    ...widget.reactions,
    if (widget.allowRemove && widget.currentReaction != null &&
        widget.currentReaction!.isNotEmpty) 'remove',
  ];

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  void _hide() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _barRect = null;
    _highlighted = -1;
    _dragging = false;
  }

  void _choose(String emoji) {
    _hide();
    if (mounted && widget.enabled) widget.onSelected(emoji);
  }

  void _open({bool dragging = false}) {
    if (!widget.enabled || _entry != null || !mounted) return;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject();
    final target = context.findRenderObject();
    if (overlayBox is! RenderBox || target is! RenderBox) return;
    final origin = target.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = MediaQuery.sizeOf(context);
    final choices = _choices;
    if (choices.isEmpty) return;
    final width = math.min(size.width - 16.0, choices.length * 46.0 + 16);
    const height = 64.0;
    final left = (origin.dx + target.size.width / 2 - width / 2)
        .clamp(8.0, math.max(8.0, size.width - width - 8.0)).toDouble();
    final top = (origin.dy - height - 12)
        .clamp(MediaQuery.paddingOf(context).top + 5.0,
          math.max(MediaQuery.paddingOf(context).top + 5.0,
            size.height - height - MediaQuery.paddingOf(context).bottom - 9.0))
        .toDouble();
    _barRect = Rect.fromLTWH(left, top, width, height);
    _dragging = dragging;
    _highlighted = -1;
    _entry = OverlayEntry(builder: (_) {
      final rect = _barRect!;
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hide,
          ),
        ),
        Positioned(
          left: rect.left, top: rect.top, width: rect.width,
          height: rect.height + 12,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              height: rect.height,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF20212D),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: const Color(0x80FFFFFF), width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x80000000),
                    blurRadius: 25, offset: Offset(0, 11)),
                ],
              ),
              child: Row(children: [
                for (int i = 0; i < choices.length; i++)
                  Expanded(child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _choose(choices[i]),
                    child: Center(child: TweenAnimationBuilder<double>(
                      key: ValueKey('reaction-${choices[i]}-${i == _highlighted}'),
                      tween: Tween<double>(
                        begin: 1,
                        end: i == _highlighted ? 1.34 : 1),
                      duration: const Duration(milliseconds: 155),
                      curve: Curves.easeOutBack,
                      builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                      child: Semantics(
                        button: true,
                        label: choices[i] == 'remove'
                          ? 'Remove reaction' : 'React ${choices[i]}',
                        child: Text(choices[i] == 'remove' ? '✕' : choices[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: choices[i] == 'remove'
                            ? 20 : 27, color: Colors.white)),
                      ),
                    )),
                  )),
              ]),
            ),
          ),
        ),
      ]);
    });
    overlay.insert(_entry!);
  }

  void _move(LongPressMoveUpdateDetails details) {
    if (_entry == null || _barRect == null) return;
    final r = _barRect!;
    final pos = details.globalPosition;
    int hovered = -1;
    if (pos.dy >= r.top - 30 && pos.dy <= r.bottom + 27 &&
        pos.dx >= r.left && pos.dx <= r.right) {
      hovered = ((pos.dx - r.left) / (r.width / _choices.length))
        .floor().clamp(0, _choices.length - 1);
    }
    if (hovered != _highlighted) {
      _highlighted = hovered;
      _entry?.markNeedsBuild();
    }
  }

  void _end() {
    if (_entry == null) return;
    if (_dragging && _highlighted >= 0) {
      _choose(_choices[_highlighted]);
    } else {
      _hide();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _open(),
    onLongPressStart: (_) => _open(dragging: true),
    onLongPressMoveUpdate: _move,
    onLongPressEnd: (_) => _end(),
    child: widget.child,
  );
}
