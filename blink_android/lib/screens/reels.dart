import 'package:flutter/material.dart';
import '../widgets/blink_heart_flight.dart';
import '../widgets/blink_reaction_dock.dart';
import 'package:share_plus/share_plus.dart';
import 'live_inbox.dart';
import 'package:video_player/video_player.dart';

import '../core/blink_auth_api.dart';
import '../core/blink_home_api.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import '../widgets/blink_full_drawer.dart';
import 'blink_real_capture.dart';

/// Every signed-in Blink member sees the SAME global Reels feed, regardless
/// of who published each Reel. This replaces the old photo-based demo feed.
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  final PageController _controller = PageController();
  List<BlinkReel> _reels = [];
  String _myId = '';
  String? _error;
  bool _loading = true;
  bool _loadingNext = false;
  int? _nextOffset;
  int _currentIndex = 0;
  int _generation = 0;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _appActive = true);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      setState(() => _appActive = false);
    }
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final requestId = ++_generation;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _nextOffset = null;
    });
    try {
      final user = await BlinkAuthApi.currentUser();
      if (user == null) {
        if (mounted) go(context, '/login', replace: true);
        return;
      }
      final page = await BlinkHomeApi.reels();
      if (!mounted || requestId != _generation) return;
      setState(() {
        _reels = page.items;
        _nextOffset = page.nextOffset;
        _myId = (user['id'] ?? '').toString();
        _currentIndex = 0;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    } catch (e) {
      if (mounted && requestId == _generation) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  Future<void> _loadNext() async {
    final skip = _nextOffset;
    if (skip == null || _loading || _loadingNext) return;
    final requestId = _generation;
    setState(() => _loadingNext = true);
    try {
      final page = await BlinkHomeApi.reels(skip: skip);
      if (!mounted || requestId != _generation) return;
      final known = _reels.map((reel) => reel.id).toSet();
      setState(() {
        _reels.addAll(page.items.where((reel) => !known.contains(reel.id)));
        _nextOffset = page.nextOffset;
        _loadingNext = false;
      });
    } catch (e) {
      if (mounted && requestId == _generation) {
        setState(() => _loadingNext = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('More Reels unavailable: $e')),
        );
      }
    }
  }

  void _pageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index >= _reels.length - 4) _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlinkColors.canvas,
      drawer: const BlinkFullDrawer(),
      bottomNavigationBar: const BlinkBottomBar(active: 'reels'),
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(color: BlinkColors.orange))
          else if (_error != null)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, style: const TextStyle(color: BlinkColors.ink),
                    textAlign: TextAlign.center),
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ]),
            ))
          else if (_reels.isEmpty)
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.smart_display_outlined, color: BlinkColors.orange, size: 62),
              const SizedBox(height: 14),
              const Text('No public Reels yet',
                style: TextStyle(color: BlinkColors.ink, fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 12),
              TextButton(onPressed: () => go(context, '/reel/upload'),
                child: const Text('Publish the first Reel')),
              TextButton(onPressed: _refresh, child: const Text('Refresh')),
            ]))
          else
            PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              onPageChanged: _pageChanged,
              itemCount: _reels.length,
              itemBuilder: (context, index) => ReelFullScreen(
                key: ValueKey(_reels[index].id),
                reel: _reels[index],
                myUserId: _myId,
                active: _appActive && index == _currentIndex,
              ),
            ),
          Positioned(
            top: 12, left: 11, right: 11,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xF1272028), Color(0xDE562E2D)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x77FFFFFF)),
                boxShadow: const [
                  BoxShadow(color: Color(0x44000000),
                    blurRadius: 18, offset: Offset(0, 7)),
                ]),
              child: Row(children: [
                Builder(builder: (scaffoldContext) => IconButton(
                  tooltip: 'Open Blink navigation',
                  onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                )),
                const Expanded(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REELS · BLINK',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFFFFB78E),
                        fontSize: 9, fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                    Text('Watch your world',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                )),
                IconButton(
                  tooltip: 'Refresh public Reels',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white),
                ),
                IconButton(
                  tooltip: 'Publish a Reel',
                  onPressed: () => go(context, '/reel/upload'),
                  icon: const Icon(Icons.add_circle_outline,
                    color: Color(0xFFFFB78E)),
                ),
              ]),
            ),
          ),
          if (_loadingNext)
            const Positioned(bottom: 10, right: 14,
              child: CircularProgressIndicator(color: BlinkColors.orange)),
        ]),
      ),
    );
  }
}

