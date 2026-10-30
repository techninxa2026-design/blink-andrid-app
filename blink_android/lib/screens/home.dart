
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

// ==================================================
// BLINK MOMENTS CONFIGURATION
// ==================================================

// Public Moments = other users' public posts.
// My Moments = current user's posts.
//
// Includes both image and video Moments.
//
// NestJS currently returns only active,
// non-expired public Moments.

const int _momentPageSize = 40;

// ==================================================
// SHARED MOMENTS FILTER
// ==================================================

List<BlinkMoment> filterMomentsForViewer(
    List<BlinkMoment> moments,
    String userId, {
      required bool mine,
    }) {
  if (userId.isEmpty) {
    return <BlinkMoment>[];
  }

  return moments.where((moment) {
    if (moment.id.isEmpty ||
        moment.senderId.isEmpty) {
      return false;
    }

    if (mine) {
      // My Moments:
      // ONLY currently logged-in user's posts.
      return moment.senderId == userId;
    }

    // Public Moments:
    // ALL OTHER users' public posts.
    return moment.senderId != userId;
  }).toList();
}

// ==================================================
// HOME SCREEN
// ==================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  final ScrollController _scroll =
  ScrollController();

  final Set<String> _seenServerIds =
  <String>{};

  // 0 = Public Moments
  // 1 = My Moments
  int selectedFeed = 0;

  String _myId = '';

  List<BlinkMoment> _moments =
  <BlinkMoment>[];

  int _activeCount = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;

  int _serverOffset = 0;
  int _requestVersion = 0;
  int _emptySearchPages = 0;

  String? _error;

  bool get _mine => selectedFeed == 1;

  // ==================================================
  // INITIALIZE
  // ==================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _scroll.addListener(_onScroll);

    _load();
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 550) {
      _loadNext();
    }
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  @override
  void dispose() {
    ++_requestVersion;

    WidgetsBinding.instance.removeObserver(this);

    _scroll.removeListener(_onScroll);
    _scroll.dispose();

    super.dispose();
  }

  // ==================================================
  // SWITCH PUBLIC / MY MOMENTS
  // ==================================================

  void _changeFeed(int value) {
    if (value == selectedFeed ||
        (value != 0 && value != 1)) {
      return;
    }

    setState(() {
      selectedFeed = value;
    });

    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }

    _load();
  }

  // ==================================================
  // LOAD REAL MOMENTS FROM DATABASE
  // ==================================================

  Future<void> _load() async {
    final request = ++_requestVersion;
    final mine = _mine;

    setState(() {
      _loading = true;
      _loadingMore = false;
      _hasMore = false;
      _error = null;
    });

    try {
      // Get authenticated user from NestJS.
      final user =
      await BlinkAuthApi.currentUser();

      if (!mounted ||
          request != _requestVersion) {
        return;
      }

      if (user == null) {
        go(
          context,
          '/login',
          replace: true,
        );
        return;
      }

      final userId =
      (user['id'] ?? '').toString();

      if (userId.isEmpty) {
        throw const BlinkHomeError(
          'Cannot identify the signed-in account.',
        );
      }

      // PUBLIC:
      // GET /moments
      //
      // Fetches all active public Moments,
      // then excludes the logged-in user.
      //
      // MY MOMENTS:
      // GET /moments/mine
      //
      // Fetches the current user's uploads.

      final page = await BlinkHomeApi.moments(
        mine: mine,
        skip: 0,
        take: _momentPageSize,
      );

      // Load active Check-ins separately.
      int checkins = _activeCount;

      try {
        checkins =
        await BlinkHomeApi.activeCheckinsCount();
      } catch (_) {
        // Check-ins errors must not hide Moments.
      }

      if (!mounted ||
          request != _requestVersion ||
          mine != _mine) {
        return;
      }

      // Apply the real user-ID filter.
      final visible = filterMomentsForViewer(
        page,
        userId,
        mine: mine,
      );

      setState(() {
        _myId = userId;

        _moments = visible;

        // Remember ALL records returned by server,
        // including records excluded from Public.
        _seenServerIds
          ..clear()
          ..addAll(
            page
                .map((moment) => moment.id)
                .where((id) => id.isNotEmpty),
          );

        // Server offset counts original records,
        // not only the filtered records.
        _serverOffset = page.length;

        _hasMore = page.length == _momentPageSize;

        _activeCount = checkins;
        _emptySearchPages = 0;
        _loading = false;
      });

      // If the first batch contains only the
      // logged-in user's Moments, search farther
      // instead of displaying a false empty state.
      if (!mine &&
          visible.isEmpty &&
          _hasMore) {
        _loadNext();
      }
    } catch (error) {
      if (!mounted ||
          request != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  // ==================================================
  // LOAD MORE PUBLIC MOMENTS
  // ==================================================

  Future<void> _loadNext() async {
    if (!mounted ||
        _loading ||
        _loadingMore ||
        !_hasMore ||
        _myId.isEmpty) {
      return;
    }

    final request = _requestVersion;
    final mine = _mine;
    final offset = _serverOffset;

    setState(() {
      _loadingMore = true;
    });

    try {
      final page =
      await BlinkHomeApi.moments(
        mine: mine,
        skip: offset,
        take: _momentPageSize,
      );

      if (!mounted ||
          request != _requestVersion ||
          mine != _mine) {
        return;
      }

      // Exclude records already returned by
      // previous pages.
      //
      // This also stops repeated pagination
      // if NestJS has not enabled skip/take.

      final unseen = page.where((moment) {
        return moment.id.isNotEmpty &&
            !_seenServerIds.contains(moment.id);
      }).toList();

      // Exclude all of the current user's posts.
      final visible = filterMomentsForViewer(
        unseen,
        _myId,
        mine: mine,
      );

      setState(() {
        _seenServerIds.addAll(
          page
              .map((moment) => moment.id)
              .where((id) => id.isNotEmpty),
        );

        final currentIds = _moments
            .map((moment) => moment.id)
            .toSet();

        _moments.addAll(
          visible.where(
                (moment) =>
            !currentIds.contains(moment.id),
          ),
        );

        _serverOffset += page.length;

        _hasMore = page.length == _momentPageSize && unseen.isNotEmpty;

        _loadingMore = false;

        _emptySearchPages =
        visible.isEmpty
            ? _emptySearchPages + 1
            : 0;
      });

      // Try a few more pages automatically
      // when no other users' Moments have
      // been found yet.
      if (_moments.isEmpty &&
          _hasMore &&
          _emptySearchPages < 5) {
        _loadNext();
      }
    } catch (error) {
      if (!mounted ||
          request != _requestVersion) {
        return;
      }

      setState(() {
        _loadingMore = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load more Moments: $error',
          ),
        ),
      );
    }
  }

  // ==================================================
  // HOME UI
  // ==================================================

  @override
  Widget build(BuildContext context) {
    // Second-level safety filter.
    //
    // Even if old state contains a Moment
    // from another tab, the wrong Moment
    // cannot appear in this tab.

    final visible = filterMomentsForViewer(
      _moments,
      _myId,
      mine: _mine,
    );

    final showItems =
        !_loading &&
            _error == null &&
            visible.isNotEmpty;

    final itemCount =
    showItems
        ? visible.length + 3
        : 3;

    return Scaffold(
      backgroundColor: BlinkColors.canvas,

      // ORIGINAL EXPLORE DRAWER
      drawer: const BlinkFullDrawer(),

      // ORIGINAL BLINK HOME HEADER
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,

        title: const BlinkLogo(
          fontSize: 33,
        ),

        leading: Builder(
          builder: (context) {
            return IconButton(
              tooltip: 'Explore features',

              onPressed: () {
                Scaffold.of(context).openDrawer();
              },

              icon: const Icon(
                Icons.menu_rounded,
                color: BlinkColors.ink,
                size: 25,
              ),
            );
          },
        ),

        actions: const [
          BlinkMessageButton(),
          SizedBox(width: 9),
        ],
      ),

      // HOME CONTENT
      body: RefreshIndicator(
        onRefresh: _load,
        color: BlinkColors.orange,

        child: ListView.builder(
          controller: _scroll,

          physics:
          const AlwaysScrollableScrollPhysics(),

          padding: EdgeInsets.zero,

          itemCount: itemCount,

          itemBuilder: (context, index) {
            // ==================================
            // CHECK-INS
            // ==================================

            if (index == 0) {
              return BlinkHomeCheckins(
                activeCount: _activeCount,
              );
            }

            // ==================================
            // PUBLIC / MY MOMENTS TABS
            // ==================================

            if (index == 1) {
              return Padding(
                padding:
                const EdgeInsets.symmetric(
                  vertical: 13,
                ),

                child: BlinkChips(
                  labels: const [
                    'Public Moments',
                    'My Moments',
                  ],

                  onChanged: _changeFeed,
                ),
              );
            }

            // ==================================
            // LOADING STATE
            // ==================================

            if (index == 2 && _loading) {
              return const Padding(
                padding: EdgeInsets.all(32),

                child: Center(
                  child: CircularProgressIndicator(
                    color: BlinkColors.orange,
                  ),
                ),
              );
            }

            // ==================================
            // ERROR STATE
            // ==================================

            if (index == 2 &&
                _error != null) {
              return _feedMessage(
                _error!,
                button: 'Retry',
                onPressed: _load,
                icon: Icons.refresh_rounded,
              );
            }

            // ==================================
            // EMPTY PUBLIC FEED
            // ==================================

            if (index == 2 &&
                visible.isEmpty) {
              if (_hasMore) {
                return _feedMessage(
                  _loadingMore
                      ? 'Finding public Moments from other members...'
                      : 'More public Moments may be available.',

                  button:
                  _loadingMore
                      ? null
                      : 'Find more',

                  onPressed:
                  _loadingMore
                      ? null
                      : _loadNext,

                  icon: Icons.refresh_rounded,
                );
              }

              return _feedMessage(
                _mine
                    ? 'You have not uploaded any Moments yet.'
                    : 'No active public Moments from other members are available.',

                button: 'Capture a Moment',

                onPressed: () {
                  go(context, '/capture');
                },

                icon: Icons.camera_alt_outlined,
              );
            }

            // ==================================
            // LOAD MORE FOOTER
            // ==================================

            if (index == visible.length + 2) {
              if (!_hasMore) {
                return const SizedBox(
                  height: 25,
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16),

                child: Center(
                  child: _loadingMore
                      ? const CircularProgressIndicator(
                    color: BlinkColors.orange,
                  )
                      : TextButton.icon(
                    onPressed: _loadNext,

                    icon: const Icon(
                      Icons.expand_more_rounded,
                    ),

                    label: const Text(
                      'Load more Moments',
                    ),
                  ),
                ),
              );
            }

            // ==================================
            // REAL MOMENT CARD
            // ==================================

            final moment = visible[index - 2];

            return BlinkLiveMomentCard(
              key: ValueKey(
                'home-${moment.id}',
              ),

              moment: moment,

              myUserId: _myId,

              onDeleted: _load,
            );
          },
        ),
      ),

      // ORIGINAL BOTTOM NAVIGATION
      bottomNavigationBar: const BlinkBottomBar(active: 'home'),
    );
  }
}

