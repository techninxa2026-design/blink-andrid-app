import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../core/blink_home_api.dart';
import '../core/blink_original_music.dart';
import '../core/live_api.dart';
import '../core/theme.dart';
import '../widgets/blink_heart_flight.dart';
import '../widgets/blink_reaction_dock.dart';
import 'dart:ui' show ImageFilter;

class BlinkLiveMomentCard extends StatefulWidget {
  const BlinkLiveMomentCard({
    super.key,
    required this.moment,
    required this.myUserId,
    this.onDeleted,
    this.immersive = false,
    this.active = true,
  });
  final BlinkMoment moment;
  final String myUserId;
  final VoidCallback? onDeleted;
  /// Full-screen, swipeable Moment viewer with web-parity interaction rail.
  final bool immersive;
  /// Keeps off-screen story videos paused when swiping between Moments.
  final bool active;

  @override
  State<BlinkLiveMomentCard> createState() => _BlinkLiveMomentCardState();
}

class _BlinkLiveMomentCardState extends State<BlinkLiveMomentCard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _activity;
  VideoPlayerController? _video;
  BlinkOriginalPlayer? _soundtrack;
  bool _soundtrackPlaying = false;
  bool _saved = false;
  bool _busy = false;
  bool _captionExpanded = false;
  bool _chromeVisible = true;
  // Activity and media failures are independent: valid Moments stay visible.
  String? _videoError;

  // Instagram-style double-tap feedback is deliberately separate from the
  // backend reaction state, so the heart animation runs immediately.
  late final AnimationController _loveController;
  final GlobalKey _likeActionKey = GlobalKey(debugLabel: 'Blink Moment Like');
  Offset? _loveTapPoint;
  Offset? _loveDestination;

  @override
  void initState() {
    super.initState();
    _loveController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1120));
    _loadActivity();
    _loadSaved();
    if (widget.moment.mediaType == 'video') _initVideo();
  }

  @override
  void didUpdateWidget(covariant BlinkLiveMomentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.immersive || widget.active == oldWidget.active) return;
    final video = _video;
    if (video != null && video.value.isInitialized) {
      if (widget.active) {
        video.play();
      } else {
        video.pause();
      }
    }
  }

  Future<void> _initVideo() async {
    final video = VideoPlayerController.networkUrl(Uri.parse(BlinkHomeApi.mediaUrl(widget.moment.mediaUrl)));
    _video = video;
    try {
      await video.initialize();
      await video.setLooping(true);
      if (widget.immersive && widget.active && mounted) await video.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _videoError = 'Could not play this video.');
    }
  }

  Future<void> _loadActivity() async {
    try {
      final activity = await BlinkHomeApi.activity(widget.moment.id);
      if (mounted) setState(() => _activity = activity);
    } catch (error) {
      // Activity is optional metadata. A temporary 404/timeout must never
      // label a valid public Moment as expired or unavailable.
      debugPrint('Blink Moment activity ${widget.moment.id}: $error');
    }
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _saved = prefs.getBool('blink_saved_${widget.moment.id}') ?? false);
  }

  Future<void> _toggleSave() async {
    final prefs = await SharedPreferences.getInstance();
    final value = !_saved;
    await prefs.setBool('blink_saved_${widget.moment.id}', value);
    if (!mounted) return;
    setState(() => _saved = value);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? 'Saved on this device' : 'Removed from saved items')));
  }

  Future<void> _like() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Same endpoint and same toggle behavior as the Blink web Like button.
      await BlinkHomeApi.react(widget.moment.id, '❤️');
      await _loadActivity();
    } catch (error) {
      _notify('Could not like this Moment: ${BlinkHomeApi.momentActionError(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Double tapping any Moment media gives ❤️, never toggles it OFF.
  /// The normal heart button intentionally retains the web's toggle behavior.
  Future<void> _doubleTapLove() async {
    if (!widget.active || !mounted) return;
    final destination = _likeControlPosition();
    setState(() {
      _loveDestination = destination;
    });
    _loveController.forward(from: 0);
    if (_busy || _activity?['myReaction'] == '❤️') return;

    final previous = _activity == null
        ? null : Map<String, dynamic>.from(_activity!);
    final priorEmoji = (_activity?['myReaction'] ?? '').toString();
    final total = _activity?['reactionTotal'];
    final count = total is num ? total.toInt()
        : int.tryParse(total?.toString() ?? '') ?? 0;

    // Show the selected ❤️ and updated count immediately, then reconcile
    // with Blink's existing POST /moments/:id/react endpoint.
    setState(() {
      _busy = true;
      _activity = {
        if (_activity != null) ..._activity!,
        'myReaction': '❤️',
        'reactionTotal': count + (priorEmoji.isEmpty ? 1 : 0),
      };
    });

    try {
      // If metadata wasn't loaded yet, check the real reaction first:
      // Blink's API uses a toggle, and repeated double taps must not unlove.
      if (previous == null) {
        try {
          final latest = await BlinkHomeApi.activity(widget.moment.id);
          if (!mounted) return;
          if ((latest['myReaction'] ?? '').toString() == '❤️') {
            setState(() => _activity = latest);
            return;
          }
        } catch (error) {
          debugPrint('Moment love metadata unavailable: $error');
        }
      }
      await BlinkHomeApi.react(widget.moment.id, '❤️');
      if (mounted) await _loadActivity();
    } catch (error) {
      if (mounted) {
        setState(() => _activity = previous);
        _notify('Could not love this Moment: '
          '${BlinkHomeApi.momentActionError(error)}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Measure the Like control after its frame has been laid out, at gesture
  /// time. Never call localToGlobal() from a LayoutBuilder layout callback.
  Offset _likeControlPosition() {
    final fallback = Offset(
      MediaQuery.sizeOf(context).width - 41,
      MediaQuery.sizeOf(context).height * .33,
    );
    try {
      final root = context.findRenderObject();
      final target = _likeActionKey.currentContext?.findRenderObject();
      if (root is RenderBox && target is RenderBox &&
          root.hasSize && target.hasSize) {
        return root.globalToLocal(
          target.localToGlobal(target.size.center(Offset.zero)));
      }
    } catch (error) {
      debugPrint('Blink love target calculation: $error');
    }
    return fallback;
  }

  Widget _loveBurst() => Positioned.fill(
    child: LayoutBuilder(builder: (context, space) => BlinkHeartFlight(
      progress: _loveController,
      origin: _loveTapPoint ??
        Offset(space.maxWidth * .5, space.maxHeight * .5),
      destination: _loveDestination ??
        Offset(space.maxWidth - 41, space.maxHeight * .33),
    )),
  );

  Future<void> _reaction() async {
    if (_busy) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 15,
            children: ['❤️', '🧡', '😂', '😮', '🔥', '👏'].map((emoji) =>
              InkWell(onTap: () => Navigator.pop(context, emoji), child: Padding(
                padding: const EdgeInsets.all(8), child: Text(emoji, style: const TextStyle(fontSize: 31)),
              )),
            ).toList(),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await _applyReaction(selected);
  }

  Future<void> _applyReaction(String selected) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await BlinkHomeApi.react(widget.moment.id, selected);
      await _loadActivity();
    } catch (e) {
      _notify(BlinkHomeApi.momentActionError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _comments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _BlinkMomentComments(
        momentId: widget.moment.id,
        myUserId: widget.myUserId,
      ),
    );
    if (mounted) await _loadActivity();
  }

  Future<void> _share() async {
    final media = BlinkHomeApi.mediaUrl(widget.moment.mediaUrl);
    if (media.isEmpty) return;
    try {
      await SharePlus.instance.share(ShareParams(text: '${widget.moment.caption ?? 'A Blink Moment'}\n$media'));
    } catch (e) {
      _notify('Sharing unavailable: $e');
    }
  }


  Future<void> _viewers() async {
    try {
      final result = await BlinkHomeApi.request('GET', '/moments/' + Uri.encodeComponent(widget.moment.id) + '/views');
      if (!mounted) return;
      final viewers = result is List ? result : (result is Map ? (result['viewers'] is List ? result['viewers'] as List : <dynamic>[]) : <dynamic>[]);
      await showModalBottomSheet<void>(context: context, isScrollControlled: true,
        builder: (ctx) => SafeArea(child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .55,
          child: Column(children: [
            const Padding(padding: EdgeInsets.all(17), child: Text('Moment viewers', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            Expanded(child: viewers.isEmpty
              ? const Center(child: Text('No viewers yet'))
              : ListView.builder(itemCount: viewers.length, itemBuilder: (_, i) {
                  final v = obj(viewers[i]);
                  return ListTile(leading: liveAvatar(v, radius: 21),
                    title: Text(field(v, 'name', 'Blink member')),
                    subtitle: Text(field(v, 'viewedAt')));
                })),
          ]),
        )));
    } catch (e) { _notify('Unable to load viewers: $e'); }
  }

  /// Same free BP gift choices as web. The server only credits the Moment
  /// owner and records a gift; no points are deducted from the sender.
  Future<void> _giftBp() async {
    if (widget.myUserId == widget.moment.senderId || _busy) return;
    // Never block a free gift on a balance/activity lookup. The public
    // Moment itself and the backend gift endpoint are the source of truth.
    if (_activity == null) unawaited(_loadActivity());
    if (!mounted) return;
    final amounts = BlinkHomeApi.momentGiftChoices;
    int selected = 5;
    bool sending = false;
    String? error;
    final rawBalance = _activity?['myBalance'];
    final earned = rawBalance is num
        ? rawBalance.toDouble()
        : double.tryParse('$rawBalance');

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: BlinkColors.surface,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BLINK MOMENTS', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w900,
                        letterSpacing: 1.6, color: BlinkColors.orangeDark)),
                      const SizedBox(height: 5),
                      Text('Give Blink Points', style:
                        Theme.of(sheetContext).textTheme.titleLarge),
                    ],
                  )),
                  IconButton.filledTonal(
                    tooltip: 'Close',
                    onPressed: sending ? null : () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
                const Divider(height: 27),
                const Text('🧡', style: TextStyle(fontSize: 58)),
                const SizedBox(height: 10),
                const Text('Appreciate this Moment by sending Blink Points.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: BlinkColors.muted)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  decoration: BoxDecoration(
                    color: BlinkColors.orangeSoft,
                    borderRadius: BorderRadius.circular(13)),
                  child: Row(children: [
                    const Expanded(child: Text('Your earned BP',
                      style: TextStyle(color: BlinkColors.ink))),
                    Text('${earned?.toStringAsFixed(1) ?? '—'} BP', style:
                      const TextStyle(color: BlinkColors.orangeDark,
                        fontWeight: FontWeight.w900)),
                  ]),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: amounts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisExtent: 50,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8),
                  itemBuilder: (_, i) {
                    final amount = amounts[i];
                    final chosen = amount == selected;
                    return OutlinedButton(
                      onPressed: sending ? null : () => update(() => selected = amount),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: chosen ? BlinkColors.orangeSoft : Colors.white,
                        side: BorderSide(
                          color: chosen ? BlinkColors.orange : BlinkColors.line,
                          width: chosen ? 1.5 : 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11))),
                      child: Text('$amount BP', style: TextStyle(
                        color: chosen ? BlinkColors.orangeDark : BlinkColors.ink,
                        fontWeight: chosen ? FontWeight.w800 : FontWeight.w500)),
                    );
                  },
                ),
                if (error != null) Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 11),
                  child: Text(
                    'Free appreciation: the creator earns BP, and your BP is not deducted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BlinkColors.muted, fontSize: 12)),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: sending ? null : () async {
                      update(() { sending = true; error = null; });
                      try {
                        await BlinkHomeApi.giftFreeBp(
                          momentId: widget.moment.id,
                          creatorId: widget.moment.senderId,
                          senderId: widget.myUserId,
                          amount: selected,
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        _notify('Creator earned $selected BP. Your BP was not deducted.');
                        unawaited(_loadActivity());
                      } catch (failure) {
                        if (sheetContext.mounted) update(() {
                          error = BlinkHomeApi.momentActionError(failure);
                          sending = false;
                        });
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: BlinkColors.orange,
                      disabledBackgroundColor: const Color(0xFFFFBB91),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48)),
                    child: Text(sending ? 'Sending BP...' : 'Send $selected BP'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareToInbox() async {
    try {
      final users = arr(await LiveApi.call('GET', '/inbox/friends'));
      if (!mounted) return;
      if (users.isEmpty) { _notify('Add a Blink friend to share Moments.'); return; }
      final friend = await showModalBottomSheet<Map<String,dynamic>>(context: context, builder: (ctx) =>
        SafeArea(child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('Share Moment to Blink Inbox')),
          ...users.map((u) => ListTile(
            leading: liveAvatar(u), title: Text(field(u, 'name')),
            onTap: () => Navigator.pop(ctx, obj(u)),
          )),
        ])));
      if (friend == null || !mounted) return;
      final conversation = obj(await LiveApi.call('POST', '/inbox/conversations',
        {'friendId': field(friend, 'id')}));
      final id = field(conversation, 'conversationId');
      if (id.isEmpty) throw const LiveApiError('Unable to open conversation.');
      await LiveApi.call('POST', '/inbox/conversations/' + Uri.encodeComponent(id) + '/messages', {
        'body': '📸 Blink Moment shared\n' +
          ((widget.moment.caption ?? '').isEmpty ? '' : widget.moment.caption! + '\n') +
          BlinkHomeApi.mediaUrl(widget.moment.mediaUrl)
      });
      _notify('Moment shared to ' + field(friend, 'name'));
    } catch (e) { _notify('Unable to share: $e'); }
  }

  Future<void> _shareOptions() async {
    await showModalBottomSheet<void>(context: context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.chat_bubble_outline, color: BlinkColors.orange),
          title: const Text('Share to Blink Inbox'),
          onTap: () { Navigator.pop(ctx); _shareToInbox(); }),
        ListTile(leading: const Icon(Icons.share_outlined),
          title: const Text('Share outside Blink'),
          onTap: () { Navigator.pop(ctx); _share(); }),
      ]),
    ));
  }

  Future<void> _deleteMoment() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete Moment?'),
      content: const Text('This deletes the Moment and its media permanently.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    try {
      await BlinkHomeApi.deleteMoment(widget.moment.id);
      widget.onDeleted?.call();
      _notify('Moment deleted.');
    } catch (e) { _notify('Could not delete Moment: $e'); }
  }

  Future<void> _toggleSoundtrack() async {
    final id = widget.moment.musicTrackId;
    if (id == null || blinkOriginalTrack(id) == null) return;
    final player = _soundtrack ??= BlinkOriginalPlayer();
    try {
      await player.play(id);
      if (mounted) setState(() => _soundtrackPlaying = player.isPlaying);
    } catch (error) {
      _notify('Unable to play Blink soundtrack: $error');
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        if (widget.moment.senderId != widget.myUserId) {
          try { await BlinkHomeApi.recordView(widget.moment.id); } catch (_) {}
        }
        await controller.play();
      }
      if (mounted) setState(() {});
    } catch (_) {
      _notify('Unable to play this video on this device.');
    }
  }

  Future<void> _openMedia() async {
    if (widget.moment.senderId != widget.myUserId) {
      try { await BlinkHomeApi.recordView(widget.moment.id); } catch (_) {}
    }
    if (!mounted) return;
    if (widget.moment.mediaType == 'video') {
      await _video?.pause();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _MomentVideoFullscreen(
          url: BlinkHomeApi.mediaUrl(widget.moment.mediaUrl),
        ),
      ));
    } else {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: BlinkColors.canvas,
           appBar: AppBar(backgroundColor: BlinkColors.surface, foregroundColor: BlinkColors.orangeDark),
          body: Center(child: InteractiveViewer(child: Image.network(
            BlinkHomeApi.mediaUrl(widget.moment.mediaUrl),
            errorBuilder: (_, __, ___) => const Text(
              'Could not display this image', style: TextStyle(color: BlinkColors.muted)),
          ))),
        ),
      ));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _loveController.dispose();
    _video?.dispose();
    _soundtrack?.dispose();
    super.dispose();
  }

  String _ago(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  // The visible orb is compact; its 52x50 logical-pixel hit region remains
  // easy to target even on a narrow phone or while holding it one-handed.
  Widget _actionTile({
    required Widget symbol,
    required String label,
    VoidCallback? onPressed,
    String? tooltip,
    Key? tileKey,
    Color accent = Colors.white,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Tooltip(
      message: tooltip ?? label,
      child: Material(
        key: tileKey,
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 52,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 52, height: 49,
                child: Center(child: Container(
                  width: 38, height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x9D18171D),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent == Colors.white
                        ? const Color(0x90FFFFFF)
                        : accent.withValues(alpha: .68),
                      width: 1.1),
                  ),
                  child: symbol,
                )),
              ),
              Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 5)])),
            ]),
          ),
        ),
      ),
    ),
  );

  Widget _buildImmersive() {
    final video = _video;
    final mine = widget.moment.senderId == widget.myUserId;
    final myReaction = (_activity?['myReaction'] ?? '').toString();
    final reactions = (_activity?['reactionTotal'] ?? 0).toString();
    final comments = (_activity?['commentCount'] ?? 0).toString();
    final caption = widget.moment.caption?.trim() ?? '';
    final track = blinkOriginalTrack(widget.moment.musicTrackId);
    final height = MediaQuery.sizeOf(context).height;
    final compact = height < 650;

    return Stack(fit: StackFit.expand, children: [
      // A bright ambient extension protects the original media aspect ratio;
      // only a narrow bottom scrim is darkened for white foreground text.
      const DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFFE0CB), Color(0xFFF6E9EA), Color(0xFFBEAFC5)]))),
      if (widget.moment.mediaType == 'video') ...[
        if (video != null && video.value.isInitialized)
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: video.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video),
            ),
          )
        else
          Center(child: _videoError == null
            ? const CircularProgressIndicator(color: BlinkColors.orange)
            : const Icon(Icons.videocam_off_outlined,
                color: BlinkColors.orangeDark, size: 48)),
        if (video != null && video.value.isInitialized)
          Center(child: IgnorePointer(child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: video.value.isPlaying ? 0 : 1,
            child: const Icon(Icons.play_circle_fill_rounded,
              color: Colors.white, size: 67),
          ))),
      ] else ...[
        Positioned.fill(child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Image.network(
            BlinkHomeApi.mediaUrl(widget.moment.mediaUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFFF6DACB))),
        )),
        const Positioned.fill(child: ColoredBox(
          color: Color(0x24FFF5ED))),
        Image.network(
          BlinkHomeApi.mediaUrl(widget.moment.mediaUrl),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined,
              color: BlinkColors.orangeDark, size: 47)),
        ),
      ],
      // The scrim lives near the caption, not across the entire photograph.
      const Positioned(
        bottom: 0, left: 0, right: 0,
        height: 270,
        child: IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x4B17121B),
                Color(0xA914111D), Color(0xD81B1421)],
              stops: [0, .34, .69, 1],
            )),
        )),
      ),
      const Positioned(
        top: 0, left: 0, right: 0,
        height: 145,
        child: IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x77000000), Colors.transparent]),
          )),
        ),
      ),
      // The PageView still owns vertical navigation. A single tap on an
      // image toggles the controls for distraction-free viewing.
      Positioned.fill(child: GestureDetector(
        key: const ValueKey('blink-moment-immersive-media'),
        behavior: HitTestBehavior.translucent,
        onTap: widget.moment.mediaType == 'video'
          ? _togglePlayback
          : () => setState(() => _chromeVisible = !_chromeVisible),
        onDoubleTapDown: (details) => _loveTapPoint = details.localPosition,
        onDoubleTap: _doubleTapLove,
      )),
      _loveBurst(),
      Positioned.fill(child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 190),
          opacity: _chromeVisible ? 1 : 0,
          child: Stack(children: [
            SafeArea(child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(17, 0, 70, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: compact ? height * .30 : height * .28),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 39, height: 39,
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                Color(0xFFFF5900), Color(0xFFFF9F5C)])),
                            child: CircleAvatar(
                              backgroundColor: BlinkColors.orangeDark,
                              backgroundImage: widget.moment.avatarKey == null
                                ? null : NetworkImage(
                                  BlinkHomeApi.mediaUrl(widget.moment.avatarKey!)),
                              child: widget.moment.avatarKey == null
                                ? const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 20)
                                : null,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.moment.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white,
                                  fontSize: 14, fontWeight: FontWeight.w900)),
                              Text(_ago(widget.moment.createdAt),
                                style: const TextStyle(
                                  color: Color(0xD6FFFFFF), fontSize: 11)),
                            ],
                          )),
                          SizedBox(width: 40, height: 42,
                            child: IconButton(
                              tooltip: _saved ? 'Remove saved Moment' : 'Save Moment',
                              padding: EdgeInsets.zero,
                              onPressed: _toggleSave,
                              icon: Icon(_saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                                color: Colors.white, size: 23)),
                          ),
                        ]),
                        if (caption.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(caption,
                            maxLines: _captionExpanded ? null : 2,
                            overflow: _captionExpanded
                              ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 13.5,
                              height: 1.43, fontWeight: FontWeight.w500)),
                          if (caption.length > 55 || caption.contains('\n'))
                            GestureDetector(
                              onTap: () => setState(
                                () => _captionExpanded = !_captionExpanded),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                child: Text(
                                  _captionExpanded ? 'Show less' : 'Read more',
                                  style: const TextStyle(color: Color(0xFFFFC5A1),
                                    fontSize: 12, fontWeight: FontWeight.w900)),
                              ),
                            ),
                        ],
                        if (track != null)
                          InkWell(
                            onTap: _toggleSoundtrack,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(_soundtrackPlaying
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.music_note_rounded,
                                  color: const Color(0xFFFFC5A1), size: 19),
                                const SizedBox(width: 5),
                                Flexible(child: Text(track.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white,
                                    fontSize: 11.5, fontWeight: FontWeight.w600))),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )),
            SafeArea(child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 5, top: 65, bottom: 45),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height * .65),
                  child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _actionTile(
                        symbol: Icon(myReaction == '❤️'
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                          color: myReaction == '❤️'
                            ? const Color(0xFFFF3758) : Colors.white,
                          size: 23),
                        label: reactions,
                        tooltip: 'Like Moment',
                        tileKey: _likeActionKey,
                        accent: const Color(0xFFFF3758),
                        onPressed: _busy ? null : _like,
                      ),
                      BlinkReactionDock(
                        enabled: !_busy,
                        currentReaction: myReaction,
                        onSelected: _applyReaction,
                        child: _actionTile(
                          symbol: Text(myReaction.isNotEmpty &&
                              myReaction != '❤️' ? myReaction : '😊',
                            style: const TextStyle(fontSize: 22)),
                          label: 'React',
                          tooltip: 'React',
                          onPressed: null,
                          accent: const Color(0xFFFFD08B),
                        ),
                      ),
                      _actionTile(
                        symbol: const Icon(Icons.mode_comment_outlined,
                          color: Colors.white, size: 22),
                        label: comments, tooltip: 'Comments',
                        onPressed: _comments,
                      ),
                      _actionTile(
                        symbol: Icon(mine
                            ? Icons.visibility_outlined
                            : Icons.card_giftcard_rounded,
                          color: const Color(0xFFFFC28E), size: 22),
                        label: mine ? 'Views' : 'BP',
                        tooltip: mine ? 'Moment viewers' : 'Give Blink Points',
                        accent: const Color(0xFFFFC28E),
                        onPressed: mine ? _viewers : _giftBp,
                      ),
                      _actionTile(
                        symbol: const Icon(Icons.send_outlined,
                          color: Colors.white, size: 22),
                        label: 'Share', tooltip: 'Share',
                        onPressed: _shareOptions,
                      ),
                    ]),
                  ),
                ),
              ),
            )),
          ]),
        ),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.immersive) return _buildImmersive();
    final reaction = (_activity?['myReaction'] ?? '').toString();
    final total = _activity?['reactionTotal'] ?? 0;
    final comments = _activity?['commentCount'] ?? 0;
    final video = _video;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BlinkColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 9, 7),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFFE9DC),
              backgroundImage: widget.moment.avatarKey != null
                ? NetworkImage(BlinkHomeApi.mediaUrl(widget.moment.avatarKey!)) : null,
              child: widget.moment.avatarKey == null ? const Icon(Icons.person, color: BlinkColors.orange) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.moment.author, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(_ago(widget.moment.createdAt), style: const TextStyle(color: BlinkColors.muted, fontSize: 11)),
            ])),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) => value == 'delete' ? _deleteMoment() : _shareOptions(),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'share', child: Text('Share')),
                if (widget.moment.senderId == widget.myUserId)
                  const PopupMenuItem(value: 'delete', child: Text('Delete Moment')),
              ],
            ),
          ]),
        ),
        // Video Moments have a centered Blink-orange play button.
        if (widget.moment.mediaType == 'video')
          SizedBox(
            width: double.infinity,
            height: 295,
            child: Stack(fit: StackFit.expand, children: [
              const ColoredBox(color: Color(0xFF181818)),
              if (video != null && video.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: video.value.size.width,
                    height: video.value.size.height,
                    child: VideoPlayer(video),
                  ),
                ),
              if (video == null || !video.value.isInitialized)
                Center(child: _videoError != null
                    ? const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 38)
                    : const CircularProgressIndicator(color: BlinkColors.orange)),
              if (video != null && video.value.isInitialized)
                Positioned.fill(child: InkWell(
                  onTap: _togglePlayback,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 170),
                      opacity: video.value.isPlaying ? 0 : 1,
                      child: IgnorePointer(
                        child: Container(
                          width: 78, height: 78,
                          decoration: BoxDecoration(
                            color: BlinkColors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(
                              color: Color(0x65000000), blurRadius: 18, offset: Offset(0, 7))],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              size: 48, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                )),
              if (video != null && video.value.isInitialized)
                Positioned(right: 8, bottom: 8,
                  child: IconButton.filledTonal(
                    onPressed: _openMedia,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xBB000000),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                ),
            ]),
          )
        else
          GestureDetector(
            onTap: _openMedia,
            child: Image.network(
              BlinkHomeApi.mediaUrl(widget.moment.mediaUrl),
              height: 295,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 295, child: Center(child: Icon(Icons.broken_image_outlined,
                  size: 36, color: BlinkColors.muted))),
            ),
          ),
        Row(children: [
          IconButton(onPressed: _busy ? null : _reaction,
            icon: Text(reaction.isEmpty ? '♡' : reaction,
              style: TextStyle(fontSize: 25, color: reaction.isEmpty ? BlinkColors.ink : BlinkColors.orange))),
          Text('$total', style: const TextStyle(fontSize: 11)),
          IconButton(onPressed: _comments, icon: const Icon(Icons.mode_comment_outlined, size: 22)),
          Text('$comments', style: const TextStyle(fontSize: 11)),
          IconButton(onPressed: _shareOptions, tooltip: 'Share Moment', icon: const Icon(Icons.send_outlined, size: 21)),
          if (widget.moment.senderId != widget.myUserId)
            IconButton(onPressed: _busy ? null : _giftBp, tooltip: 'Gift Blink Points',
              icon: const Icon(Icons.stars_outlined, color: BlinkColors.orange, size: 23)),
          if (widget.moment.senderId == widget.myUserId)
            IconButton(onPressed: _viewers, tooltip: 'Moment viewers', icon: const Icon(Icons.visibility_outlined, size: 23)),
          const Spacer(),
          IconButton(onPressed: _toggleSave,
            icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded)),
        ]),
        if (blinkOriginalTrack(widget.moment.musicTrackId) != null)
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextButton.icon(
              onPressed: _toggleSoundtrack,
              icon: Icon(_soundtrackPlaying ? Icons.pause_circle_outline : Icons.music_note,
                color: BlinkColors.orange),
              label: Text('♪ ' + blinkOriginalTrack(widget.moment.musicTrackId)!.title +
                (_soundtrackPlaying ? ' · Stop' : ' · Play')),
            )),
        if ((widget.moment.caption ?? '').isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(widget.moment.caption!, style: const TextStyle(fontSize: 12.5))),
      ]),
    );
  }
}

