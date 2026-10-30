import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/nav.dart';
import '../core/theme.dart';
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

class ShareMediaScreen extends StatelessWidget {
  const ShareMediaScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Share Media',
    logoTitle: false,
    active: 'home',
    child: ScreenList(
      children: [
        const SectionHeading(
          'Share Media',
          subtitle: 'Share to a friend or your community',
        ),
        const BlinkPanel(
          child: Row(
            children: [
              Icon(
                Icons.collections_rounded,
                color: BlinkColors.orange,
                size: 27,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Choose a moment or reel to share',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...people.map(
          (p) => BlinkUserLine(
            person: p,
            trailing: TextButton(
              onPressed: () => demoToast(
                context,
                'Share preview: connect your inbox share API.',
              ),
              child: const Text(
                'Send',
                style: TextStyle(color: BlinkColors.orange),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
