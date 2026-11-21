import 'package:flutter/material.dart';

import '../core/blink_auth_api.dart';
import '../core/theme.dart';
import '../core/nav.dart';
import '../core/live_api.dart';
import '../widgets/ui.dart';
import '../widgets/blink_motion.dart';

/// BP Wallet reflects the real MySQL user.blinkPoints balance.
/// The API does not yet expose a transaction ledger, so never invent one.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletState();
}
class _WalletState extends State<WalletScreen> {
  String? balance;
  String? error;
  bool loading = true;
  bool historyAvailable = false;
  List<Map<String,dynamic>> history = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final profile = obj(await LiveApi.call('GET', '/profile/me'));
      // Older servers may not yet have the authenticated reward-history
      // endpoint. Never hide the real balance if that optional call fails.
      List<Map<String,dynamic>> received = [];
      bool available = false;
      try {
        final result = obj(await LiveApi.call('GET', '/profile/me/bp-activity'));
        received = arr(result['items']).map((x) => obj(x)).toList();
        available = true;
      } catch (exception) {
        debugPrint('Blink BP reward activity unavailable: $exception');
      }
      if (!mounted) return;
      setState(() {
        balance = profile['blinkPoints']?.toString();
        history = received;
        historyAvailable = available;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'BP Wallet',
    active: 'explore',
    child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const BlinkSectionBand(
            eyebrow: 'REAL REWARDS',
            title: 'Your Blink Points',
            subtitle: 'Rewards earned through real Blink activity',
            mood: BlinkMood.rewards,
            icon: Icons.workspace_premium_rounded,
            padding: EdgeInsets.fromLTRB(0, 1, 0, 14)),
          BlinkReveal(child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,end: Alignment.bottomRight,
                colors:[Color(0xFF2D2018),Color(0xFF8F521A),Color(0xFFEFAB42)]),
              borderRadius: BorderRadius.circular(27),
              boxShadow: const [BoxShadow(color: Color(0x55D98738),
                blurRadius: 28,offset: Offset(0, 12))],
            ),
            child: Stack(children: [
              Positioned(right:-55,top:-69,
                child:Container(width:185,height:185,
                  decoration:BoxDecoration(shape:BoxShape.circle,
                    border:Border.all(color:Color(0x40FFFFFF),width:33)))),
              Positioned(right:17,bottom:15,
                child:Icon(Icons.stars_rounded,color:Color(0x70FFFFFF),size:82)),
              Padding(padding:const EdgeInsets.all(23),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const Text('✦  YOUR BLINK REWARDS',style:TextStyle(
                    fontSize:10,color:Color(0xFFFFE0AC),
                    letterSpacing:1.4,fontWeight:FontWeight.w900)),
                  const SizedBox(height:24),
                  const Text('Available balance',style:TextStyle(
                    color:Colors.white70,fontSize:13)),
                  const SizedBox(height:7),
                  if (loading || balance == null ||
                      double.tryParse(balance!) == null)
                    Text(loading ? 'Loading…' : 'Unavailable',
                      style: const TextStyle(color: Colors.white,
                        fontSize: 30, fontWeight: FontWeight.w900))
                  else
                    TweenAnimationBuilder<double>(
                      duration: BlinkMotion.duration(context, ms: 740),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0, end: double.parse(balance!)),
                      builder: (_, value, __) => Text(
                        value.toStringAsFixed(0) + ' BP',
                        style: const TextStyle(color: Colors.white,
                          fontSize: 38, fontWeight: FontWeight.w900,
                          letterSpacing: -1.1))),

                  const SizedBox(height:25),
                  const Text('Earned through your real Blink activity',
                    style:TextStyle(color:Colors.white70,fontSize:11)),
                ]),
              ),
            ]),
          )),
          if (error != null) liveError(error, _load),
          if (!loading && balance == null && error == null)
            const ListTile(title: Text('Balance not available'),
              subtitle: Text('Update and restart your Blink NestJS server to enable this wallet balance.')),
          const SizedBox(height: 20),
          const BlinkProListCard(
            icon: Icons.verified_user_outlined,
            eyebrow: 'YOUR REWARDS',
            title: 'Verified Blink Points',
            subtitle: 'Your BP balance is stored on your Blink account and confirmed by the server.',
            badges: [BlinkInfoPill('Account secured',icon:Icons.verified_outlined,highlight:true)],
          ),
          BlinkProListCard(
            icon: Icons.receipt_long_outlined,
            eyebrow: 'REWARDS ACTIVITY',
            title: 'Recorded Blink rewards',
            subtitle: !historyAvailable
              ? 'Reward activity is not supported by the connected server yet.'
              : history.isEmpty
                ? 'No recorded reward events yet.'
                : 'Actual approved task rewards, correct Secret guesses and Moment BP gifts.',
          ),
          if(historyAvailable)...history.map((item) {
            final amount = num.tryParse(field(item, 'amount', '0')) ?? 0;
            final date = DateTime.tryParse(field(item,'createdAt'));
            final when = date == null ? '' :
              '${date.toLocal().year}-${date.toLocal().month.toString().padLeft(2, '0')}-${date.toLocal().day.toString().padLeft(2, '0')}';
            return BlinkProListCard(
              icon:Icons.stars_outlined,
              eyebrow: field(item,'type').replaceAll('_',' '),
              title:field(item,'description','Blink reward'),
              subtitle:when,
              badges:[BlinkInfoPill('+${amount.toStringAsFixed(amount%1==0?0:2)} BP',
                icon:Icons.verified_outlined,highlight:true)],
            );
          }),
        ],
      ),
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Settings',
    active: 'people',
    child: ScreenList(
      children: [
        const SizedBox(height: 9),
        const BlinkFeatureHero(
          eyebrow:'YOUR ACCOUNT. YOUR SPACE.',
          title:'Make Blink your own.',
          subtitle:'Your identity, preferences, and the tools that matter to you.',
          icon:Icons.tune_rounded,mood:BlinkMood.studio,
          margin:EdgeInsets.fromLTRB(0,0,0,18),
        ),
        const BlinkSectionBand(
          eyebrow: 'PROFILE & IDENTITY',
          title: 'Your Blink account',
          subtitle: 'Manage the way people see and reach you',
          mood: BlinkMood.community,
          icon: Icons.account_circle_outlined,
          padding: EdgeInsets.fromLTRB(0, 2, 0, 14)),
        BlinkProListCard(
          icon:Icons.account_circle_rounded,
          eyebrow:'YOUR PROFILE',
          title:'My Blink account',
          subtitle:'Edit who you are and how you show up on Blink.',
          onTap:()=>go(context,'/profile'),
        ),
        const BlinkSectionBand(
          eyebrow: 'APP PREFERENCES',
          title: 'Controls & settings',
          subtitle: 'Account tools, notifications and privacy actions',
          mood: BlinkMood.studio,
          icon: Icons.tune_rounded,
          padding: EdgeInsets.fromLTRB(0, 12, 0, 14)),
        BlinkPanel(
          child: Column(
            children: [
              BlinkOptionRow(
                icon: Icons.manage_accounts_outlined,
                text: 'Edit profile',
                onTap: () => go(context, '/profile/edit'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.business_center_outlined,
                text: 'Business profile',
                onTap: () => go(context, '/business/profile'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.dashboard_outlined,
                text: 'Creator dashboard',
                onTap: () => go(context, '/creator'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.notifications_none_rounded,
                text: 'Notifications',
                onTap: () => go(context, '/notifications'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.palette_outlined,
                text: 'Theme and appearance',
                onTap: () => go(context, '/appearance'),
              ),
              const Divider(),
          BlinkOptionRow(
            icon: Icons.logout_rounded,
            text: 'Log Out',
            onTap: () async {
              try {
                await BlinkAuthApi.logout();

                if (!context.mounted) return;

                go(
                  context,
                  '/login',
                  replace: true,
                );
              } catch (_) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Unable to clear the session. Please try again.',
                    ),
                  ),
                );
              }
            },
          ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Notifications aggregated only from existing authenticated Blink endpoints.
/// The NestJS API does not expose a durable, universal notifications ledger:
/// these are live, actionable items, not fabricated push or read receipts.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  int unavailableSources = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<dynamic> _safeGet(String path) async {
    try {
      return await LiveApi.call('GET', path);
    } catch (exception) {
      debugPrint('Blink notifications: $path unavailable: $exception');
      return null;
    }
  }

  Future<void> _load() async {
    final result = await Future.wait<dynamic>([
      _safeGet('/friends/requests/incoming'),
      _safeGet('/inbox'),
      _safeGet('/business-match/requests'),
      _safeGet('/business-match/meetings'),
      _safeGet('/hearts/incoming'),
      _safeGet('/irl/invitations'),
    ]);
    if (!mounted) return;
    final unavailable = result.where((x) => x == null).length;
    if (unavailable == result.length) {
      setState(() {
        error = 'Could not connect to any Blink activity service.';
        loading = false; unavailableSources = unavailable;
      });
      return;
    }

    final next = <Map<String, dynamic>>[];
    void add(String title, String detail, String route, String category,
        dynamic timestamp) {
      next.add({
        'title': title,
        'detail': detail,
        'route': route,
        'category': category,
        'createdAt': timestamp?.toString() ?? '',
      });
    }

    for (final raw in arr(result[0])) {
      final request = obj(raw);
      final sender = obj(request['sender']);
      add(field(sender, 'name', 'Someone') + ' sent a friend request',
        'Accept or decline this connection request.',
        '/people/requests', 'friends', request['createdAt']);
    }
    for (final raw in arr(result[1])) {
      final conversation = obj(raw);
      final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
      if (unread <= 0) continue;
      final who = conversation['isGroup'] == true
        ? field(conversation, 'groupName', 'Group conversation')
        : field(conversation['otherUser'], 'name', 'A friend');
      add('$unread unread message${unread == 1 ? '' : 's'} from $who',
        'Open Inbox to view and reply.', '/inbox', 'inbox',
        conversation['updatedAt']);
    }
    for (final raw in arr(result[2])) {
      final request = obj(raw);
      if (field(request, 'direction') != 'incoming') continue;
      add('Business connection request',
        field(request['profile'], 'name', 'A business') +
          ' wants to connect with you.',
        '/business', 'business', request['createdAt']);
    }
    for (final raw in arr(result[3])) {
      final meeting = obj(raw);
      if (field(meeting, 'role') != 'attendee' ||
          field(meeting, 'status') != 'PENDING') continue;
      add('Business meeting invitation',
        field(meeting, 'title', 'Meeting') + ' · ' +
          field(meeting, 'counterpartName', 'Business partner'),
        '/business/meetings', 'meeting', meeting['createdAt']);
    }
    for (final raw in arr(result[4])) {
      final heart = obj(raw);
      if (field(heart, 'status') != 'PENDING') continue;
      add('Someone sent you a Blink Heart',
        'A private Heart is waiting for your response.',
        '/hearts', 'hearts', heart['createdAt']);
    }
    final now = DateTime.now();
    for (final raw in arr(result[5])) {
      final invitation = obj(raw);
      final plan = obj(invitation['plan']);
      final starts = DateTime.tryParse(field(plan, 'startsAt'));
      if (starts != null && starts.isBefore(now)) continue;
      add('You are invited to an IRL plan',
        field(plan, 'title', 'A Blink meetup') + ' · ' +
          field(plan, 'place', 'Meetup location to be confirmed'),
        '/irl', 'irl', invitation['createdAt']);
    }
    int timeOf(Map<String, dynamic> value) =>
      DateTime.tryParse(field(value, 'createdAt'))
        ?.millisecondsSinceEpoch ?? 0;
    next.sort((a, b) => timeOf(b).compareTo(timeOf(a)));
    setState(() {
      items = next; error = null; loading = false;
      unavailableSources = unavailable;
    });
  }

  IconData _icon(String category) => switch(category) {
    'friends' => Icons.person_add_alt_1_rounded,
    'inbox' => Icons.mark_chat_unread_rounded,
    'business' => Icons.handshake_outlined,
    'meeting' => Icons.event_available_outlined,
    'hearts' => Icons.favorite_border_rounded,
    'irl' => Icons.groups_2_outlined,
    _ => Icons.notifications_active_outlined,
  };

  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Notifications',
    active: 'explore',
    child: RefreshIndicator(onRefresh: _load, child: loading
      ? const Center(child: CircularProgressIndicator())
      : error != null ? liveError(error, _load)
      : ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          const BlinkFeatureHero(
            eyebrow:'YOUR BLINK PULSE',
            title:'Stay in the loop.',
            subtitle:'Real requests, conversations, Hearts and upcoming plans.',
            icon:Icons.notifications_active_outlined,
            mood:BlinkMood.community,
            margin:EdgeInsets.fromLTRB(0,0,0,12),
          ),
          SectionHeading('Your updates',
            subtitle: '${items.length} live items needing your attention'),
          if (unavailableSources > 0)
            Padding(padding: const EdgeInsets.symmetric(vertical:10),
              child: Text(
                '$unavailableSources activity source${unavailableSources == 1 ? '' : 's'} unavailable. Pull to retry.',
                style: Theme.of(context).textTheme.bodySmall)),
          if (items.isEmpty)
            const BlinkExperienceState(
              title: 'All caught up',
              subtitle: 'No new actionable updates from your connected Blink services.',
              icon: Icons.notifications_none_rounded,
              mood: BlinkMood.community),
          ...items.map((item) => BlinkProListCard(
            title: field(item, 'title'),
            subtitle: field(item, 'detail'),
            eyebrow: field(item, 'category').toUpperCase(),
            icon: _icon(field(item, 'category')),
            onTap: () => go(context, field(item, 'route')),
          )),
          const SizedBox(height: 14),
          Text('Updates reflect current server data. A permanent event history, read tracking and push delivery require a dedicated server notification service.',
            style: Theme.of(context).textTheme.bodySmall),
        ],
      )),
  );
}

/// Matches Web's saved light/dark appearance while keeping Blink Orange.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: blinkAppearance,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const BlinkBrandedTitle('Appearance')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const BlinkFeatureHero(
          eyebrow:'THE COLOR OF BLINK',
          title:'Bold. Warm. Yours.',
          subtitle:'The same Blink Orange identity, now in day and night.',
          icon:Icons.palette_rounded,mood:BlinkMood.studio,
          margin:EdgeInsets.fromLTRB(0,0,0,18),
        ),
        BlinkProListCard(
          icon:blinkAppearance.isDark ? Icons.dark_mode_rounded
              : Icons.light_mode_rounded,
          eyebrow:'CURRENT APPEARANCE',
          title:blinkAppearance.isDark ? 'Blink Orange · Dark'
              : 'Blink Orange · Light',
          subtitle:'Your choice is saved on this device.',
          badges:const [BlinkInfoPill('ACTIVE',
            icon:Icons.check_circle_outline,highlight:true)],
        ),
        const SizedBox(height:16),
        SegmentedButton<ThemeMode>(
          showSelectedIcon:true,
          segments:const [
            ButtonSegment(value:ThemeMode.light,
              icon:Icon(Icons.light_mode_outlined),label:Text('Light')),
            ButtonSegment(value:ThemeMode.dark,
              icon:Icon(Icons.dark_mode_outlined),label:Text('Dark')),
          ],
          selected:{blinkAppearance.mode},
          onSelectionChanged:(values) =>
            blinkAppearance.choose(values.first),
        ),
      ]),
    ),
  );
}