class _BlinkMomentComments extends StatefulWidget {
  const _BlinkMomentComments({required this.momentId, required this.myUserId});
  final String momentId;
  final String myUserId;

  @override
  State<_BlinkMomentComments> createState() => _BlinkMomentCommentsState();
}

class _BlinkMomentCommentsState extends State<_BlinkMomentComments> {
  final _text = TextEditingController();
  Map<String, dynamic>? _activity;
  String? _error;
  bool _sending = false;
  String? _replyTo;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final activity = await BlinkHomeApi.activity(widget.momentId);
      if (mounted) setState(() { _activity = activity; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await BlinkHomeApi.comment(widget.momentId, _text.text.trim(), parentId: _replyTo);
      _text.clear();
      if (mounted) setState(() => _replyTo = null);
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _commentTile(Map<String, dynamic> entry, {bool nested = false}) {
    final author = entry['author'] is Map ? entry['author'] as Map : {};
    final id = (entry['id'] ?? '').toString();
    final deleted = entry['deletedAt'] != null;
    final mine = author['id']?.toString() == widget.myUserId;
    final replies = entry['replies'];
    final name = (author['name'] ?? 'Blink member').toString();
    return Padding(
      padding: EdgeInsets.only(left: nested ? 25 : 0, bottom: 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: nested ? 14 : 17,
          backgroundColor: BlinkColors.orangeSoft,
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(color: BlinkColors.orangeDark,
              fontWeight: FontWeight.w900, fontSize: 12)),
        ),
        const SizedBox(width: 9),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 11, 12, 12),
              decoration: BoxDecoration(
                color: nested ? const Color(0xFFFFF3EC) : Colors.white,
                border: Border.all(color: const Color(0xFFFFE4D7)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(17),
                  bottomLeft: Radius.circular(17),
                  bottomRight: Radius.circular(17))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: BlinkColors.ink))),
                    if (mine && !deleted)
                      SizedBox(width: 30, height: 30, child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Delete comment',
                        icon: const Icon(Icons.delete_outline_rounded,
                          size: 17, color: BlinkColors.muted),
                        onPressed: () async {
                          try {
                            await BlinkHomeApi.deleteComment(id);
                            await _reload();
                          } catch (e) {
                            if (mounted) setState(() => _error = e.toString());
                          }
                        },
                      )),
                  ]),
                  const SizedBox(height: 5),
                  Text((entry['body'] ?? '').toString(),
                    style: const TextStyle(fontSize: 13,
                      height: 1.42, color: BlinkColors.ink)),
                ],
              ),
            ),
            if (!nested && !deleted)
              TextButton.icon(
                onPressed: () => setState(() => _replyTo = id),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text('Reply'),
                style: TextButton.styleFrom(
                  foregroundColor: BlinkColors.orangeDark,
                  visualDensity: VisualDensity.compact),
              ),
            if (!nested && replies is List)
              ...replies.whereType<Map<String, dynamic>>()
                  .map((reply) => _commentTile(reply, nested: true)),
          ],
        )),
      ]),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = _activity?['comments'];
    final count = _activity?['commentCount'] ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(children: [
          const SizedBox(height: 9),
          Center(child: Container(
            width: 45, height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFFFCEB1),
              borderRadius: BorderRadius.circular(8)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 19, 16, 13),
            child: Row(children: [
              Container(
                width: 43, height: 43,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFFFF5900), Color(0xFFFF9C62)]),
                  borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.forum_rounded,
                  color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The conversation',
                    style: TextStyle(fontSize: 19,
                      fontWeight: FontWeight.w900)),
                  Text('$count comments · Join the Moment',
                    style: const TextStyle(fontSize: 11.5,
                      color: BlinkColors.muted)),
                ],
              )),
              IconButton(
                tooltip: 'Close comments',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          const Divider(height: 1),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12),
              child: Text(_error!,
                style: const TextStyle(color: Colors.red))),
          Expanded(child: _activity == null && _error == null
            ? const Center(child: CircularProgressIndicator(
                color: BlinkColors.orange))
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(15, 17, 15, 8),
                  children: comments is List && comments.isNotEmpty
                    ? comments.whereType<Map<String, dynamic>>()
                        .map(_commentTile).toList()
                    : [
                        const SizedBox(height: 85),
                        const Icon(Icons.chat_bubble_outline_rounded,
                          color: BlinkColors.orange, size: 43),
                        const SizedBox(height: 12),
                        const Text('Start something meaningful',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        const Text('Be the first to leave a comment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: BlinkColors.muted)),
                      ],
                ),
              )),
          if (_replyTo != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: BlinkColors.orangeSoft,
                borderRadius: BorderRadius.circular(13)),
              child: Row(children: [
                const Icon(Icons.reply_rounded,
                  color: BlinkColors.orangeDark, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Replying to a comment',
                  style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w800))),
                IconButton(
                  tooltip: 'Cancel reply',
                  onPressed: () => setState(() => _replyTo = null),
                  icon: const Icon(Icons.close, size: 18)),
              ]),
            ),
          SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _text,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _replyTo == null
                    ? 'Add your voice…' : 'Write a reply…',
                  counterText: '',
                  prefixIcon: const Icon(Icons.edit_note_rounded,
                    color: BlinkColors.orangeDark),
                  filled: true,
                  fillColor: const Color(0xFFFFF3EC)),
              )),
              const SizedBox(width: 9),
              Material(
                color: _sending
                  ? BlinkColors.muted : BlinkColors.orange,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _sending ? null : _send,
                  borderRadius: BorderRadius.circular(16),
                  child: const SizedBox(
                    width: 49, height: 49,
                    child: Icon(Icons.arrow_upward_rounded,
                      color: Colors.white)),
                ),
              ),
            ]),
          )),
        ]),
      ),
    );
  }
}

