import 'package:flutter/material.dart';
import '../core/theme.dart';

/// The feature navigation drawer from the original Blink web experience.
/// It complements (rather than replaces) the five-button bottom navigation.
class BlinkFullDrawer extends StatelessWidget {
  const BlinkFullDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * .86,
      backgroundColor: BlinkColors.canvas,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [BlinkColors.orangeDark, BlinkColors.orange],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 165),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10)),
                          child: Image.asset('assets/branding/final.png',
                            height: 25, fit: BoxFit.contain,
                            semanticLabel: 'Blink official logo'),
                        ),
                        const SizedBox(height: 7),
                        const Text('Your world, one moment at a time',
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close drawer',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 22),
                children: const [
                  _DrawerSection('FEED & CREATION'),
                  _DrawerLink('Home', Icons.home_rounded, '/home'),
                  _DrawerLink('Public Moments', Icons.public_rounded, '/moments'),
                  _DrawerLink('My Moments', Icons.photo_library_outlined, '/moments/mine'),
                  _DrawerLink('Reels', Icons.smart_display_outlined, '/reels'),
                  _DrawerLink('Capture', Icons.camera_alt_outlined, '/capture'),
                  _DrawerSection('CONNECT'),
                  _DrawerLink('Inbox & Messages', Icons.chat_bubble_outline_rounded, '/inbox'),
                  _DrawerLink('Friends', Icons.people_outline_rounded, '/people/friends'),
                  _DrawerLink('Discover People', Icons.person_search_outlined, '/people'),
                  _DrawerLink('Check-Ins', Icons.waving_hand_outlined, '/checkins'),
                  _DrawerLink('IRL Plans', Icons.event_available_outlined, '/irl'),
                  _DrawerSection('EXPLORE BLINK'),
                  _DrawerLink('Space & Explore', Icons.explore_outlined, '/explore'),
                  _DrawerLink('Blink Secrets', Icons.quiz_outlined, '/secrets'),
                  _DrawerLink('Blink Hearts', Icons.favorite_border_rounded, '/hearts'),
                  _DrawerLink('Blink Exchange', Icons.swap_horiz_rounded, '/exchange'),
                  _DrawerLink('Creator Tasks', Icons.task_alt_outlined, '/tasks'),
                  _DrawerLink('Creator Dashboard', Icons.dashboard_outlined, '/creator'),
                  _DrawerLink('Business Match', Icons.business_center_outlined, '/business'),
                  _DrawerLink('BP Wallet', Icons.stars_outlined, '/wallet'),
                  _DrawerSection('MY BLINK'),
                  _DrawerLink('My Profile', Icons.account_circle_outlined, '/profile'),
                  _DrawerLink('Friend Requests', Icons.person_add_alt_1_outlined, '/people/requests'),
                  _DrawerLink('Notifications', Icons.notifications_none_rounded, '/notifications'),
                  _DrawerLink('Settings', Icons.settings_outlined, '/settings'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(13, 18, 13, 8),
    child: Text(title, style: const TextStyle(
      color: BlinkColors.orangeDark, fontSize: 11,
      fontWeight: FontWeight.w900, letterSpacing: 1.2)),
  );
}

class _DrawerLink extends StatelessWidget {
  const _DrawerLink(this.title, this.icon, this.route);
  final String title;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: BlinkColors.orangeSoft,
          borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 20, color: BlinkColors.orangeDark),
      ),
      title: Text(title, style: const TextStyle(
        color: BlinkColors.ink, fontSize: 13, fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right_rounded,
        size: 17, color: BlinkColors.orange),
      onTap: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.pushNamed(route);
      },
    ),
  );
}
