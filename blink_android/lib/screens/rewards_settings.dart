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
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final profile = obj(await LiveApi.call('GET', '/profile/me'));
      if (!mounted) return;
      setState(() {
        balance = profile['blinkPoints']?.toString();
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
          const BlinkProListCard(
            icon: Icons.receipt_long_outlined,
            eyebrow: 'REWARDS ACTIVITY',
            title: 'Transaction history',
            subtitle: 'An itemized ledger is not available from the current Blink API.',
          ),
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

/// Real alerts from the Inbox and the pending-friend-requests API.
/// No fake notification records are rendered.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsState();
}
class _NotificationsState extends State<NotificationsScreen> {
  List<dynamic> incoming = [];
  List<dynamic> conversations = [];
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final result = await Future.wait([
        LiveApi.call('GET','/friends/requests/incoming'),
        LiveApi.call('GET','/inbox'),
      ]);
      if (!mounted) return;
      setState(() {
        incoming = arr(result[0]);
        conversations = arr(result[1]).where((c) =>
          ((obj(c)['unreadCount'] as num?)?.toInt() ?? 0) > 0).toList();
        loading = false;
        error = null;
      });
    } catch(e) {
      if(mounted) setState(() {error = '$e'; loading = false;});
    }
  }
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Notifications',
    active: 'people',
    child: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? liveError(error,_load)
      : RefreshIndicator(onRefresh:_load,child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          const BlinkFeatureHero(
            eyebrow:'YOUR BLINK PULSE',
            title:'Stay in the loop.',
            subtitle:'New conversations, connection requests and what needs your attention.',
            icon:Icons.notifications_active_outlined,
            mood:BlinkMood.community,
            margin:EdgeInsets.fromLTRB(0,0,0,12),
          ),
          const SectionHeading('Your updates', subtitle: 'New messages and friend requests'),
          if (incoming.isEmpty && conversations.isEmpty)
            const BlinkExperienceState(
              title: 'All caught up',
              subtitle: 'No unread messages or pending friend requests.',
              icon: Icons.notifications_none_rounded,
              mood: BlinkMood.community),
          ...incoming.map((raw) {
            final r = obj(raw);
            final user = obj(r['sender']);
            return BlinkProListCard(
              leading:liveAvatar(user),
              icon:Icons.person_add_alt_1,
              eyebrow:'NEW CONNECTION REQUEST',
              title:field(user,'name','A member')+' sent a friend request',
              subtitle:'Review and respond to this request',
              onTap:()=>go(context,'/people/requests'),
              badges:const [BlinkInfoPill('Action available',
                icon:Icons.person_add_alt_1_rounded,highlight:true)],
            );
          }),
          ...conversations.map((raw) {
            final c=obj(raw);
            final sender=c['isGroup']==true
              ? field(c,'groupName','Group')
              : field(c['otherUser'],'name','Friend');
            final unread=(c['unreadCount'] as num?)?.toInt() ?? 0;
            return BlinkProListCard(
              icon:Icons.mark_email_unread_outlined,
              eyebrow:'BLINK INBOX',
              title:'Messages from $sender',
              subtitle:'Open your conversation and reply',
              badges:[BlinkInfoPill('$unread unread',
                icon:Icons.mark_chat_unread_outlined,highlight:true)],
              onTap:()=>go(context,'/inbox'),
            );
          }),
          const SizedBox(height: 14),
          const Text('Other activity notifications require a dedicated server notification endpoint.',
            style: TextStyle(fontSize: 12, color: BlinkColors.muted)),
        ],
      )),
  );
}

/// Single, consistent branded theme (no dark-mode toggle for now).
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BlinkBrandedTitle('Appearance')),
    body: ListView(padding: const EdgeInsets.all(16), children: const [
      BlinkFeatureHero(
        eyebrow:'THE COLOR OF BLINK',
        title:'Bold. Warm. Yours.',
        subtitle:'A signature orange experience, built to keep every moment recognizable.',
        icon:Icons.palette_rounded,mood:BlinkMood.studio,
        margin:EdgeInsets.fromLTRB(0,0,0,18),
      ),
      BlinkProListCard(
        icon:Icons.light_mode_rounded,
        eyebrow:'CURRENT APPEARANCE',
        title:'Blink Orange · Light',
        subtitle:'Active across Blink. Dark-mode switching is not yet available.',
        badges:[BlinkInfoPill('ACTIVE',icon:Icons.check_circle_outline,highlight:true)],
      ),
    ]),
  );
}
