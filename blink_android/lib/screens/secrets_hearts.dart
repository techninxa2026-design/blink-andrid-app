import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/nav.dart';
import '../widgets/ui.dart';

class SecretsScreen extends StatefulWidget {
  const SecretsScreen({super.key});
  @override
  State<SecretsScreen> createState() => _SecretsScreenState();
}

class _SecretsScreenState extends State<SecretsScreen> {
  int? guess;
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Secrets',
    active: 'explore',
    trailing: IconButton(
      onPressed: () => go(context, '/secret/create'),
      icon: const Icon(Icons.add_circle_rounded, color: BlinkColors.orange),
    ),
    child: ScreenList(
      children: [
        const SectionHeading(
          'Secrets',
          subtitle: 'Anonymous questions, unexpected answers',
        ),
        const DemoTag('Discover the unexpected'),
        const SizedBox(height: 13),
        BlinkPanel(
          color: BlinkColors.pale,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: BlinkColors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Anonymous Secret',
                    style: TextStyle(
                      color: BlinkColors.orange,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.favorite, color: BlinkColors.orange, size: 19),
                ],
              ),
              const SizedBox(height: 21),
              const Text(
                'Can you guess my dream destination?',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 15),
              ...[
                'Japan',
                'Switzerland',
                'Norway',
                'New Zealand',
              ].asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => guess = e.key),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: guess == e.key
                            ? BlinkColors.orangeSoft
                            : Colors.white,
                        border: Border.all(
                          color: guess == e.key
                              ? BlinkColors.orange
                              : BlinkColors.line,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            guess == e.key
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off_rounded,
                            color: BlinkColors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(e.value, style: const TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              BlinkButton(
                'Submit Guess',
                onPressed: guess == null
                    ? null
                    : () => demoToast(
                        context,
                        'Guess selected. Rewards are verified by the Blink API.',
                      ),
              ),
              const SizedBox(height: 9),
              const Center(
                child: Text(
                  '30 guesses · Reveal in 6 hours',
                  style: TextStyle(fontSize: 10.5, color: BlinkColors.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        const BlinkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DemoTag('Anonymous'),
              SizedBox(height: 12),
              Text(
                'Guess where I am traveling next! ✈',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text(
                'Reveal in 12 hours',
                style: TextStyle(color: BlinkColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BlinkButton(
          'Create a Secret',
          icon: Icons.add,
          onPressed: () => go(context, '/secret/create'),
        ),
      ],
    ),
  );
}

class CreateSecretScreen extends StatefulWidget {
  const CreateSecretScreen({super.key});
  @override
  State<CreateSecretScreen> createState() => _CreateSecretScreenState();
}

class _CreateSecretScreenState extends State<CreateSecretScreen> {
  bool anonymous = true;
  String reveal = '6 hours';
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Create Secret',
    logoTitle: false,
    active: 'explore',
    child: ScreenList(
      children: [
        const SectionHeading('Create Secret', subtitle: 'Keep them guessing'),
        const BlinkField(
          label: 'Secret question',
          hint: 'Secret question',
          lines: 3,
        ),
        const BlinkField(label: 'Option A', hint: 'Option A'),
        const BlinkField(label: 'Option B', hint: 'Option B'),
        const BlinkField(label: 'Option C', hint: 'Option C'),
        const BlinkField(label: 'Option D', hint: 'Option D'),
        const Text(
          'Reveal after',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          initialValue: reveal,
          decoration: const InputDecoration(),
          items: [
            '1 hour',
            '6 hours',
            '12 hours',
            '24 hours',
            '48 hours',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => reveal = v ?? reveal),
        ),
        const SizedBox(height: 7),
        SwitchListTile.adaptive(
          activeTrackColor: BlinkColors.orange,
          title: const Text('Post anonymously', style: TextStyle(fontSize: 13)),
          value: anonymous,
          onChanged: (v) => setState(() => anonymous = v),
        ),
        const SizedBox(height: 11),
        BlinkButton(
          'Save Secret',
          onPressed: () => demoToast(
            context,
            'UI preview: connect to the Blink Secrets API.',
          ),
        ),
      ],
    ),
  );
}

class HeartsScreen extends StatelessWidget {
  const HeartsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Hearts',
    active: 'explore',
    child: ScreenList(
      children: [
        const SectionHeading(
          'Hearts',
          subtitle: 'Send meaningful anonymous messages',
        ),
        BlinkPanel(
          color: BlinkColors.pale,
          child: Column(
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: BlinkColors.pink,
                size: 49,
              ),
              const SizedBox(height: 8),
              const Text(
                'Send a meaningful message.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your heart can stay anonymous until you choose.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BlinkColors.muted, fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              BlinkButton(
                'Send a Heart',
                onPressed: () => go(context, '/heart/send'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        const BlinkChips(labels: ['Received', 'Sent']),
        const SizedBox(height: 11),
        ...[0, 1, 2].map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BlinkPanel(
              child: InkWell(
                onTap: () => go(context, '/heart/chat'),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: BlinkColors.orangeSoft,
                      child: Icon(
                        i == 0
                            ? Icons.favorite_rounded
                            : Icons.mark_email_unread_rounded,
                        color: BlinkColors.pink,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i == 0
                                ? 'Someone sent you a Heart'
                                : 'A special message',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap to read the message',
                            style: TextStyle(
                              color: BlinkColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: BlinkColors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class SendHeartScreen extends StatelessWidget {
  const SendHeartScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Send a Heart',
    logoTitle: false,
    active: 'explore',
    child: ScreenList(
      children: [
        const SectionHeading(
          'Send a Heart',
          subtitle: 'Say something special, anonymously',
        ),
        const BlinkField(label: 'Recipient', hint: 'Search a person'),
        const BlinkField(
          label: 'Your message',
          hint: 'Write from the heart...',
          lines: 6,
        ),
        const DemoNotice(
          'The receiver decides whether to accept your anonymous Heart.',
        ),
        const SizedBox(height: 22),
        BlinkButton(
          'Send Heart',
          icon: Icons.favorite_rounded,
          onPressed: () => demoToast(
            context,
            'UI preview: connect to the Blink Hearts API.',
          ),
        ),
      ],
    ),
  );
}

class HeartConversationScreen extends StatefulWidget {
  const HeartConversationScreen({super.key});
  @override
  State<HeartConversationScreen> createState() =>
      _HeartConversationScreenState();
}

class _HeartConversationScreenState extends State<HeartConversationScreen> {
  bool accepted = false;
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Heart Conversation',
    logoTitle: false,
    active: 'explore',
    child: ScreenList(
      children: [
        const SectionHeading(
          'Heart Conversation',
          subtitle: 'A private space for meaningful words',
        ),
        const SizedBox(height: 7),
        const BlinkPanel(
          child: Row(
            children: [
              Icon(Icons.favorite_rounded, color: BlinkColors.pink),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I wanted to say thank you. You are a truly special person. 🧡',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Align(
          alignment: Alignment.centerRight,
          child: DemoTag('That means a lot. ❤️'),
        ),
        const SizedBox(height: 20),
        const BlinkField(
          label: 'Reply',
          hint: 'Write your response...',
          lines: 3,
        ),
        BlinkButton(
          accepted ? 'Reply to Heart' : 'Accept and Reply',
          onPressed: () {
            setState(() => accepted = true);
            demoToast(
              context,
              'UI preview: heart acceptance and reply need the API.',
            );
          },
        ),
        const SizedBox(height: 11),
        BlinkButton(
          'Decline',
          outline: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
