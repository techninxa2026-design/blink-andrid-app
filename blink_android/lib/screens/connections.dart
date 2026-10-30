import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

class DiscoverPeopleScreen extends StatefulWidget {
  const DiscoverPeopleScreen({super.key});
  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final users = people
        .where((p) => p.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return BlinkScreen(
      title: 'Discover People',
      active: 'people',
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PeopleTab('Discover', '/people', true),
              _PeopleTab('Requests', '/people/requests', false),
              _PeopleTab('Friends', '/people/friends', false),
            ],
          ),
          BlinkSearchBox(
            hint: 'Find people...',
            onChanged: (s) => setState(() => search = s),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 18),
              itemCount: users.length,
              itemBuilder: (context, index) => BlinkUserLine(
                person: users[index],
                subtitle: index % 2 == 0 ? '2 days ago' : 'Suggested for you',
                trailing: IconButton(
                  onPressed: () =>
                      demoToast(context, 'Friend request sent (demo).'),
                  icon: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: BlinkColors.orange,
                  ),
                ),
                onTap: () => go(context, '/profile'),
              ),
              separatorBuilder: (_, __) => const Divider(height: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleTab extends StatelessWidget {
  final String label, route;
  final bool selected;
  const _PeopleTab(this.label, this.route, this.selected);
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () {
      if (!selected) go(context, route);
    },
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? BlinkColors.orange : BlinkColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: 2,
          color: selected ? BlinkColors.orange : Colors.transparent,
        ),
      ],
    ),
  );
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final handled = <int>{};
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Friend Requests',
    active: 'people',
    child: Column(
      children: [
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _PeopleTab('Discover', '/people', false),
            const _PeopleTab('Requests', '/people/requests', true),
            const _PeopleTab('Friends', '/people/friends', false),
          ],
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: people.length,
            itemBuilder: (context, index) {
              if (handled.contains(index)) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: BlinkPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BlinkUserLine(
                        person: people[index],
                        subtitle: 'Sent you a friend request',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: BlinkButton(
                              'Accept',
                              height: 35,
                              onPressed: () =>
                                  setState(() => handled.add(index)),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: SizedBox(
                              height: 35,
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => handled.add(index)),
                                child: const Text('Decline'),
                              ),
                            ),
                          ),
                        ],
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

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'My Friends',
    active: 'people',
    child: Column(
      children: [
        const SectionHeading(
          'My Friends',
          subtitle: 'Keep your connections close',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _PeopleTab('Discover', '/people', false),
            const _PeopleTab('Requests', '/people/requests', false),
            const _PeopleTab('Friends', '/people/friends', true),
          ],
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: people.length,
            itemBuilder: (context, index) => BlinkUserLine(
              person: people[index],
              subtitle: 'Friends',
              onTap: () => go(context, '/profile'),
              trailing: TextButton(
                onPressed: () => go(context, '/chat'),
                child: const Text(
                  'Message',
                  style: TextStyle(color: BlinkColors.orange, fontSize: 11),
                ),
              ),
            ),
            separatorBuilder: (_, __) => const Divider(),
          ),
        ),
      ],
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Profile',
    active: 'people',
    trailing: IconButton(
      onPressed: () => go(context, '/settings'),
      icon: const Icon(Icons.settings_outlined, color: BlinkColors.orange),
    ),
    child: ListView(
      children: [
        SizedBox(
          height: 140,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF7B0B), BlinkColors.orange],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -44,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: BlinkAvatar(person: people[1], size: 92),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 53),
        const Text(
          'Nusrat Jahan',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        const Text(
          'Creator · Dhaka',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: BlinkColors.muted),
        ),
        const SizedBox(height: 18),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            BlinkCount('128', 'Followers'),
            BlinkCount('96', 'Following'),
            BlinkCount('86', 'Connections'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 15),
          child: BlinkButton(
            'Edit Profile',
            onPressed: () => go(context, '/profile/edit'),
          ),
        ),
        BlinkChips(
          labels: const ['Moments', 'Reels', 'About'],
          onChanged: (i) => setState(() => tab = i),
        ),
        const SizedBox(height: 11),
        if (tab == 2)
          const Padding(
            padding: EdgeInsets.all(18),
            child: BlinkPanel(
              child: Text(
                'I create, explore and share beautiful little moments. Based in Dhaka. 🧡',
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () =>
                    go(context, tab == 0 ? '/moment/view' : '/reel/view'),
                child: BlinkPhoto(
                  id: [1005, 1015, 1018, 1011, 1016, 1012][i % 6],
                  radius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool isBusiness = false, privateProfile = false;
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Edit Profile',
    logoTitle: false,
    active: 'people',
    child: ScreenList(
      children: [
        const SizedBox(height: 17),
        Center(child: BlinkAvatar(person: people[1], size: 94, ring: true)),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => demoToast(
              context,
              'Connect a photo picker to update your avatar.',
            ),
            child: const Text(
              'Change profile photo',
              style: TextStyle(color: BlinkColors.orange),
            ),
          ),
        ),
        const SizedBox(height: 15),
        const BlinkField(label: 'Full name', hint: 'Nusrat Jahan'),
        const BlinkField(label: 'Username', hint: 'nusratjahan'),
        const BlinkField(label: 'Bio', hint: 'Tell people about you', lines: 3),
        BlinkPanel(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: BlinkColors.orange,
                title: const Text(
                  'Business profile',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                value: isBusiness,
                onChanged: (v) => setState(() => isBusiness = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: BlinkColors.orange,
                title: const Text(
                  'Private profile',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                value: privateProfile,
                onChanged: (v) => setState(() => privateProfile = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 19),
        BlinkButton(
          'Save Changes',
          onPressed: () => demoToast(
            context,
            'UI preview: connect to your profile update API.',
          ),
        ),
      ],
    ),
  );
}
