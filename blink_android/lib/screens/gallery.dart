import 'package:flutter/material.dart';

import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// A developer-only screen index for visually reviewing every mockup route.
class ScreenGalleryScreen extends StatefulWidget {
  const ScreenGalleryScreen({super.key});
  @override
  State<ScreenGalleryScreen> createState() => _ScreenGalleryScreenState();
}

class _ScreenGalleryScreenState extends State<ScreenGalleryScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final routes = BlinkRoutes.pages.keys
        .where(
          (r) =>
              r != '/' &&
              r != '/ui-gallery' &&
              r.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return BlinkScreen(
      title: 'Screen Gallery',
      logoTitle: false,
      active: 'explore',
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(17, 16, 17, 3),
            child: Text(
              'Every Blink design screen',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(17, 0, 17, 7),
            child: Text(
              'Tap any route to review its Flutter layout on your device.',
              style: TextStyle(fontSize: 12, color: BlinkColors.muted),
            ),
          ),
          BlinkSearchBox(
            hint: 'Filter the screens...',
            onChanged: (v) => setState(() => query = v),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: routes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final path = routes[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: BlinkColors.orangeSoft,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: BlinkColors.orange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    path == '/home'
                        ? 'Home & Moments'
                        : path
                              .split('/')
                              .where((e) => e.isNotEmpty)
                              .map(
                                (e) => '${e[0].toUpperCase()}${e.substring(1)}',
                              )
                              .join(' · '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    path,
                    style: const TextStyle(
                      fontSize: 10,
                      color: BlinkColors.muted,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: BlinkColors.orange,
                  ),
                  onTap: () => go(context, path),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
