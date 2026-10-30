import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'live_inbox.dart';
import 'package:video_player/video_player.dart';

import '../core/blink_auth_api.dart';
import '../core/blink_home_api.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
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
                onDeleted: _refresh,
              ),
            ),
          Positioned(
            top: 12, left: 14, right: 12,
            child: Row(children: [
              const Text('Reels', style: TextStyle(
                color: BlinkColors.orangeDark, fontSize: 23, fontWeight: FontWeight.w900,
              )),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh public Reels',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, color: BlinkColors.orangeDark),
              ),
              IconButton(
                tooltip: 'Publish a Reel',
                onPressed: () => go(context, '/reel/upload'),
                icon: const Icon(Icons.add_circle_outline, color: BlinkColors.orangeDark),
              ),
            ]),
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
    this.onDeleted,
  });

  final BlinkReel reel;
  final String myUserId;
  final bool active;
  final VoidCallback? onDeleted;

  @override
  State<ReelFullScreen> createState() => _ReelFullScreenState();
}

class _ReelFullScreenState extends State<ReelFullScreen> {
  VideoPlayerController? _player;
  bool _busy = false;
  String? _playbackError;
  String? _reaction;
  int _reactionCount = 0;
  int _commentCount = 0;
  bool _viewRecorded = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _react() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await BlinkHomeApi.reactReel(
        widget.reel.id, _reaction == '❤️' ? null : '❤️',
      );
      if (!mounted) return;
      setState(() {
        _reaction = result['myReaction']?.toString();
        final n = result['reactionCount'];
        _reactionCount = n is num ? n.toInt() : _reactionCount;
      });
    } catch (e) { _toast('Reaction failed: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
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

  Future<void> _delete() async {
    if (widget.reel.authorId != widget.myUserId) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Reel?'),
        content: const Text('This permanently removes your published Reel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try { await BlinkHomeApi.deleteReel(widget.reel.id); widget.onDeleted?.call(); }
    catch (e) { _toast('Cannot delete Reel: $e'); }
  }

  Widget _action(IconData icon, String text, VoidCallback handler, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(onTap: handler, child: Column(children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: BlinkColors.orangeSoft,
        child: Stack(fit: StackFit.expand, children: [
          if (player != null && player.value.isInitialized)
            FittedBox(fit: BoxFit.cover, child: SizedBox(
              width: player.value.size.width,
              height: player.value.size.height,
              child: VideoPlayer(player),
            ))
          else
            Image.network(
              BlinkHomeApi.mediaUrl(widget.reel.thumbnailUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: BlinkColors.orangeSoft),
            ),
          if (player == null || !player.value.isInitialized)
            Center(child: _playbackError != null
              ? Text(_playbackError!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white))
              : const CircularProgressIndicator(color: BlinkColors.orange)),
          if (player != null && player.value.isInitialized)
            InkWell(onTap: _togglePlay, child: Center(child: AnimatedOpacity(
              opacity: player.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 170),
              child: IgnorePointer(child: const Icon(
                Icons.play_circle_fill_rounded, color: BlinkColors.orange, size: 78,
              )),
            ))),
        ]),
      )),
      const Positioned.fill(child: IgnorePointer(child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x45000000), Colors.transparent, Color(0xC9000000)],
        )),
      ))),
      Positioned(right: 10, bottom: 95, child: Column(children: [
        _action(_reaction == '❤️' ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          '$_reactionCount', _react, color: _reaction == '❤️' ? BlinkColors.orange : Colors.white),
        _action(Icons.mode_comment_outlined, '$_commentCount', _comments),
        _action(Icons.share_rounded, 'Share', _share),
        if (widget.reel.authorId == widget.myUserId)
          _action(Icons.delete_outline_rounded, 'Delete', _delete),
      ])),
      Positioned(left: 15, right: 70, bottom: 35, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18, backgroundColor: BlinkColors.orange,
              backgroundImage: widget.reel.avatarKey != null
                ? NetworkImage(BlinkHomeApi.mediaUrl(widget.reel.avatarKey!)) : null,
              child: widget.reel.avatarKey == null
                ? const Icon(Icons.person, color: Colors.white, size: 22) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.reel.authorName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w900))),
          ]),
          if ((widget.reel.caption ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(widget.reel.caption!, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ],
      )),
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

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _input.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final rows = await BlinkHomeApi.reelComments(widget.reelId);
      if (mounted) setState(() { _comments = rows; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await BlinkHomeApi.commentReel(widget.reelId, text);
      _input.clear();
      _posted = true;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _comment(Map<String, dynamic> value, {int indent = 0}) {
    final author = value['author'];
    final user = author is Map ? author : <String, dynamic>{};
    final replies = value['replies'];
    return Padding(
      padding: EdgeInsets.only(left: indent * 20.0, top: 10, bottom: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((user['name'] ?? 'Blink member').toString(),
          style: const TextStyle(fontWeight: FontWeight.w800)),
        Text((value['body'] ?? '').toString()),
        if (replies is List && indent == 0)
          ...replies.whereType<Map<String, dynamic>>()
            .map((reply) => _comment(reply, indent: 1)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(children: [
        const Padding(padding: EdgeInsets.all(16),
          child: Text('Reel comments', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: BlinkColors.orange))
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: _comments.isEmpty
                ? [const Center(child: Text('No comments yet.'))]
                : _comments.map(_comment).toList(),
            ))),
        Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _input,
              maxLength: 600,
              minLines: 1, maxLines: 3,
              decoration: const InputDecoration(hintText: 'Write a comment...'),
            )),
            IconButton(
              onPressed: _sending ? null : _post,
              icon: const Icon(Icons.send_rounded, color: BlinkColors.orange),
            ),
          ])),
        TextButton(onPressed: () => Navigator.pop(context, _posted),
          child: const Text('Done')),
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
      foregroundColor: BlinkColors.orangeDark, title: const Text('Reel')),
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
