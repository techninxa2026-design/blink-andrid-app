import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../core/blink_home_api.dart';
import '../core/live_api.dart';
import '../widgets/ui.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final users = people
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return BlinkScreen(
      title: 'Inbox',
      active: 'home',
      trailing: IconButton(
        onPressed: () => go(context, '/group-chat'),
        icon: const Icon(Icons.group_add_outlined, color: BlinkColors.orange),
      ),
      child: Column(
        children: [
          const SectionHeading(
            'Inbox & Messages',
            subtitle: 'Keep the conversation going',
          ),
          BlinkSearchBox(
            hint: 'Search conversations...',
            onChanged: (v) => setState(() => query = v),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              itemCount: users.length,
              itemBuilder: (context, i) => BlinkUserLine(
                person: users[i],
                subtitle: const [
                  'Thanks for the message!',
                  'Hi! How is everything?',
                  'Can you share more?',
                  'Sounds amazing!',
                  'Talk to you soon',
                  'Great idea!',
                ][i % 6],
                onTap: () => go(context, '/chat'),
                trailing: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '2:45 PM',
                      style: TextStyle(fontSize: 10, color: BlinkColors.muted),
                    ),
                    SizedBox(height: 7),
                    CircleAvatar(
                      backgroundColor: BlinkColors.orange,
                      radius: 8,
                      child: Text(
                        '1',
                        style: TextStyle(fontSize: 9, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              separatorBuilder: (_, __) => const Divider(),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatSurface extends StatefulWidget {
  final bool group;
  final String heading;
  const ChatSurface({super.key, this.group = false, required this.heading});
  @override
  State<ChatSurface> createState() => _ChatSurfaceState();
}

class _ChatSurfaceState extends State<ChatSurface> {
  final input = TextEditingController();
  final sent = <String>[];
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: widget.heading,
    logoTitle: false,
    active: 'home',
    trailing: IconButton(
      onPressed: () => demoToast(context, 'Conversation options'),
      icon: const Icon(Icons.more_vert),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: BlinkUserLine(
            person: people[widget.group ? 2 : 0],
            subtitle: widget.group ? '4 members · Group chat' : 'Active now',
            trailing: const Icon(
              Icons.videocam_outlined,
              color: BlinkColors.orange,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(15),
            children: [
              const Center(child: DemoTag('TODAY')),
              const SizedBox(height: 21),
              _MessageBubble('Hey! How are you doing?', false, people.first),
              _MessageBubble(
                'Doing great. Working on Blink 🧡',
                true,
                people[1],
              ),
              _MessageBubble('Can you share the details?', false, people.first),
              _MessageBubble('Sure! I will send them here.', true, people[1]),
              ...sent.map((s) => _MessageBubble(s, true, people[1])),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => go(context, '/share'),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: BlinkColors.orange,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: input,
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      demoToast(context, 'Attach a photo or video'),
                  icon: const Icon(
                    Icons.photo_camera_outlined,
                    color: BlinkColors.orange,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (input.text.trim().isNotEmpty)
                      setState(() {
                        sent.add(input.text.trim());
                        input.clear();
                      });
                  },
                  icon: const Icon(
                    Icons.send_rounded,
                    color: BlinkColors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool mine;
  final DemoPerson person;
  const _MessageBubble(this.message, this.mine, this.person);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!mine) ...[
          BlinkAvatar(person: person, size: 27),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: mine ? BlinkColors.orangeSoft : const Color(0xFFF2F3F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(message, style: const TextStyle(fontSize: 12.5)),
          ),
        ),
        if (mine) const SizedBox(width: 5),
      ],
    ),
  );
}

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ChatSurface(heading: 'Arafat Hossain');
}

class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ChatSurface(heading: 'Blink Creators', group: true);
}

class ShareMediaScreen extends StatefulWidget {
  const ShareMediaScreen({super.key});
  @override State<ShareMediaScreen> createState() => _ShareMediaState();
}

class _ShareMediaState extends State<ShareMediaScreen> {
  List<BlinkMoment> moments = [];
  List<BlinkReel> reels = [];
  List<dynamic> friends = [];
  String? selected;
  String? error;
  String query = '';
  bool loading = true;
  bool sending = false;
  final search = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { search.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        BlinkHomeApi.moments(mine: true, take: 50),
        BlinkHomeApi.myReels(),
        LiveApi.call('GET', '/inbox/friends'),
      ]);
      if (!mounted) return;
      setState(() {
        moments = (results[0] as List).cast<BlinkMoment>();
        reels = (results[1] as List).cast<BlinkReel>();
        friends = arr(results[2]);
        selected ??= moments.isNotEmpty ? 'm:' + moments.first.id :
          reels.isNotEmpty ? 'r:' + reels.first.id : null;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  String _selectedMessage() {
    final key = selected;
    if (key == null) return '';
    if (key.startsWith('m:')) {
      for (final moment in moments) {
        if (moment.id == key.substring(2)) {
          return '📸 Blink Moment shared\n' +
            ((moment.caption ?? '').isEmpty ? '' : moment.caption! + '\n') +
            BlinkHomeApi.mediaUrl(moment.mediaUrl);
        }
      }
    }
    if (key.startsWith('r:')) {
      for (final reel in reels) {
        if (reel.id == key.substring(2)) {
          return '🎬 Blink Reel shared\n' +
            ((reel.caption ?? '').isEmpty ? '' : reel.caption! + '\n') +
            BlinkHomeApi.mediaUrl(reel.videoUrl);
        }
      }
    }
    return '';
  }

  Future<void> _shareTo(dynamic raw) async {
    final friend = obj(raw);
    final friendId = field(friend, 'id');
    final message = _selectedMessage();
    if (sending || friendId.isEmpty || message.isEmpty) return;
    setState(() => sending = true);
    try {
      final convo = obj(await LiveApi.call('POST', '/inbox/conversations',
        {'friendId': friendId}));
      final id = field(convo, 'conversationId');
      if (id.isEmpty) throw const LiveApiError('Could not open Blink Inbox.');
      await LiveApi.call('POST', '/inbox/conversations/' +
        Uri.encodeComponent(id) + '/messages', {'body': message});
      if (mounted) liveNotice(context, 'Shared to ' + field(friend, 'name'));
    } catch (e) {
      if (mounted) liveNotice(context, 'Could not share: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget _media(String key, String title, String url, {bool video = false}) {
    final chosen = selected == key;
    return InkWell(
      onTap: sending ? null : () => setState(() => selected = key),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        width: 115, padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: chosen ? BlinkColors.orangeSoft : Colors.white,
          border: Border.all(color: chosen ? BlinkColors.orange : BlinkColors.line,
            width: chosen ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(9),
              child: Image.network(url, height: 88, width: 101,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(
                  width: 101, height: 88, color: BlinkColors.orangeSoft,
                  alignment: Alignment.center, child: Icon(
                    video ? Icons.movie_outlined : Icons.image_outlined,
                    color: BlinkColors.orange))),
            ),
            if (video) const Positioned.fill(child: Center(child:
              Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 34))),
          ]),
          const SizedBox(height: 5),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
          if (chosen) const Align(alignment: Alignment.centerRight,
            child: Icon(Icons.check_circle, color: BlinkColors.orange, size: 18)),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final matched = friends.where((f) =>
      field(f, 'name').toLowerCase().contains(query.toLowerCase())).toList();
    return BlinkScreen(
      title: 'Share Media', active: 'home',
      child: loading ? const Center(child: CircularProgressIndicator()) :
        error != null ? liveError(error, _load) :
        RefreshIndicator(onRefresh: _load, child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 30),
          children: [
            const SectionHeading('Share on Blink',
              subtitle: 'Send your Moments and Reels to friends'),
            const SizedBox(height: 14),
            Text('Select a Moment or Reel', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (moments.isEmpty && reels.isEmpty)
              const Padding(padding: EdgeInsets.all(20),
                child: Text('Publish a Moment or Reel to share it with friends.')),
            SizedBox(height: 150, child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...moments.map((m) => Padding(padding: const EdgeInsets.only(right: 9),
                  child: _media('m:' + m.id, m.caption ?? 'Moment',
                    BlinkHomeApi.mediaUrl(m.mediaUrl), video: m.mediaType == 'video'))),
                ...reels.map((r) => Padding(padding: const EdgeInsets.only(right: 9),
                  child: _media('r:' + r.id, r.caption ?? 'Reel',
                    BlinkHomeApi.mediaUrl(r.thumbnailUrl), video: true))),
              ],
            )),
            const SizedBox(height: 20),
            Text('Share with a friend', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(controller: search, onChanged: (value) =>
              setState(() => query = value),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
                hintText: 'Search Blink friends...')),
            const SizedBox(height: 10),
            if (matched.isEmpty) const ListTile(
              title: Text('No friends found'),
              subtitle: Text('Connect with Blink members to share privately.')),
            ...matched.map((f) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: liveAvatar(f),
                title: Text(field(f, 'name', 'Blink member')),
                trailing: FilledButton.icon(
                  onPressed: sending || selected == null ? null : () => _shareTo(f),
                  icon: const Icon(Icons.send_outlined, size: 16),
                  label: const Text('Send'),
                ),
              ),
            )),
          ],
        )),
    );
  }
}
