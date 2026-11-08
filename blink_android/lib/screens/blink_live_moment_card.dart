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
  bool _taughtLove = false;
  // Activity and media failures are independent: valid Moments stay visible.
  String? _videoError;

  // Instagram-style double-tap feedback is deliberately separate from the
  // backend reaction state, so the heart animation runs immediately.
  late final AnimationController _loveController;
  final GlobalKey _likeActionKey = GlobalKey(debugLabel: 'Blink Moment Like');
  Offset? _loveTapPoint;

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
    if (!widget.active) return;
    if (!_taughtLove && mounted) setState(() => _taughtLove = true);
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

  /// The particle destination is measured from the actual Like control,
  /// not approximated using a hard-coded screen height. It remains accurate
  /// on short phones, large fonts and when the system insets change.
  Widget _loveBurst() => Positioned.fill(
    child: LayoutBuilder(builder: (context, space) {
      final host = this.context.findRenderObject();
      final like = _likeActionKey.currentContext?.findRenderObject();
      Offset? target;
      if (host is RenderBox && like is RenderBox &&
          host.hasSize && like.hasSize) {
        target = host.globalToLocal(
          like.localToGlobal(like.size.center(Offset.zero)));
      }
      return BlinkHeartFlight(
        progress: _loveController,
        origin: _loveTapPoint ??
          Offset(space.maxWidth / 2, space.maxHeight / 2),
        destination: target ??
          Offset(space.maxWidth - 37, space.maxHeight * .35),
      );
    }),
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

  Widget _actionTile({
    required Widget symbol,
    required String label,
    required VoidCallback onPressed,
    String? tooltip,
    Key? tileKey,
    Color accent = Colors.white,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Tooltip(
      message: tooltip ?? label,
      child: Material(
        key: tileKey,
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          splashColor: BlinkColors.orange.withValues(alpha: .18),
          child: SizedBox(
            width: 64,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52, height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xD9252733),
                      Color.lerp(const Color(0xC9212230),
                        accent, .16) ?? const Color(0xC9212230),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: accent == Colors.white
                      ? const Color(0x4CFFFFFF)
                      : accent.withValues(alpha: .65),
                    width: 1.1),
                  boxShadow: const [
                    BoxShadow(color: Color(0x70000000),
                      blurRadius: 15, offset: Offset(0, 5)),
                  ],
                ),
                child: symbol,
              ),
              const SizedBox(height: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xC4171922),
                  borderRadius: BorderRadius.circular(9)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 58),
                    child: Text(label, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
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

    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black),
      if (widget.moment.mediaType == 'video') ...[
        if (video != null && video.value.isInitialized)
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: video.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video)),
          )
        else
          Center(child: _videoError == null
            ? const CircularProgressIndicator(color: BlinkColors.orange)
            : const Icon(Icons.videocam_off_outlined,
                color: Colors.white54, size: 46)),
        if (video != null && video.value.isInitialized)
          Positioned.fill(child: IgnorePointer(
            child: Center(child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: video.value.isPlaying ? 0 : 1,
              child: const Icon(Icons.play_circle_fill_rounded,
                color: Colors.white, size: 72),
            )),
          )),
      ] else
        Image.network(
          BlinkHomeApi.mediaUrl(widget.moment.mediaUrl),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined,
              color: Colors.white54, size: 50)),
        ),
      const IgnorePointer(child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xB9000000), Colors.transparent, Color(0xBE000000)],
            stops: [0, .33, 1],
          )),
      )),
      // Handle one-tap video play/pause and double-tap love in the SAME
      // gesture recognizer. This keeps vertical PageView swipes available.
      Positioned.fill(child: GestureDetector(
        key: const ValueKey('blink-moment-immersive-media'),
        behavior: HitTestBehavior.translucent,
        onTap: widget.moment.mediaType == 'video' ? _togglePlayback : null,
        onDoubleTapDown: (details) => _loveTapPoint = details.localPosition,
        onDoubleTap: _doubleTapLove,
        onLongPress: _reaction,
      )),
      _loveBurst(),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 56, 15, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(),
            Row(children: [
              CircleAvatar(
                radius: 19, backgroundColor: BlinkColors.orange,
                backgroundImage: widget.moment.avatarKey == null
                  ? null : NetworkImage(
                      BlinkHomeApi.mediaUrl(widget.moment.avatarKey!)),
                child: widget.moment.avatarKey == null
                  ? const Icon(Icons.person_rounded, color: Colors.white)
                  : null,
              ),
              const SizedBox(width: 9),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.moment.author,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w900)),
                  Text(_ago(widget.moment.createdAt),
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              )),
              IconButton(
                tooltip: 'Share Moment',
                onPressed: _shareOptions,
                icon: const Icon(Icons.send_outlined, color: Colors.white)),
            ]),
            if ((widget.moment.caption ?? '').isNotEmpty) ...[
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.only(right: 64),
                child: Text(widget.moment.caption!,
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
            if (blinkOriginalTrack(widget.moment.musicTrackId) != null)
              TextButton.icon(
                onPressed: _toggleSoundtrack,
                icon: Icon(_soundtrackPlaying ? Icons.pause_circle_outline
                  : Icons.music_note_rounded, color: Colors.white, size: 18),
                label: Text(blinkOriginalTrack(widget.moment.musicTrackId)!.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
          ]),
        ),
      ),
      SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 10, top: 30, bottom: 46),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .70),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _actionTile(
                    symbol: Icon(myReaction == '❤️'
                      ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                      color: myReaction == '❤️'
                        ? const Color(0xFFFF2851) : Colors.white,
                      size: 27),
                    label: reactions, tooltip: 'Like Moment',
                    tileKey: _likeActionKey,
                    accent: const Color(0xFFFF2851),
                    onPressed: _busy ? () {} : _like,
                  ),
                  _actionTile(
                    symbol: Text(myReaction.isNotEmpty && myReaction != '❤️'
                      ? myReaction : '😊',
                      style: const TextStyle(fontSize: 24)),
                    label: 'React', onPressed: _reaction,
                    accent: const Color(0xFFFFB547),
                  ),
                  _actionTile(
                    symbol: const Icon(Icons.mode_comment_outlined,
                      color: Colors.white, size: 25),
                    label: comments, tooltip: 'Comments',
                    accent: const Color(0xFF8EBDFF),
                    onPressed: _comments,
                  ),
                  _actionTile(
                    symbol: Icon(mine ? Icons.visibility_outlined
                        : Icons.card_giftcard_rounded,
                      color: const Color(0xFFFFB27F), size: 25),
                    label: mine ? 'Viewers' : 'BP',
                    accent: const Color(0xFFFFBF52),
                    tooltip: mine ? 'Moment viewers' : 'Give Blink Points',
                    onPressed: mine ? _viewers : _giftBp,
                  ),
                  _actionTile(
                    symbol: const Icon(Icons.send_outlined,
                      color: Colors.white, size: 25),
                    label: 'Share', accent: const Color(0xFF9BE9D0),
                    onPressed: _shareOptions,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
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
    return Padding(
      padding: EdgeInsets.only(left: nested ? 30 : 0, bottom: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text((author['name'] ?? 'Blink member').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          if (mine && !deleted) IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () async {
              try { await BlinkHomeApi.deleteComment(id); await _reload(); }
              catch (e) { if (mounted) setState(() => _error = e.toString()); }
            },
          ),
        ]),
        Text((entry['body'] ?? '').toString()),
        if (!nested && !deleted) TextButton(
          onPressed: () => setState(() => _replyTo = id), child: const Text('Reply'),
        ),
        if (!nested && replies is List)
          ...replies.whereType<Map<String, dynamic>>().map((r) => _commentTile(r, nested: true)),
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(children: [
          const SizedBox(height: 15),
          const Text('Moment comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          Expanded(child: _activity == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(onRefresh: _reload, child: ListView(
                padding: const EdgeInsets.all(18),
                children: comments is List && comments.isNotEmpty
                  ? comments.whereType<Map<String, dynamic>>().map(_commentTile).toList()
                  : [const Text('No comments yet. Be the first to comment.')],
              ))),
          if (_replyTo != null) Row(children: [
            const SizedBox(width: 14),
            const Expanded(child: Text('Replying to comment')),
            IconButton(onPressed: () => setState(() => _replyTo = null), icon: const Icon(Icons.close)),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), child: Row(children: [
            Expanded(child: TextField(controller: _text, maxLength: 500, minLines: 1, maxLines: 3,
              decoration: const InputDecoration(hintText: 'Write a comment...'))),
            IconButton(onPressed: _sending ? null : _send, icon: const Icon(Icons.send, color: BlinkColors.orange)),
          ])),
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