// ==================================================
// SHARED EMPTY / ERROR MESSAGE
// ==================================================

Widget _feedMessage(
    String message, {
      String? button,
      VoidCallback? onPressed,
      IconData icon = Icons.refresh_rounded,
    }) {
  return Padding(
    padding: const EdgeInsets.all(28),

    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
        ),

        if (button != null &&
            onPressed != null) ...[
          const SizedBox(height: 12),

          TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(button),
          ),
        ],
      ],
    ),
  );
}

// ==================================================
// SEPARATE MOMENTS SCREEN
// Uses exactly the same feed rules as Home.
// ==================================================

class MomentsFeedScreen extends StatefulWidget {
  const MomentsFeedScreen({super.key, this.initialMine = false});
  final bool initialMine;

  @override
  State<MomentsFeedScreen> createState() =>
      _MomentsFeedScreenState();
}

class _MomentsFeedScreenState
    extends State<MomentsFeedScreen> {
  final ScrollController _scroll =
  ScrollController();

  final Set<String> _seenServerIds =
  <String>{};

  late bool _mine;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;

  int _serverOffset = 0;
  int _requestVersion = 0;
  int _emptySearchPages = 0;

  String _myId = '';
  String? _error;

  List<BlinkMoment> _items =
  <BlinkMoment>[];

  @override
  void initState() {
    super.initState();

    _mine = widget.initialMine;
    _scroll.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 550) {
      _loadNext();
    }
  }

  @override
  void dispose() {
    ++_requestVersion;

    _scroll.removeListener(_onScroll);
    _scroll.dispose();

    super.dispose();
  }

  void _changeTab(int index) {
    final mine = index == 1;

    if (_mine == mine) {
      return;
    }

    setState(() {
      _mine = mine;
    });

    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }

    _load();
  }

  // ================================================
  // LOAD MOMENTS
  // ================================================

  Future<void> _load() async {
    final request = ++_requestVersion;
    final mine = _mine;

    setState(() {
      _loading = true;
      _loadingMore = false;
      _hasMore = false;
      _error = null;
    });

    try {
      final self =
      await BlinkAuthApi.currentUser();

      if (!mounted ||
          request != _requestVersion) {
        return;
      }

      if (self == null) {
        go(
          context,
          '/login',
          replace: true,
        );
        return;
      }

      final userId =
      (self['id'] ?? '').toString();

      if (userId.isEmpty) {
        throw const BlinkHomeError(
          'Missing signed-in account ID.',
        );
      }

      final page =
      await BlinkHomeApi.moments(
        mine: mine,
        skip: 0,
        take: _momentPageSize,
      );

      if (!mounted ||
          request != _requestVersion ||
          mine != _mine) {
        return;
      }

      final visible = filterMomentsForViewer(
        page,
        userId,
        mine: mine,
      );

      setState(() {
        _myId = userId;

        _items = visible;

        _seenServerIds
          ..clear()
          ..addAll(
            page
                .map((moment) => moment.id)
                .where((id) => id.isNotEmpty),
          );

        _serverOffset = page.length;

        _hasMore = page.length == _momentPageSize;

        _emptySearchPages = 0;
        _loading = false;
      });

      if (!mine &&
          visible.isEmpty &&
          _hasMore) {
        _loadNext();
      }
    } catch (error) {
      if (!mounted ||
          request != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  // ================================================
  // PAGINATE PUBLIC MOMENTS
  // ================================================

  Future<void> _loadNext() async {
    if (!mounted ||
        _loading ||
        _loadingMore ||
        !_hasMore ||
        _myId.isEmpty) {
      return;
    }

    final request = _requestVersion;
    final mine = _mine;
    final offset = _serverOffset;

    setState(() {
      _loadingMore = true;
    });

    try {
      final page =
      await BlinkHomeApi.moments(
        mine: mine,
        skip: offset,
        take: _momentPageSize,
      );

      if (!mounted ||
          request != _requestVersion ||
          mine != _mine) {
        return;
      }

      final unseen = page.where(
            (moment) {
          return moment.id.isNotEmpty &&
              !_seenServerIds.contains(
                moment.id,
              );
        },
      ).toList();

      final visible = filterMomentsForViewer(
        unseen,
        _myId,
        mine: mine,
      );

      setState(() {
        _seenServerIds.addAll(
          page
              .map((moment) => moment.id)
              .where((id) => id.isNotEmpty),
        );

        final known = _items
            .map((moment) => moment.id)
            .toSet();

        _items.addAll(
          visible.where(
                (moment) =>
            !known.contains(moment.id),
          ),
        );

        _serverOffset += page.length;

        _hasMore = page.length == _momentPageSize && unseen.isNotEmpty;

        _loadingMore = false;

        _emptySearchPages =
        visible.isEmpty
            ? _emptySearchPages + 1
            : 0;
      });

      if (_items.isEmpty &&
          _hasMore &&
          _emptySearchPages < 5) {
        _loadNext();
      }
    } catch (error) {
      if (!mounted ||
          request != _requestVersion) {
        return;
      }

      setState(() {
        _loadingMore = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load more Moments: $error',
          ),
        ),
      );
    }
  }

  // ================================================
  // MOMENTS SCREEN UI
  // ================================================

  @override
  Widget build(BuildContext context) {
    final visible = filterMomentsForViewer(
      _items,
      _myId,
      mine: _mine,
    );

    return BlinkScreen(
      title: 'Moments',
      bottom: false,

      trailing: IconButton(
        tooltip: 'Create Moment',

        onPressed: () {
          go(context, '/capture');
        },

        icon: const Icon(
          Icons.add_circle_rounded,
          color: BlinkColors.orange,
        ),
      ),

      child: RefreshIndicator(
        color: BlinkColors.orange,
        onRefresh: _load,

        child: ListView(
          controller: _scroll,

          physics:
          const AlwaysScrollableScrollPhysics(),

          children: [
            const SectionHeading(
              'Moments',
              subtitle:
              'Public Moments from other Blink members',
            ),

            BlinkChips(
              initial: widget.initialMine ? 1 : 0,
              labels: const [
                'Public Moments',
                'My Moments',
              ],
              onChanged: _changeTab,
            ),

            const SizedBox(height: 8),

            // LOADING
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(25),

                child: Center(
                  child: CircularProgressIndicator(
                    color: BlinkColors.orange,
                  ),
                ),
              ),

            // ERROR
            if (_error != null)
              _feedMessage(
                _error!,
                button: 'Retry',
                onPressed: _load,
              ),

            // EMPTY
            if (!_loading &&
                _error == null &&
                visible.isEmpty)
              _feedMessage(
                _hasMore
                    ? 'Looking for more Moments from other members...'
                    : _mine
                    ? 'You have not uploaded any Moments yet.'
                    : 'No active public Moments from other members are available.',

                button:
                _hasMore && !_loadingMore
                    ? 'Find more'
                    : null,

                onPressed:
                _hasMore && !_loadingMore
                    ? _loadNext
                    : null,
              ),

            // REAL MOMENT CARDS
            if (!_loading &&
                _error == null)
              ...visible.map(
                    (moment) =>
                    BlinkLiveMomentCard(
                      key: ValueKey(
                        'moments-${moment.id}',
                      ),

                      moment: moment,
                      myUserId: _myId,
                      onDeleted: _load,
                    ),
              ),

            // LOAD MORE
            if (!_loading &&
                _error == null &&
                _hasMore)
              Padding(
                padding: const EdgeInsets.all(16),

                child: Center(
                  child: _loadingMore
                      ? const CircularProgressIndicator(
                    color: BlinkColors.orange,
                  )
                      : TextButton(
                    onPressed: _loadNext,

                    child: const Text(
                      'Load more Moments',
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// EXPLORE SCREEN
// Original design and destinations preserved.
// ==================================================

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
      logoTitle: false,
      bottom: false,

      child: ListView(
        children: [
          const SectionHeading(
            'Explore Blink',
            subtitle:
            'Discover everything Blink has to offer',
          ),

          const BlinkSearchBox(),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              15,
              7,
              15,
              18,
            ),

            child: GridView.builder(
              shrinkWrap: true,

              physics:
              const NeverScrollableScrollPhysics(),

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
                  borderRadius:
                  BorderRadius.circular(17),

                  onTap: () {
                    go(context, tile.route);
                  },

                  child: Container(
                    padding:
                    const EdgeInsets.all(10),

                    decoration: BoxDecoration(
                      color: tile.background,

                      borderRadius:
                      BorderRadius.circular(17),
                    ),

                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,

                      children: [
                        Container(
                          width: 46,
                          height: 46,

                          decoration:
                          const BoxDecoration(
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

                          overflow:
                          TextOverflow.ellipsis,

                          textAlign:
                          TextAlign.center,

                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          tile.subtitle,

                          maxLines: 2,

                          overflow:
                          TextOverflow.ellipsis,

                          textAlign:
                          TextAlign.center,

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

// ==================================================
// EXPLORE ITEM
// ==================================================

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

// ==================================================
// CAPTURE SCREEN
// Uses the real camera/gallery/upload screen.
// ==================================================

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BlinkRealCaptureScreen();
  }
}
