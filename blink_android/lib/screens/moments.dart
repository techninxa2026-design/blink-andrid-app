import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/nav.dart';
import '../core/data.dart';
import '../widgets/ui.dart';

class CreateMomentScreen extends StatelessWidget {
  const CreateMomentScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Create Moment',
    logoTitle: false,
    active: 'home',
    child: ScreenList(
      children: [
        const SizedBox(height: 15),
        const SectionHeading(
          'Create Moment',
          subtitle: 'Capture something unforgettable',
        ),
        Stack(
          children: [
            const BlinkPhoto(id: 1018, height: 380),
            Positioned(
              top: 14,
              left: 12,
              child: _MediaChip('♫ Add music', Icons.music_note_rounded),
            ),
            Positioned(
              top: 14,
              right: 12,
              child: _MediaChip('Filters', Icons.auto_fix_high_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        BlinkButton('Continue', onPressed: () => go(context, '/moment/edit')),
        const SizedBox(height: 12),
        BlinkButton(
          'Open Capture',
          outline: true,
          onPressed: () => go(context, '/capture'),
        ),
      ],
    ),
  );
}

class _MediaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MediaChip(this.label, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class EditMomentScreen extends StatelessWidget {
  const EditMomentScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Edit & Publish',
    logoTitle: false,
    active: 'home',
    child: ScreenList(
      children: [
        const SectionHeading('Edit & Publish'),
        const BlinkPhoto(id: 1018, height: 260),
        const SizedBox(height: 15),
        const BlinkField(
          label: 'Caption',
          hint: 'Write a caption...',
          lines: 3,
        ),
        BlinkPanel(
          child: Column(
            children: [
              BlinkOptionRow(
                icon: Icons.location_on_rounded,
                text: 'Add location',
                onTap: () => demoToast(
                  context,
                  'Location picker requires device location permission.',
                ),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.people_alt_rounded,
                text: 'Tag people',
                onTap: () => go(context, '/people'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.music_note_rounded,
                text: 'Add music',
                onTap: () => demoToast(context),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.public_rounded,
                text: 'Visibility',
                detail: 'Public',
                onTap: () => demoToast(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BlinkButton(
          'Publish Moment',
          onPressed: () {
            demoToast(
              context,
              'UI preview: hook this form up to POST /moments.',
            );
            go(context, '/moments');
          },
        ),
      ],
    ),
  );
}

class MomentDetailScreen extends StatefulWidget {
  const MomentDetailScreen({super.key});
  @override
  State<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends State<MomentDetailScreen> {
  bool liked = false, saved = false;
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Moment View',
    active: 'home',
    trailing: IconButton(
      onPressed: () => go(context, '/moment/viewers'),
      icon: const Icon(Icons.visibility_outlined, color: BlinkColors.orange),
    ),
    child: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BlinkUserLine(person: people.first, subtitle: '2h ago'),
        ),
        const BlinkPhoto(id: 1015, height: 425, radius: BorderRadius.zero),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => liked = !liked),
                icon: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: BlinkColors.orange,
                ),
              ),
              const Text('2.4k', style: TextStyle(fontSize: 12)),
              IconButton(
                onPressed: () => go(context, '/moment/comments'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              const Text('128', style: TextStyle(fontSize: 12)),
              IconButton(
                onPressed: () => go(context, '/share'),
                icon: const Icon(Icons.send_rounded),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => saved = !saved),
                icon: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'What a beautiful view. Life is made of moments like this ✨',
            style: TextStyle(fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: BlinkButton(
                  'Comments',
                  outline: true,
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () => go(context, '/moment/comments'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BlinkButton(
                  'Viewers',
                  icon: Icons.visibility_outlined,
                  onPressed: () => go(context, '/moment/viewers'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MomentCommentsScreen extends StatefulWidget {
  const MomentCommentsScreen({super.key});
  @override
  State<MomentCommentsScreen> createState() => _MomentCommentsScreenState();
}

class _MomentCommentsScreenState extends State<MomentCommentsScreen> {
  final controller = TextEditingController();
  final extra = <String>[];
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Comments',
    active: 'home',
    logoTitle: false,
    child: Column(
      children: [
        const SectionHeading('Comments', subtitle: 'What people are saying'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5 + extra.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BlinkPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlinkUserLine(
                      person: people[index % people.length],
                      subtitle: '${index + 1}h ago',
                      trailing: IconButton(
                        onPressed: () => demoToast(context, 'Reply to comment'),
                        icon: const Icon(Icons.reply_rounded, size: 19),
                      ),
                    ),
                    Text(
                      index < 5
                          ? const [
                              'So beautiful! 🔥',
                              'Looks amazing, where is this?',
                              'Incredible shot!',
                              'This made my day 🧡',
                              'Love this place!',
                            ][index]
                          : extra[index - 5],
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '♡ Like     ↩ Reply',
                      style: TextStyle(
                        color: BlinkColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                BlinkAvatar(person: people[1], size: 36),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty)
                      setState(() {
                        extra.add(controller.text.trim());
                        controller.clear();
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

class MomentViewersScreen extends StatelessWidget {
  const MomentViewersScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Viewers',
    logoTitle: false,
    active: 'home',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          '128 viewers',
          subtitle: 'People who viewed this moment',
        ),
        const Divider(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            itemBuilder: (_, i) => BlinkUserLine(
              person: people[i % people.length],
              subtitle: i % 2 == 0 ? '2h ago' : 'Yesterday',
              trailing: const Icon(Icons.more_horiz, color: BlinkColors.muted),
            ),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: 21,
          ),
        ),
      ],
    ),
  );
}
