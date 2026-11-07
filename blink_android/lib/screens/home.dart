
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/nav.dart';
import '../core/blink_auth_api.dart';
import '../core/blink_home_api.dart';

import '../widgets/ui.dart';
import '../widgets/home_navigation.dart';
import '../widgets/blink_full_drawer.dart';

import 'blink_live_moment_card.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showCheckins)
          BlinkHomeCheckins(
            activeCount: _checkinCount,
          ),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR PEOPLE, YOUR MOMENTS',
                style: TextStyle(
                  fontSize: 10,
                  color: BlinkColors.orange,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Moments ✦',
                style: TextStyle(
                  fontSize: 26,
                  color: BlinkColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        BlinkChips(
          key: ValueKey('moments-${_mine ? "mine" : "public"}'),
          initial: _mine ? 1 : 0,
          labels: const [
            'Public Moments',
            'My Moments',
          ],
          onChanged: _changeFeed,
        ),

        const SizedBox(height: 10),

        // Debug diagnostics remain in debugPrint, not in the user-facing UI.
      ],
    );
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
  // ListView.builder avoids creating all video players at once.
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: BlinkColors.orange,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),

        // 1 header + N Moments + 1 footer
        itemCount: _items.length + 2,

        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader();
          }

          if (index == _items.length + 1) {
            return _buildFooter();
          }

          final moment = _items[index - 1];

          return BlinkLiveMomentCard(
            key: ValueKey(
              '${_mine ? "my" : "public"}-${moment.id}',
            ),
            moment: moment,
            myUserId: _viewerId,
            onDeleted: _refresh,
          );
        },
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
          const SectionHeading(
            'Explore Blink',
            subtitle: 'Discover everything Blink has to offer',
          ),

          const BlinkSearchBox(),

          Padding(
            padding: const EdgeInsets.fromLTRB(15, 7, 15, 18),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.12,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final tile = items[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => go(context, tile.route),

                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tile.background,
                      borderRadius: BorderRadius.circular(17),
                    ),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0xCCFFFFFF),
                            shape: BoxShape.circle,
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
                );
              },
            ),
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
