import 'package:flutter/material.dart';

import '../core/blink_auth_api.dart';
import '../core/theme.dart';
import '../core/nav.dart';
import '../core/data.dart';
import '../widgets/ui.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'BP Wallet',
    active: 'explore',
    child: ListView(
      children: [
        const SectionHeading(
          'BP Wallet',
          subtitle: 'Your Blink Points, your rewards',
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 13),
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A07), BlinkColors.orange],
            ),
            borderRadius: BorderRadius.circular(19),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available balance',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              SizedBox(height: 10),
              Text(
                '50.50 BP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.stars_rounded, color: Colors.white70, size: 31),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              Expanded(child: BlinkPanel(child: BlinkCount('76', 'Earned'))),
              SizedBox(width: 8),
              Expanded(child: BlinkPanel(child: BlinkCount('25.5', 'Used'))),
              SizedBox(width: 8),
              Expanded(child: BlinkPanel(child: BlinkCount('505', 'Bonuses'))),
            ],
          ),
        ),
        const SectionHeading('Recent Activity'),
        ...<(String, String, String)>[
          ('Completed a task', 'Today · 12:24 PM', '+ 4.5 BP'),
          ('Published a moment', 'Yesterday · 4:10 PM', '+ 0.5 BP'),
          ('Creator task verified', '24 Oct · 11:42 AM', '+ 2 BP'),
          ('Reel engagement', '23 Oct · 3:21 PM', '+ 1 BP'),
        ].map(
          (e) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
            child: BlinkPanel(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: BlinkColors.orangeSoft,
                    child: Icon(Icons.stars_rounded, color: BlinkColors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.$2,
                          style: const TextStyle(
                            color: BlinkColors.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    e.$3,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: BlinkColors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 11, 16, 18),
          child: DemoNotice(
            'BP is an in-app reward. Cash conversion is not available in this UI demo.',
          ),
        ),
      ],
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
        BlinkUserLine(
          person: people[1],
          subtitle: 'My Blink account',
          onTap: () => go(context, '/profile'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        const Divider(),
        const SizedBox(height: 10),
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
                icon: Icons.lock_outline_rounded,
                text: 'Privacy and security',
                onTap: () => go(context, '/profile/edit'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.delete_outline_rounded,
                text: 'Delete account',
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete account?'),
                    content: const Text(
                      'This is a UI preview. Real deletion must require authentication and be handled by your backend.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          demoToast(context);
                        },
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.grid_view_rounded,
                text: 'UI screen gallery',
                onTap: () => go(context, '/ui-gallery'),
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

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Notifications',
    logoTitle: false,
    active: 'people',
    child: ListView(
      children: [
        const SectionHeading(
          'Notifications',
          subtitle: 'Your latest Blink activity',
        ),
        ...<(String, String)>[
          ('liked your moment', 'Just now'),
          ('sent you a friend request', '12m ago'),
          ('commented on your reel', '1h ago'),
          ('shared a moment with you', 'Yesterday'),
          ('verified your creator task', '2 days ago'),
        ].asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: BlinkUserLine(
              person: people[e.key % people.length],
              subtitle: '${e.value.$1} · ${e.value.$2}',
              trailing: const Icon(
                Icons.circle,
                color: BlinkColors.orange,
                size: 8,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: blinkAppearance,
    builder: (context, child) => Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text('Choose your Blink theme', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Blink orange remains the primary brand color.'),
        const SizedBox(height: 18),
        _themeTile(context, ThemeMode.light, Icons.light_mode_outlined,
          'Light', 'Bright white surfaces and deep orange accents'),
        _themeTile(context, ThemeMode.dark, Icons.dark_mode_outlined,
          'Dark', 'Comfortable dark surfaces and vivid orange accents'),
        _themeTile(context, ThemeMode.system, Icons.brightness_auto_outlined,
          'Use device setting', 'Follow your phone appearance'),
      ]),
    ),
  );

  Widget _themeTile(BuildContext context, ThemeMode option, IconData icon,
      String title, String subtitle) => Card(
    child: RadioListTile<ThemeMode>(
      value: option,
      groupValue: blinkAppearance.mode,
      onChanged: (value) {
        if (value != null) blinkAppearance.choose(value);
      },
      secondary: Icon(icon, color: BlinkColors.orange),
      title: Text(title), subtitle: Text(subtitle),
      activeColor: BlinkColors.orange,
    ),
  );
}
