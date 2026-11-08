
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/nav.dart';
import '../core/blink_auth_api.dart';
import '../core/blink_home_api.dart';

import '../widgets/ui.dart';
import '../widgets/blink_motion.dart';
import '../widgets/home_navigation.dart';
import '../widgets/blink_full_drawer.dart';

import 'blink_moment_story_gallery.dart';
import 'blink_real_capture.dart';

// ============================================================
// BLINK MOMENTS CONFIGURATION
// ============================================================

const int _momentPageSize = 40;

// Public Moments: every OTHER user's public Moments.
// My Moments: only the currently authenticated user's Moments.
//
// The API must use the same database as the Blink web application.

List<BlinkMoment> filterMomentsForViewer(
    List<BlinkMoment> moments,
    String userId, {
      required bool mine,
    }) {
  if (userId.trim().isEmpty) {
    return <BlinkMoment>[];
  }

  return moments.where((moment) {
    if (moment.id.trim().isEmpty ||
        moment.senderId.trim().isEmpty) {
      return false;
    }

    if (mine) {
      return moment.senderId == userId;
    }

    return moment.senderId != userId;
  }).toList();
}

// ============================================================
// PAGINATION RESULT
// ============================================================

class _MomentBatch {
  const _MomentBatch({
    required this.items,
    required this.seenIds,
    required this.nextOffset,
    required this.hasMore,
    required this.serverCount,
  });

  final List<BlinkMoment> items;
  final Set<String> seenIds;
  final int nextOffset;
  final bool hasMore;
  final int serverCount;
}

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlinkColors.canvas,

      drawer: const BlinkFullDrawer(),

      appBar: AppBar(
        backgroundColor: BlinkColors.surface,
        centerTitle: true,
        elevation: 0,

        title: const BlinkLogo(
          fontSize: 33,
        ),

        leading: Builder(
          builder: (scaffoldContext) {
            return IconButton(
              tooltip: 'Open Blink navigation',
              icon: const Icon(
                Icons.menu_rounded,
                color: BlinkColors.orangeDark,
                size: 26,
              ),
              onPressed: () {
                Scaffold.of(scaffoldContext).openDrawer();
              },
            );
          },
        ),

        actions: const [
          BlinkMessageButton(),
          SizedBox(width: 8),
        ],
      ),

      body: const _BlinkMomentsFeed(
        showCheckins: true,
      ),

      bottomNavigationBar: const BlinkBottomBar(
        active: 'home',
      ),
    );
  }
}

// ============================================================
// SEPARATE MOMENTS SCREEN
// Supports:
// /moments
// /moments/mine
// ============================================================

class MomentsFeedScreen extends StatelessWidget {
  const MomentsFeedScreen({
    super.key,
    this.initialMine = false,
  });

  final bool initialMine;

  @override
  Widget build(BuildContext context) {
    return BlinkScreen(
      title: 'Moments',
      active: 'home',
      logoTitle: false,

      trailing: IconButton(
        tooltip: 'Create Moment',
        icon: const Icon(
          Icons.add_circle_rounded,
          color: BlinkColors.orange,
          size: 27,
        ),
        onPressed: () {
          go(context, '/capture');
        },
      ),

      child: _BlinkMomentsFeed(
        initialMine: initialMine,
      ),
    );
  }
}

// ============================================================
// REUSABLE REAL MOMENTS FEED
// ============================================================

class _BlinkMomentsFeed extends StatefulWidget {
  const _BlinkMomentsFeed({
    this.showCheckins = false,
    this.initialMine = false,
  });

  final bool showCheckins;
  final bool initialMine;

  @override
  State<_BlinkMomentsFeed> createState() =>
      _BlinkMomentsFeedState();
}