class ReelFullScreen extends StatefulWidget {
  const ReelFullScreen({
    super.key,
    required this.reel,
    required this.myUserId,
    required this.active,
  });

  final BlinkReel reel;
  final String myUserId;
  final bool active;

  @override
  State<ReelFullScreen> createState() => _ReelFullScreenState();
}

class _ReelFullScreenState extends State<ReelFullScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _player;
  bool _busy = false;
  String? _playbackError;
  String? _reaction;
  int _reactionCount = 0;
  int _commentCount = 0;
  bool _viewRecorded = false;
  late final AnimationController _loveController;
  Offset? _loveTapPosition;

  @override
  void initState() {
    super.initState();
    _loveController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1120));
    _reaction = widget.reel.myReaction;
    _reactionCount = widget.reel.reactionCount;
    _commentCount = widget.reel.commentCount;
    _prepareVideo();
    if (widget.active) _recordView();
  }

  Future<void> _prepareVideo() async {
    final player = VideoPlayerController.networkUrl(
      Uri.parse(BlinkHomeApi.mediaUrl(widget.reel.videoUrl)),
    );
    _player = player;
    try {
      await player.initialize();
      await player.setLooping(true);
      if (!mounted || _player != player) {
        await player.dispose();
        return;
      }
      if (widget.active) await player.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _playbackError = 'This Reel cannot play on this device.');
    }
  }

  Future<void> _recordView() async {
    if (_viewRecorded || widget.reel.authorId == widget.myUserId) return;
    _viewRecorded = true;
    try { await BlinkHomeApi.recordReelView(widget.reel.id); } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant ReelFullScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _recordView();
        if (_player?.value.isInitialized == true) _player!.play();
      } else {
        if (_player?.value.isInitialized == true) _player!.pause();
      }
    }
  }

  @override
  void dispose() {
    _loveController.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    if (player.value.isPlaying) { await player.pause(); }
    else { await player.play(); }
    if (mounted) setState(() {});
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _setReelReaction(String selected) async {
    if (_busy || !mounted) return;
    final emoji = selected == 'remove' ? null : selected;
    setState(() => _busy = true);
    try {
      final result = await BlinkHomeApi.reactReel(widget.reel.id, emoji);
      if (!mounted) return;
      setState(() {
        _reaction = result['myReaction']?.toString();
        final n = result['reactionCount'];
        _reactionCount = n is num ? n.toInt() : _reactionCount;
      });
    } catch (e) {
      _toast('Reaction failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doubleTapLove() async {
    if (!widget.active || !mounted) return;
    _loveController.forward(from: 0);
    // Never unlove an already-loved Reel on repeated double taps.
    if (_busy || _reaction == '❤️') return;
    await _setReelReaction('❤️');
  }

  Future<void> _comments() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: BlinkColors.canvas,
       builder: (_) => _LiveReelComments(reelId: widget.reel.id),
    );
    if (added == true && mounted) setState(() => _commentCount += 1);
  }

  Future<void> _share() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.people_alt_outlined, color: BlinkColors.orange),
            title: const Text('Share to Blink friends'),
            subtitle: const Text('Send the Reel into your friends\' Inbox'),
            onTap: () {
              Navigator.pop(sheetContext);
              shareReelToBlinkFriends(context, widget.reel.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share outside Blink'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final url = BlinkHomeApi.mediaUrl(widget.reel.videoUrl);
              try {
                await SharePlus.instance.share(ShareParams(
                  text: '${widget.reel.caption ?? 'Watch this Blink Reel'}\n$url',
                ));
              } catch (e) { _toast('Share failed: $e'); }
            },
          ),
        ]),
      ),
    );
  }

  Widget _action(IconData icon, String text, VoidCallback? handler,
      {Color color = Colors.white}) {
    final compact = MediaQuery.sizeOf(context).height < 650;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: handler,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(width: 52, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xBC27212B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x70FFFFFF))),
                child: Icon(icon, color: color, size: 23)),
              const SizedBox(height: 5),
              Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5,
                  color: Colors.white, fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 6)])),
            ],
          )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD4B8), Color(0xFF4D385A),
            Color(0xFF191524)]))),
      if (player != null && player.value.isInitialized)
        FittedBox(fit: BoxFit.cover, child: SizedBox(
          width: player.value.size.width,
          height: player.value.size.height,
          child: VideoPlayer(player),
        ))
      else Image.network(
        BlinkHomeApi.mediaUrl(widget.reel.thumbnailUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
          const ColoredBox(color: Color(0xFF4D385A)),
      ),
      if (player == null || !player.value.isInitialized)
        Center(child: _playbackError != null
          ? Padding(padding: const EdgeInsets.all(35),
              child: Text(_playbackError!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)))
          : const CircularProgressIndicator(color: BlinkColors.orange)),
      const IgnorePointer(child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x75151120), Colors.transparent,
            Color(0xD7181522)],
          stops: [0, .4, 1],
        )),
      )),
      // Let the PageView own vertical swipes. This single recognizer
      // handles tap-to-pause and double-tap love without action conflicts.
      Positioned.fill(child: GestureDetector(
        key: const ValueKey('blink-reel-immersive-media'),
        behavior: HitTestBehavior.translucent,
        onTap: _togglePlay,
        onDoubleTapDown: (details) =>
          _loveTapPosition = details.localPosition,
        onDoubleTap: _doubleTapLove,
        child: Center(child: IgnorePointer(child: AnimatedOpacity(
          opacity: player?.value.isPlaying == false ? 1 : 0,
          duration: const Duration(milliseconds: 170),
          child: const Icon(Icons.play_circle_fill_rounded,
            size: 72, color: Color(0xFFFFE9D8)),
        ))),
      )),
      Positioned.fill(child: LayoutBuilder(
        builder: (context, space) => BlinkHeartFlight(
          progress: _loveController,
          origin: _loveTapPosition ??
            Offset(space.maxWidth * .5, space.maxHeight * .5),
          destination: Offset(space.maxWidth - 38,
            space.maxHeight * .56),
        ),
      )),
      Positioned(
        right: 9,
        bottom: MediaQuery.sizeOf(context).height < 650 ? 52 : 80,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BlinkReactionDock(
            enabled: !_busy,
            reactions: const ['❤️', '😍', '😂', '😮', '😢', '🔥', '👍'],
            currentReaction: _reaction,
            allowRemove: true,
            onSelected: _setReelReaction,
            child: _action(
              _reaction != null && _reaction!.isNotEmpty
                ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              '$_reactionCount', null,
              color: _reaction != null && _reaction!.isNotEmpty
                ? const Color(0xFFFF3E63) : Colors.white,
            ),
          ),
          _action(Icons.mode_comment_outlined, '$_commentCount', _comments),
          _action(Icons.send_rounded, 'Share', _share),
        ]),
      ),
      Positioned(
        left: 13, right: 72, bottom: 33,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .30),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xD421202C), Color(0xB733283B)]),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0x62FFFFFF))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✦  BLINK ORIGINAL',
                  style: TextStyle(color: Color(0xFFFFC39B),
                    letterSpacing: 1.1, fontSize: 9,
                    fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(children: [
                  CircleAvatar(
                    radius: 19, backgroundColor: BlinkColors.orange,
                    backgroundImage: widget.reel.avatarKey != null
                      ? NetworkImage(BlinkHomeApi.mediaUrl(widget.reel.avatarKey!))
                      : null,
                    child: widget.reel.avatarKey == null
                      ? const Icon(Icons.person,
                          color: Colors.white, size: 22) : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(widget.reel.authorName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w900))),
                ]),
                if ((widget.reel.caption ?? '').isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(widget.reel.caption!,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white,
                      height: 1.4, fontSize: 12.5)),
                ],
                const SizedBox(height: 6),
                const Text('Double tap to love · Hold a reaction to choose',
                  style: TextStyle(fontSize: 9.5,
                    color: Color(0xDDFFFFFF))),
              ],
            ),
          ),
        ),
      ),
      if (player != null && player.value.isInitialized)
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: VideoProgressIndicator(player,
            allowScrubbing: true,
            padding: EdgeInsets.zero,
            colors: const VideoProgressColors(
              playedColor: BlinkColors.orange,
              bufferedColor: Color(0x88FFD9C2),
              backgroundColor: Color(0x66555555))),
        ),
    ]);
  }
}

