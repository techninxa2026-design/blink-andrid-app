import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../core/blink_home_api.dart';
import '../core/theme.dart';

class BlinkLiveMomentCard extends StatefulWidget {
  const BlinkLiveMomentCard({super.key, required this.moment, required this.myUserId, this.onDeleted});
  final BlinkMoment moment;
  final String myUserId;
  final VoidCallback? onDeleted;

  @override
  State<BlinkLiveMomentCard> createState() => _BlinkLiveMomentCardState();
}

class _BlinkLiveMomentCardState extends State<BlinkLiveMomentCard> {
  Map<String, dynamic>? _activity;
  VideoPlayerController? _video;
  bool _saved = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivity();
    _loadSaved();
    if (widget.moment.mediaType == 'video') _initVideo();
  }

  Future<void> _initVideo() async {
    final video = VideoPlayerController.networkUrl(Uri.parse(BlinkHomeApi.mediaUrl(widget.moment.mediaUrl)));
    _video = video;
    try {
      await video.initialize();
      await video.setLooping(true);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load video.');
    }
  }

  Future<void> _loadActivity() async {
    try {
      final activity = await BlinkHomeApi.activity(widget.moment.id);
      if (mounted) setState(() => _activity = activity);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
      _notify(e.toString());
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
              'Image unavailable', style: TextStyle(color: BlinkColors.ink)),
          ))),
        ),
      ));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  String _ago(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
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
              onSelected: (value) => value == 'delete' ? _deleteMoment() : _share(),
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
                Center(child: _error != null
                    ? Text(_error!, style: const TextStyle(color: BlinkColors.ink))
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
                height: 295, child: Center(child: Text('Media unavailable'))),
            ),
          ),
        Row(children: [
          IconButton(onPressed: _busy ? null : _reaction,
            icon: Text(reaction.isEmpty ? '♡' : reaction,
              style: TextStyle(fontSize: 25, color: reaction.isEmpty ? BlinkColors.ink : BlinkColors.orange))),
          Text('$total', style: const TextStyle(fontSize: 11)),
          IconButton(onPressed: _comments, icon: const Icon(Icons.mode_comment_outlined, size: 22)),
          Text('$comments', style: const TextStyle(fontSize: 11)),
          IconButton(onPressed: _share, icon: const Icon(Icons.send_outlined, size: 21)),
          const Spacer(),
          IconButton(onPressed: _toggleSave,
            icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded)),
        ]),
        if ((widget.moment.caption ?? '').isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(widget.moment.caption!, style: const TextStyle(fontSize: 12.5))),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(8), child: Text('Activity unavailable: $_error', style: const TextStyle(fontSize: 10, color: Colors.red))),
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
