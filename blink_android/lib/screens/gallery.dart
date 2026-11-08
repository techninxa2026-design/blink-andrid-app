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
          const BlinkFeatureHero(
            eyebrow:'THE WHOLE BLINK UNIVERSE',
            title:'Every experience. One design.',
            subtitle:'Explore the complete set of screens and check every detail.',
            icon:Icons.dashboard_customize_rounded,
            mood:BlinkMood.studio,
          ),
          BlinkSearchBox(
            hint: 'Filter the screens...',
            onChanged: (v) => setState(() => query = v),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: routes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 1),
              itemBuilder: (context, i) {
                final path = routes[i];
                return BlinkProListCard(
                  icon:Icons.arrow_outward_rounded,
                  eyebrow:'SCREEN ${i+1} · PREVIEW',
                  title:path=='/home'?'Home & Moments'
                    :path.split('/').where((e)=>e.isNotEmpty)
                      .map((e)=>'${e[0].toUpperCase()}${e.substring(1)}').join(' · '),
                  subtitle:path,
                  onTap:()=>go(context,path),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