class _LiveReelComments extends StatefulWidget {
  const _LiveReelComments({required this.reelId});
  final String reelId;
  @override
  State<_LiveReelComments> createState() => _LiveReelCommentsState();
}

class _LiveReelCommentsState extends State<_LiveReelComments> {
  final _input = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _posted = false;
  String _myId = '';
  String? _replyId, _replyName;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _input.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final rows = await BlinkHomeApi.reelComments(widget.reelId);
      final viewer = await BlinkAuthApi.cachedUser();
      if (mounted) setState(() { _comments = rows; _myId = (viewer?['id'] ?? '').toString(); _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await BlinkHomeApi.commentReel(widget.reelId, text, parentId: _replyId);
      _input.clear();
      _replyId = null; _replyName = null;
      _posted = true;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(String id) async {
    try {
      await BlinkHomeApi.request('DELETE', '/reels/comments/' + Uri.encodeComponent(id));
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Widget _comment(Map<String, dynamic> value, {int indent = 0}) {
    final rawAuthor = value['author'];
    final user = rawAuthor is Map ? rawAuthor : <String, dynamic>{};
    final replies = value['replies'];
    final id = (value['id'] ?? '').toString();
    final name = (user['name'] ?? 'Blink member').toString();
    final deleted = value['deletedAt'] != null ||
      value['body'] == '[deleted]';
    final owner = _myId.isNotEmpty &&
      (value['authorId'] ?? '').toString() == _myId;
    return Padding(
      padding: EdgeInsets.only(left: indent > 0 ? 25 : 0,
        bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: indent > 0 ? 14 : 18,
          backgroundColor: BlinkColors.orangeSoft,
          child: Text(name.isEmpty ? 'B' : name[0].toUpperCase(),
            style: const TextStyle(color: BlinkColors.orangeDark,
              fontWeight: FontWeight.w900, fontSize: 12))),
        const SizedBox(width: 9),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              decoration: BoxDecoration(
                color: indent > 0
                  ? const Color(0xFFFFF0E8) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16)),
                border: Border.all(color: const Color(0xFFFFDED0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5,
                      color: BlinkColors.ink, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(deleted ? 'Comment deleted'
                    : (value['body'] ?? '').toString(),
                    style: TextStyle(fontSize: 13,
                      color: deleted ? BlinkColors.muted : BlinkColors.ink,
                      height: 1.42)),
                ]),
            ),
            if (!deleted) Wrap(spacing: 7, children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  _replyId = indent > 0
                    ? (value['parentId'] ?? id).toString() : id;
                  _replyName = name;
                }),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text('Reply'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: BlinkColors.orangeDark)),
              if (owner) TextButton.icon(
                onPressed: () => _deleteComment(id),
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC93E4B),
                  visualDensity: VisualDensity.compact)),
            ]),
            if (replies is List && indent == 0)
              ...replies.whereType<Map<String, dynamic>>()
                .map((reply) => _comment(reply, indent: 1)),
          ],
        )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .77,
      child: Column(children: [
        const SizedBox(height: 8),
        Center(child: Container(width: 45, height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFFFCEB1),
            borderRadius: BorderRadius.circular(8)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(19, 19, 12, 12),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFFFF5900), Color(0xFFFFAB70)]),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.forum_rounded,
                color: Colors.white, size: 23)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reel conversations',
                  style: TextStyle(fontSize: 18.5,
                    color: BlinkColors.ink, fontWeight: FontWeight.w900)),
                Text('${_comments.length} conversations · Join in',
                  style: const TextStyle(
                    fontSize: 11, color: BlinkColors.muted)),
              ],
            )),
            IconButton(
              tooltip: 'Close comments',
              onPressed: () => Navigator.pop(context, _posted),
              icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFFFE5D5)),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(10),
            child: Text(_error!, style: const TextStyle(
              color: Color(0xFFC93E4B)))),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(
              color: BlinkColors.orange))
          : RefreshIndicator(onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(13, 15, 13, 14),
                children: _comments.isEmpty
                  ? [
                      const SizedBox(height: 70),
                      const Icon(Icons.mode_comment_outlined,
                        color: BlinkColors.orange, size: 43),
                      const SizedBox(height: 12),
                      const Text('Start the conversation',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      const Text('Your thoughts make this Reel better.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: BlinkColors.muted)),
                    ]
                  : _comments.map(_comment).toList(),
              ),
            )),
        if (_replyId != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: BlinkColors.orangeSoft,
              borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.reply_rounded,
                color: BlinkColors.orangeDark, size: 18),
              const SizedBox(width: 7),
              Expanded(child: Text('Reply to ${_replyName ?? 'comment'}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: 'Cancel reply',
                onPressed: () => setState(() {
                  _replyId = null; _replyName = null;
                }),
                icon: const Icon(Icons.close, size: 18)),
            ]),
          ),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _input,
              maxLength: 600,
              minLines: 1, maxLines: 3,
              decoration: InputDecoration(
                hintText: _replyId == null
                  ? 'Add to the conversation…' : 'Write a reply…',
                counterText: '',
                prefixIcon: const Icon(Icons.edit_note_rounded,
                  color: BlinkColors.orangeDark),
                filled: true,
                fillColor: const Color(0xFFFFF2E9)),
            )),
            const SizedBox(width: 9),
            Material(
              color: _sending ? BlinkColors.muted : BlinkColors.orange,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _sending ? null : _post,
                borderRadius: BorderRadius.circular(16),
                child: const SizedBox(
                  width: 48, height: 48,
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

/// Open an exact Reel ID, including Reels shared through Inbox.
class ReelDetailScreen extends StatefulWidget {
  const ReelDetailScreen({super.key});
  @override
  State<ReelDetailScreen> createState() => _ReelDetailState();
}
class _ReelDetailState extends State<ReelDetailScreen> {
  Future<List<dynamic>>? _future;
  @override void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    final arg = ModalRoute.of(context)?.settings.arguments;
    final id = arg is String ? arg : (arg is Map ? (arg['id']?.toString() ?? '') : '');
    _future = Future.wait<dynamic>([
      BlinkHomeApi.request('GET', '/reels/${Uri.encodeComponent(id)}'),
      BlinkAuthApi.cachedUser(),
    ]);
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: BlinkColors.canvas,
    appBar: AppBar(backgroundColor: BlinkColors.surface,
      foregroundColor: BlinkColors.orangeDark, title: const BlinkBrandedTitle('Reel')),
    body: FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}',
          style: const TextStyle(color: BlinkColors.ink)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data![0];
        if (data is! Map<String,dynamic>) return const Center(child: Text('Reel unavailable'));
        final self = snapshot.data![1];
        final userId = self is Map ? (self['id']?.toString() ?? '') : '';
        return ReelFullScreen(
          reel: BlinkReel.fromJson(data),
          myUserId: userId,
          active: true,
        );
      },
    ),
  );
}

/// Route into the SAME real Capture component, preselected to publish a Reel.
class UploadReelScreen extends StatelessWidget {
  const UploadReelScreen({super.key});
  @override
  Widget build(BuildContext context) => const BlinkRealCaptureScreen(
    initialVideo: true,
    preferReel: true,
  );
}
