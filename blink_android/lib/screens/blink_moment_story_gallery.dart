import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get_video_thumbnail/get_video_thumbnail.dart' as thumb;
import 'package:get_video_thumbnail/index.dart' as thumbnail_format;

import '../core/blink_home_api.dart';
import 'blink_live_moment_card.dart';

/// Four portrait Moment thumbnails per row, matching the approved mobile
/// design. This is a Sliver: the parent page scrolls VERTICALLY, not sideways.
/// The SliverGrid lazily builds visible items, so large galleries stay light.
class BlinkMomentStoryGrid extends StatelessWidget {
  const BlinkMomentStoryGrid({
    super.key,
    required this.moments,
    required this.onOpen,
  });

  final List<BlinkMoment> moments;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => SliverPadding(
    key: const ValueKey('blink-moment-story-grid'),
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        // Preserve the tall portrait thumbnail proportions at any width.
        childAspectRatio: .59,
        crossAxisSpacing: 7,
        mainAxisSpacing: 8,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _MomentStoryThumbnail(
          key: ValueKey('story-${moments[index].id}'),
          moment: moments[index],
          onTap: () => onOpen(index),
        ),
        childCount: moments.length,
      ),
    ),
  );
}

class _MomentStoryThumbnail extends StatefulWidget {
  const _MomentStoryThumbnail({
    super.key,
    required this.moment,
    required this.onTap,
  });

  final BlinkMoment moment;
  final VoidCallback onTap;

  @override
  State<_MomentStoryThumbnail> createState() => _MomentStoryThumbnailState();
}

class _MomentStoryThumbnailState extends State<_MomentStoryThumbnail> {
  Future<Uint8List>? _thumbnail;

  @override
  void initState() {
    super.initState();
    _prepareThumbnail();
  }

  @override
  void didUpdateWidget(covariant _MomentStoryThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment.id != widget.moment.id ||
        oldWidget.moment.mediaUrl != widget.moment.mediaUrl) {
      _prepareThumbnail();
    }
  }

  void _prepareThumbnail() {
    _thumbnail = widget.moment.mediaType == 'video'
        ? thumb.VideoThumbnail.thumbnailData(
            video: BlinkHomeApi.mediaUrl(widget.moment.mediaUrl),
            imageFormat: thumbnail_format.ImageFormat.JPEG,
            maxWidth: 400,
            quality: 75,
          )
        : null;
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF252526),
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: widget.onTap,
      child: Stack(fit: StackFit.expand, children: [
        if (widget.moment.mediaType != 'video')
          Image.network(
            BlinkHomeApi.mediaUrl(widget.moment.mediaUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 36)),
          )
        else
          FutureBuilder<Uint8List>(
            future: _thumbnail,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              return bytes == null || bytes.isEmpty
                ? const Center(child: Icon(Icons.play_circle_outline_rounded,
                  color: Colors.white54, size: 43))
                : Image.memory(bytes, fit: BoxFit.cover,
                  gaplessPlayback: true);
            },
          ),
        const IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x55000000), Colors.transparent, Color(0xE6000000)],
            stops: [0, .43, 1],
          )),
        )),
        Positioned(
          top: 9, right: 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x99000000),
              borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(widget.moment.mediaType == 'video'
                ? Icons.play_arrow_rounded : Icons.photo_outlined,
                color: Colors.white, size: 18),
            ),
          ),
        ),
        Positioned(
          left: 8, top: 8,
          child: Container(width: 5, height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF5900), Color(0xFFFFB06C)]),
              borderRadius: BorderRadius.circular(5))),
        ),
        Positioned(
          left: 9, right: 9, bottom: 10,
          child: Text(widget.moment.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontSize: 12,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
        ),
      ]),
    ),
  );
}

/// Full-screen swipeable stories. Each page reuses the *same* interactions
/// as the regular Moment card: heart, emoji, comments, BP gift and share.
class BlinkMomentViewer extends StatefulWidget {
  const BlinkMomentViewer({
    super.key,
    required this.moments,
    required this.viewerId,
    this.initialIndex = 0,
  });

  final List<BlinkMoment> moments;
  final String viewerId;
  final int initialIndex;

  @override
  State<BlinkMomentViewer> createState() => _BlinkMomentViewerState();
}

class _BlinkMomentViewerState extends State<BlinkMomentViewer> {
  late final PageController _controller;
  late int _index;
  final Set<String> _recordedViews = {};

  @override
  void initState() {
    super.initState();
    _index = widget.moments.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.moments.length - 1).toInt();
    _controller = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordView(_index));
  }

  void _recordView(int index) {
    if (index < 0 || index >= widget.moments.length) return;
    final moment = widget.moments[index];
    if (moment.senderId == widget.viewerId ||
        !_recordedViews.add(moment.id)) return;
    // Record image AND video views; never count the owner's own views.
    BlinkHomeApi.recordView(moment.id).catchError((Object error) {
      debugPrint('Moment view tracking: $error');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moments.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No Moments to view',
          style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          key: const ValueKey('blink-moment-story-viewer'),
          controller: _controller,
          // The four-wide gallery stays unchanged. Once opened, swipe
          // UP for the next Moment and DOWN for the previous Moment.
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(),
          itemCount: widget.moments.length,
          onPageChanged: (index) {
            setState(() => _index = index);
            _recordView(index);
          },
          itemBuilder: (context, index) => BlinkLiveMomentCard(
            key: ValueKey('immersive-${widget.moments[index].id}'),
            moment: widget.moments[index],
            myUserId: widget.viewerId,
            immersive: true,
            active: _index == index,
          ),
        ),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 8, 16, 0),
          child: Row(children: [
            IconButton(
              tooltip: 'Close Moments',
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 3),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Moments ✦',
                  style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w900)),
                Text('Swipe up or down',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0x991D1D25),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x55FFFFFF))),
              child: Text('${_index + 1} / ${widget.moments.length}',
                style: const TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w800))),
          ]),
        )),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 90, 10),
            child: Row(children: [
              const Icon(Icons.swipe_vertical_rounded,
                color: Colors.white54, size: 17),
              const SizedBox(width: 7),
              const Expanded(child: Text('SWIPE TO EXPLORE',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white60, fontSize: 9,
                  fontWeight: FontWeight.w900, letterSpacing: .8))),
              const SizedBox(width: 6),
              Text('${((_index + 1) / widget.moments.length * 100).round()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
          )),
        ),
      ]),
    );
  }
}