// A separate video player avoids rendering one VideoPlayerController in two
// camera/video textures at once when a user requests full-screen playback.
class _MomentVideoFullscreen extends StatefulWidget {
  const _MomentVideoFullscreen({required this.url});
  final String url;

  @override
  State<_MomentVideoFullscreen> createState() => _MomentVideoFullscreenState();
}

class _MomentVideoFullscreenState extends State<_MomentVideoFullscreen> {
  late final VideoPlayerController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'Video cannot play on this device.');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BlinkColors.canvas,
           appBar: AppBar(backgroundColor: BlinkColors.surface, foregroundColor: BlinkColors.orangeDark),
    body: Center(child: _error != null
      ? Text(_error!, style: const TextStyle(color: Colors.white))
      : !_controller.value.isInitialized
          ? const CircularProgressIndicator(color: BlinkColors.orange)
          : GestureDetector(
              onTap: () async {
                if (_controller.value.isPlaying) {
                  await _controller.pause();
                } else {
                  await _controller.play();
                }
                if (mounted) setState(() {});
              },
              child: Stack(alignment: Alignment.center, children: [
                AspectRatio(aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller)),
                if (!_controller.value.isPlaying)
                  const Icon(Icons.play_circle_fill_rounded,
                    color: BlinkColors.orange, size: 80),
              ]),
            )),
  );
}