class _BlinkMomentsFeedState extends State<_BlinkMomentsFeed>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();

  final Set<String> _seenIds = <String>{};

  List<BlinkMoment> _items = <BlinkMoment>[];

  late bool _mine;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;

  String _viewerId = '';
  String? _error;

  int _offset = 0;
  int _requestVersion = 0;
  int _checkinCount = 0;
  int _serverCount = 0;

  @override
  void initState() {
    super.initState();

    _mine = widget.initialMine;

    WidgetsBinding.instance.addObserver(this);

    _scroll.addListener(_onScroll);

    _refresh();
  }

  @override
  void dispose() {
    ++_requestVersion;

    WidgetsBinding.instance.removeObserver(this);

    _scroll.removeListener(_onScroll);
    _scroll.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  // ==========================================================
  // INFINITE SCROLL
  // ==========================================================

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }

    if (_scroll.position.extentAfter < 550) {
      _loadMore();
    }
  }

  // ==========================================================
  // SWITCH PUBLIC / MY MOMENTS
  // ==========================================================

  void _changeFeed(int index) {
    final nextMine = index == 1;

    if (_mine == nextMine) {
      return;
    }

    setState(() {
      _mine = nextMine;
      _items = <BlinkMoment>[];
    });

    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }

    _refresh();
  }

  // ==========================================================
  // LOAD CHECK-INS INDEPENDENTLY
  // Never block Moments waiting for Check-Ins.
  // ==========================================================

  Future<void> _loadCheckins(int requestVersion) async {
    try {
      final count = await BlinkHomeApi.activeCheckinsCount();

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _checkinCount = count;
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Blink Check-Ins] $error');
      }
    }
  }

  // ==========================================================
  // GET VISIBLE MOMENTS FROM SERVER
  //
  // Public:
  // GET /moments?skip=0&take=40
  //
  // My:
  // GET /moments/mine?skip=0&take=40
  //
  // The server applies the global feed visibility rule.
  // Flutter also checks senderId for safety.
  // ==========================================================

  Future<_MomentBatch> _fetchBatch({
    required bool mine,
    required String viewerId,
    required int startOffset,
    required Set<String> existingIds,
  }) async {
    final collected = <BlinkMoment>[];
    final seen = Set<String>.from(existingIds);

    int offset = startOffset;
    int returnedTotal = 0;
    bool hasMore = false;

    // Avoid appearing empty if an older server returns
    // a page containing only the logged-in user's posts.
    //
    // At most five pages are scanned per operation.
    // Further pages remain available through Load More.

    for (int scan = 0; scan < 5; scan++) {
      final page = await BlinkHomeApi.moments(
        mine: mine,
        skip: offset,
        take: _momentPageSize,
      );

      returnedTotal += page.length;
      offset += page.length;

      final unseen = <BlinkMoment>[];

      for (final moment in page) {
        if (moment.id.isEmpty) {
          continue;
        }

        if (seen.add(moment.id)) {
          unseen.add(moment);
        }
      }

      final visible = filterMomentsForViewer(
        unseen,
        viewerId,
        mine: mine,
      );

      collected.addAll(visible);

      if (kDebugMode) {
        debugPrint('========== BLINK MOMENTS DEBUG ==========');
        debugPrint('API: ${BlinkHomeApi.baseUrl}');
        debugPrint('Viewer ID: $viewerId');
        debugPrint('Feed: ${mine ? "MY MOMENTS" : "PUBLIC MOMENTS"}');
        debugPrint('Page offset: ${offset - page.length}');
        debugPrint('Server returned: ${page.length}');
        debugPrint('Visible after filter: ${visible.length}');

        for (final moment in page) {
          debugPrint(
            'Moment ID: ${moment.id} '
                '| Owner: ${moment.senderId} '
                '| Type: ${moment.mediaType}',
          );
        }

        debugPrint('=========================================');
      }

      // If the backend repeats an existing page,
      // stop instead of requesting the same data forever.
      hasMore =
          page.length == _momentPageSize && unseen.isNotEmpty;

      if (!hasMore || collected.isNotEmpty) {
        break;
      }
    }

    return _MomentBatch(
      items: collected,
      seenIds: seen,
      nextOffset: offset,
      hasMore: hasMore,
      serverCount: returnedTotal,
    );
  }

  // ==========================================================
  // REFRESH FEED
  // ==========================================================

  Future<void> _refresh() async {
    final request = ++_requestVersion;
    final mine = _mine;

    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _hasMore = false;

      _items = <BlinkMoment>[];
      _seenIds.clear();

      _viewerId = '';
      _offset = 0;
      _serverCount = 0;
    });

    if (widget.showCheckins) {
      unawaited(_loadCheckins(request));
    }

    try {
      // Always verify the active account against NestJS.
      final user = await BlinkAuthApi.currentUser();

      if (!mounted || request != _requestVersion) {
        return;
      }

      if (user == null) {
        go(context, '/login', replace: true);
        return;
      }

      final viewerId = (user['id'] ?? '').toString().trim();

      if (viewerId.isEmpty) {
        throw const BlinkHomeError(
          'Cannot identify the logged-in Blink user.',
        );
      }

      final result = await _fetchBatch(
        mine: mine,
        viewerId: viewerId,
        startOffset: 0,
        existingIds: <String>{},
      );

      if (!mounted ||
          request != _requestVersion ||
          mine != _mine) {
        return;
      }

      setState(() {
        _viewerId = viewerId;

        _items = result.items;

        _seenIds
          ..clear()
          ..addAll(result.seenIds);

        _offset = result.nextOffset;
        _hasMore = result.hasMore;
        _serverCount = result.serverCount;

        _loading = false;
        _error = null;
      });

      if (kDebugMode) {
        debugPrint(
          '[Blink Feed] Viewer=$viewerId '
              'Mine=$mine '
              'Server=$_serverCount '
              'Visible=${_items.length}',
        );
      }
    } catch (error) {
      if (!mounted || request != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });

      if (kDebugMode) {
        debugPrint('[Blink Feed Error] $error');
      }
    }
  }

  // ==========================================================
  // LOAD MORE MOMENTS
  // ==========================================================

  Future<void> _loadMore() async {
    if (!mounted ||
        _loading ||
        _loadingMore ||
        !_hasMore ||
        _viewerId.isEmpty) {
      return;
    }

    final request = _requestVersion;
    final mine = _mine;
    final offset = _offset;

    setState(() {
      _loadingMore = true;
    });

    try {
      final result = await _fetchBatch(
        mine: mine,
        viewerId: _viewerId,
        startOffset: offset,
        existingIds: _seenIds,
      );

      if (!mounted ||
          request != _requestVersion ||
          mine != _mine) {
        return;
      }

      setState(() {
        _seenIds
          ..clear()
          ..addAll(result.seenIds);

        _items.addAll(result.items);

        _offset = result.nextOffset;
        _hasMore = result.hasMore;
        _serverCount += result.serverCount;

        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _requestVersion) {
        return;
      }

      setState(() {
        _loadingMore = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load more Moments: $error'),
        ),
      );
    }
  }

  // ==========================================================
  // FEED HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.showCheckins)
        BlinkHomeCheckins(activeCount: _checkinCount),
      BlinkReveal(child: Container(
        margin: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF2B1E27), Color(0xFF933E32),
              Color(0xFFFA6925)]),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(29),
            topRight: Radius.circular(11),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(29))),
        child: Stack(children: [
          Positioned(top: -57, right: -51,
            child: IgnorePointer(child: Container(
              width: 192, height: 192,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0x39FFFFFF), width: 31)),
            ))),
          const Positioned(right: 10, bottom: -44,
            child: IgnorePointer(child: Icon(Icons.auto_awesome_rounded,
              size: 142, color: Color(0x1CFFFFFF)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 19, 17, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x30FFFFFF),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0x38FFFFFF))),
                    child: const Text('✦  THE BLINK FEED',
                      style: TextStyle(fontSize: 9.5, letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white))),
                  const Spacer(),
                  if (!_loading && _items.isNotEmpty)
                    Text(_items.length.toString() + ' moments',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFFFFE3D4),
                        fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 13),
                const Text('Your world, right now.',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24,
                    letterSpacing: -.7, height: 1.1,
                    color: Colors.white,
                    fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Discover real stories. Create one worth sharing.',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.7,
                    height: 1.35, color: Color(0xFFFFE5D9))),
                const SizedBox(height: 15),
                Wrap(spacing: 8, runSpacing: 9, children: [
                  FilledButton.icon(
                    onPressed: () => go(context, '/capture'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 43),
                      backgroundColor: Colors.white,
                      foregroundColor: BlinkColors.orangeDark,
                      padding: const EdgeInsets.symmetric(horizontal: 14)),
                    icon: const Icon(Icons.add_a_photo_rounded, size: 17),
                    label: const Text('Create a Moment')),
                  OutlinedButton.icon(
                    onPressed: () => _changeFeed(1),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 43),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x98FFFFFF)),
                      padding: const EdgeInsets.symmetric(horizontal: 13)),
                    icon: const Icon(Icons.grid_view_rounded, size: 16),
                    label: const Text('My Moments')),
                ]),
              ],
            ),
          ),
        ]),
      )),
      BlinkSectionBand(
        eyebrow: _mine ? 'YOUR COLLECTION' : 'THE COMMUNITY',
        title: _mine ? 'Your Moments' : 'Discover Moments',
        subtitle: _mine ? 'Everything you have shared'
          : 'People, places and stories from across Blink',
        mood: BlinkMood.studio,
        icon: Icons.auto_awesome_rounded,
      ),
      BlinkChips(
        key: ValueKey('moments-' + (_mine ? 'mine' : 'public')),
        initial: _mine ? 1 : 0,
        labels: const ['Public Moments', 'My Moments'],
        onChanged: _changeFeed,
      ),
      const SizedBox(height: 13),
    ]);
  }

  // ==========================================================
  // FEED FOOTER / LOADING / EMPTY
  // ==========================================================

  Widget _buildFooter() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(34),
        child: Center(
          child: CircularProgressIndicator(
            color: BlinkColors.orange,
          ),
        ),
      );
    }

    if (_error != null) {
      return _feedState(
        icon: Icons.error_outline_rounded,
        message: _error!,
        action: 'Retry',
        onPressed: _refresh,
      );
    }

    if (_items.isEmpty) {
      return _feedState(
        icon: _mine
            ? Icons.photo_library_outlined
            : Icons.public_rounded,
        message: _mine
            ? 'You have not uploaded any Moments yet.'
            : _hasMore
            ? 'Searching more public Moments from other Blink members.'
            : 'No public Moments from other members were returned by the server.',
        action: _hasMore ? 'Find more Moments' : 'Refresh',
        onPressed: _hasMore ? _loadMore : _refresh,
      );
    }

    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _loadingMore
              ? const CircularProgressIndicator(
            color: BlinkColors.orange,
          )
              : OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more_rounded),
            label: const Text('Load more Moments'),
          ),
        ),
      );
    }

    return const SizedBox(height: 24);
  }

  Widget _feedState({
    required IconData icon,
    required String message,
    required String action,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 38, 22, 24),
      child: Column(
        children: [
          Icon(
            icon,
            color: BlinkColors.orange,
            size: 45,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BlinkColors.ink,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(action),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MAIN FEED UI
  //
  // One continuous top-to-bottom scroll. The four-column Moments grid is a
  // lazy SliverGrid (no nested sideways carousel and no nested scroll view).
  // Reels remain a separate vertical PageView in reels.dart.
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: BlinkColors.orange,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          BlinkMomentStoryGrid(
            moments: _items,
            onOpen: (selected) async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => BlinkMomentViewer(
                  moments: List<BlinkMoment>.of(_items),
                  initialIndex: selected,
                  viewerId: _viewerId,
                ),
              ));
              if (mounted) await _refresh();
            },
          ),
          SliverToBoxAdapter(child: _buildFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

// ============================================================
// EXPLORE SCREEN
// Preserves the existing Blink sections and destinations.
// ============================================================

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = <_ExploreItem>[
      _ExploreItem(
        'Secrets',
        'Guess and reveal',
        Icons.auto_awesome_rounded,
        Color(0xFFFFE9E5),
        '/secrets',
        Color(0xFFED3552),
      ),
      _ExploreItem(
        'Hearts',
        'Express feelings',
        Icons.favorite_rounded,
        Color(0xFFFFE4E9),
        '/hearts',
        Color(0xFFF2466D),
      ),
      _ExploreItem(
        'Check-ins',
        'Create experiences',
        Icons.location_on_rounded,
        Color(0xFFE4F6E7),
        '/checkins',
        Color(0xFF2DA85B),
      ),
      _ExploreItem(
        'IRL Plans',
        'Connect offline',
        Icons.location_city_rounded,
        Color(0xFFE5F1FD),
        '/irl',
        Color(0xFF287BDA),
      ),
      _ExploreItem(
        'Exchange',
        'Explore services',
        Icons.shopping_bag_rounded,
        Color(0xFFFFEDDE),
        '/exchange',
        Color(0xFFEF8D00),
      ),
      _ExploreItem(
        'Business Match',
        'Discover opportunities',
        Icons.business_center_rounded,
        Color(0xFFFFEACD),
        '/business',
        Color(0xFFFF7900),
      ),
      _ExploreItem(
        'Creator Tasks',
        'Participate & earn',
        Icons.task_alt_rounded,
        Color(0xFFF4E6FE),
        '/tasks',
        Color(0xFF964ACC),
      ),
      _ExploreItem(
        'BP Rewards',
        'Your Blink Points',
        Icons.stars_rounded,
        Color(0xFFE9F5FF),
        '/wallet',
        Color(0xFF4084DB),
      ),
      _ExploreItem(
        'Moments',
        'Everyday moments',
        Icons.camera_alt_rounded,
        Color(0xFFFFE3DB),
        '/moments',
        BlinkColors.orange,
      ),
      _ExploreItem(
        'Messages',
        'Stay connected',
        Icons.chat_bubble_outline_rounded,
        Color(0xFFE4FAEF),
        '/inbox',
        Color(0xFF26A978),
      ),
    ];

    return BlinkScreen(
      title: 'Explore',
      active: 'explore',
      logoTitle: false,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const BlinkFeatureHero(
            eyebrow:'ONE APP. SO MANY STORIES.',
            title:'Find your next thing.',
            subtitle:'New people, creative challenges, real-life plans and conversations that matter.',
            icon:Icons.explore_rounded,
            mood:BlinkMood.studio,
          ),
          const SectionHeading(
            'Explore Blink',
            subtitle: 'Every space has something for you',
          ),

          const BlinkSearchBox(),

          Padding(
            padding: const EdgeInsets.fromLTRB(15, 7, 15, 18),
            child: LayoutBuilder(builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                // Fixed aspect ratios truncate cards at large accessibility
                // sizes. Give subtitles enough room instead of overflow.
                mainAxisExtent: 136 +
                  34 * MediaQuery.textScalerOf(context).scale(1.0),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final tile = items[index];

                return Material(
                  color:Colors.transparent,
                  child:InkWell(
                    borderRadius:BorderRadius.circular(22),
                    onTap:()=>go(context,tile.route),
                    child:Container(
                      padding:const EdgeInsets.all(11),
                      decoration:BoxDecoration(
                        gradient:LinearGradient(
                          begin:Alignment.topLeft,end:Alignment.bottomRight,
                          colors:[Colors.white,Color.lerp(tile.background,
                            Colors.white,.23)!]),
                        borderRadius:BorderRadius.circular(22),
                        border:Border.all(color:const Color(0xFFFFDBC7)),
                        boxShadow:const [
                          BoxShadow(color:Color(0x12AF5918),blurRadius:17,
                            offset:Offset(0,7)),
                        ],
                      ),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:Colors.white,
                            borderRadius:BorderRadius.circular(16),
                            border:Border.all(color:const Color(0xFFFFD8C5)),
                            boxShadow:const [
                              BoxShadow(color:Color(0x12000000),blurRadius:9,
                                offset:Offset(0,3)),
                            ],
                          ),
                          child: Icon(
                            tile.icon,
                            color: tile.iconColor,
                            size: 25,
                          ),
                        ),
                        const SizedBox(height: 11),
                        Text(
                          tile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: BlinkColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tile.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF686868),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            )),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EXPLORE ITEM MODEL
// ============================================================

class _ExploreItem {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color background;
  final String route;
  final Color iconColor;

  const _ExploreItem(
      this.name,
      this.subtitle,
      this.icon,
      this.background,
      this.route,
      this.iconColor,
      );
}

// ============================================================
// CAPTURE SCREEN
// Same real camera/gallery/upload implementation.
// ============================================================

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BlinkRealCaptureScreen();
  }
}
