import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/nav.dart';
import '../core/data.dart';
import '../widgets/ui.dart';
import 'messaging.dart';

class CheckinFeedScreen extends StatelessWidget {
  const CheckinFeedScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Check-ins',
    active: 'explore',
    trailing: IconButton(
      onPressed: () => go(context, '/checkin/create'),
      icon: const Icon(Icons.add_circle_rounded, color: BlinkColors.orange),
    ),
    child: ListView(
      children: [
        const SectionHeading(
          'Check-ins Feed',
          subtitle: 'Real places. Real connections.',
        ),
        const BlinkChips(labels: ['All', 'Friends', 'Nearby']),
        const SizedBox(height: 11),
        ...[posts[2], posts[0], posts[1]].map((p) => BlinkPostCard(post: p)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: BlinkButton(
            'Create Check-in',
            icon: Icons.location_on,
            onPressed: () => go(context, '/checkin/create'),
          ),
        ),
      ],
    ),
  );
}

class CreateCheckinScreen extends StatelessWidget {
  const CreateCheckinScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Create Check-in',
    logoTitle: false,
    active: 'explore',
    child: ScreenList(
      children: [
        const SectionHeading(
          'Create Check-in',
          subtitle: 'Share where you are and what you are doing',
        ),
        const BlinkField(
          label: 'Post ideas',
          hint: "What's happening?",
          lines: 5,
        ),
        BlinkPanel(
          child: Column(
            children: [
              BlinkOptionRow(
                icon: Icons.location_on,
                text: 'Add location',
                onTap: () =>
                    demoToast(context, 'Connect a map/location picker.'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.mood_rounded,
                text: 'Mood',
                onTap: () => demoToast(context, 'Mood options'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.people_alt_rounded,
                text: 'Audience',
                detail: 'Everyone',
                onTap: () => demoToast(context),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.image_outlined,
                text: 'Add photo',
                onTap: () => demoToast(context, 'Requires an image picker.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        BlinkButton(
          'Post Check-in',
          onPressed: () {
            demoToast(
              context,
              'UI preview: connect to the Blink check-in API.',
            );
            go(context, '/checkins');
          },
        ),
      ],
    ),
  );
}

class IrlPlansScreen extends StatefulWidget {
  const IrlPlansScreen({super.key});
  @override
  State<IrlPlansScreen> createState() => _IrlPlansScreenState();
}

class _IrlPlansScreenState extends State<IrlPlansScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final items = <(String, String, int)>[
      ('Football this Saturday', 'Dhanmondi Lake · Sat 4 PM', 1011),
      ('Weekend coffee', 'Dhanmondi · Sat 6 PM', 1060),
      ('Creator meetup', 'Dhaka · Coming soon', 1035),
      ('Explore the city', 'Gulshan · Friday', 1015),
    ];
    return BlinkScreen(
      title: 'IRL Plans',
      active: 'explore',
      child: Column(
        children: [
          const SectionHeading(
            'IRL Plans',
            subtitle: 'Meet your Blink friends offline',
          ),
          BlinkChips(
            labels: const ['Discover', 'My Plans', 'Hosting'],
            onChanged: (i) => setState(() => tab = i),
          ),
          const SizedBox(height: 11),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[(i + tab) % items.length];
                return InkWell(
                  onTap: () => go(context, '/irl/detail'),
                  child: BlinkPanel(
                    child: Row(
                      children: [
                        BlinkPhoto(id: item.$3, width: 68, height: 68),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  color: BlinkColors.orange,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 7),
                              const DemoTag('3 people going'),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: BlinkColors.muted,
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: BlinkButton(
              'Create IRL Plan',
              icon: Icons.add_circle_outline,
              onPressed: () => demoToast(
                context,
                'Connect the create-plan form to your IRL API.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IrlPlanDetailScreen extends StatefulWidget {
  const IrlPlanDetailScreen({super.key});
  @override
  State<IrlPlanDetailScreen> createState() => _IrlPlanDetailScreenState();
}

class _IrlPlanDetailScreenState extends State<IrlPlanDetailScreen> {
  bool joined = false;
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Plan Details',
    active: 'explore',
    child: ScreenList(
      children: [
        const SizedBox(height: 9),
        BlinkUserLine(person: people[0], subtitle: 'Event host'),
        const SectionHeading(
          'Football this Saturday',
          subtitle: 'Dhanmondi Lake · Sat, 4 PM',
        ),
        const Row(
          children: [
            Expanded(child: BlinkPanel(child: BlinkCount('6', 'Going'))),
            SizedBox(width: 8),
            Expanded(child: BlinkPanel(child: BlinkCount('3', 'Pending'))),
            SizedBox(width: 8),
            Expanded(child: BlinkPanel(child: BlinkCount('3', 'Invited'))),
          ],
        ),
        const SizedBox(height: 19),
        const Text(
          'Description',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ever wanted to meet up and enjoy football by the lake? Join us for an exciting afternoon with the Blink community.',
          style: TextStyle(
            color: BlinkColors.muted,
            fontSize: 12.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 25),
        BlinkButton(
          joined ? 'You requested to join' : 'Request to Join',
          onPressed: () => setState(() => joined = !joined),
        ),
        const SizedBox(height: 10),
        BlinkButton(
          'Open Plan Chat',
          outline: true,
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () => go(context, '/irl/chat'),
        ),
      ],
    ),
  );
}

class IrlChatScreen extends StatelessWidget {
  const IrlChatScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ChatSurface(heading: 'IRL Plan Chat', group: true);
}
