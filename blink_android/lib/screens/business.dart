import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/nav.dart';
import '../core/data.dart';
import '../widgets/ui.dart';

class BusinessSearchScreen extends StatefulWidget {
  const BusinessSearchScreen({super.key});
  @override
  State<BusinessSearchScreen> createState() => _BusinessSearchScreenState();
}

class _BusinessSearchScreenState extends State<BusinessSearchScreen> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    const businesses = <(String, String, int)>[
      ('Techninxa', 'Software development company', 1005),
      ('Techno Inside', 'Creative tech solutions', 1015),
      ('Creative Studio', 'Branding and design', 1018),
      ('TechSphere Studio', 'Innovation-driven digital solutions', 1011),
    ];
    final matching = businesses
        .where((b) => b.$1.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return BlinkScreen(
      title: 'Business Match',
      active: 'explore',
      child: Column(
        children: [
          const SectionHeading(
            'Business Search',
            subtitle: 'Discover people and business opportunities',
          ),
          BlinkSearchBox(
            hint: 'Search business profiles...',
            onChanged: (v) => setState(() => search = v),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              itemCount: matching.length,
              itemBuilder: (context, index) {
                final b = matching[index];
                return InkWell(
                  onTap: () => go(context, '/business/profile'),
                  child: BlinkPanel(
                    child: Row(
                      children: [
                        BlinkPhoto(id: b.$3, width: 65, height: 64),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.$1,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                b.$2,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: BlinkColors.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const DemoTag('Business'),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: BlinkColors.orange,
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Business Profile',
    active: 'explore',
    child: ScreenList(
      children: [
        const SizedBox(height: 5),
        Center(
          child: Container(
            width: 87,
            height: 87,
            decoration: BoxDecoration(
              color: BlinkColors.orangeSoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.business_center_rounded,
              color: BlinkColors.orange,
              size: 45,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Techninxa',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
        ),
        const Center(
          child: Text(
            'Software development · Dhaka',
            style: TextStyle(fontSize: 12, color: BlinkColors.muted),
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: BlinkPanel(child: BlinkCount('36', 'Connections'))),
            SizedBox(width: 7),
            Expanded(child: BlinkPanel(child: BlinkCount('16', 'Projects'))),
            SizedBox(width: 7),
            Expanded(child: BlinkPanel(child: BlinkCount('8', 'Meetings'))),
          ],
        ),
        const SizedBox(height: 19),
        const Text(
          'Description',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        const Text(
          'Custom software development, professional web applications, Flutter mobile apps, creative design and technology partnerships.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.55,
            color: BlinkColors.muted,
          ),
        ),
        const SizedBox(height: 22),
        BlinkButton(
          'Send Connection Request',
          onPressed: () => demoToast(
            context,
            'UI preview: connect to business-match requests.',
          ),
        ),
        const SizedBox(height: 9),
        BlinkButton(
          'Chat Now',
          outline: true,
          onPressed: () => go(context, '/chat'),
        ),
        const SizedBox(height: 10),
        BlinkButton(
          'Request Meeting',
          outline: true,
          onPressed: () => go(context, '/business/meetings'),
        ),
      ],
    ),
  );
}

class BusinessMeetingsScreen extends StatelessWidget {
  const BusinessMeetingsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Meetings',
    active: 'explore',
    child: ListView(
      children: [
        const SectionHeading(
          'Meetings',
          subtitle: 'Manage your business conversations',
        ),
        const BlinkChips(labels: ['Pending', 'Confirmed', 'All']),
        const SizedBox(height: 13),
        ...[
          'Project discovery call',
          'Partnership discussion',
          'Project review',
          'Follow-up meeting',
        ].asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 11),
            child: BlinkPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlinkUserLine(
                    person: people[e.key % people.length],
                    subtitle: e.value,
                    trailing: const DemoTag('Pending'),
                  ),
                  const Divider(),
                  const Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: BlinkColors.orange,
                      ),
                      SizedBox(width: 6),
                      Text('Tomorrow, 3:00 PM', style: TextStyle(fontSize: 11)),
                      Spacer(),
                      Icon(
                        Icons.videocam_outlined,
                        color: BlinkColors.orange,
                        size: 19,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BlinkButton(
                    'Schedule Meeting',
                    height: 37,
                    onPressed: () => demoToast(
                      context,
                      'UI preview: connect to business meeting scheduling.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Business Dashboard',
    active: 'explore',
    child: ListView(
      children: [
        const SectionHeading(
          'Business Dashboard',
          subtitle: 'Grow your network and partnerships',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: BlinkPanel(child: BlinkCount('36', 'Connections')),
              ),
              SizedBox(width: 8),
              Expanded(child: BlinkPanel(child: BlinkCount('8', 'Meetings'))),
              SizedBox(width: 8),
              Expanded(child: BlinkPanel(child: BlinkCount('16', 'Projects'))),
            ],
          ),
        ),
        const SectionHeading('Quick Actions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BlinkPanel(
            child: Column(
              children: [
                BlinkOptionRow(
                  icon: Icons.search_rounded,
                  text: 'Find business partners',
                  onTap: () => go(context, '/business'),
                ),
                const Divider(),
                BlinkOptionRow(
                  icon: Icons.meeting_room_outlined,
                  text: 'View meetings',
                  onTap: () => go(context, '/business/meetings'),
                ),
                const Divider(),
                BlinkOptionRow(
                  icon: Icons.business_center_rounded,
                  text: 'Business profile',
                  onTap: () => go(context, '/business/profile'),
                ),
                const Divider(),
                BlinkOptionRow(
                  icon: Icons.chat_outlined,
                  text: 'Messages',
                  onTap: () => go(context, '/inbox'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
