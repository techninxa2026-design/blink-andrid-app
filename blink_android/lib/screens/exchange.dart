import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/nav.dart';
import '../core/data.dart';
import '../widgets/ui.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});
  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final services = <(String, String, int, String)>[
      (
        'Custom website development',
        'Responsive website and web apps',
        1015,
        'Web Development',
      ),
      (
        'Flutter mobile app',
        'Android and iOS app development',
        1005,
        'Mobile App',
      ),
      (
        'UI / UX and Branding',
        'Modern design for your product',
        1018,
        'Design',
      ),
      (
        'Creator Video Production',
        'Short videos that tell stories',
        1011,
        'Video',
      ),
    ];
    return BlinkScreen(
      title: 'Exchange',
      active: 'explore',
      trailing: IconButton(
        onPressed: () => go(context, '/exchange/create'),
        icon: const Icon(Icons.add_circle_rounded, color: BlinkColors.orange),
      ),
      child: Column(
        children: [
          const SectionHeading(
            'Service Listings',
            subtitle: 'Discover a service or offer your own',
          ),
          BlinkChips(
            labels: const ['All', 'My Posts', 'Categories'],
            onChanged: (i) => setState(() => filter = i),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 3, 14, 14),
              itemCount: services.length,
              itemBuilder: (context, i) {
                final s = services[(i + filter) % services.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BlinkPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BlinkUserLine(
                          person: people[i % people.length],
                          subtitle: 'Service provider',
                        ),
                        BlinkPhoto(id: s.$3, height: 165),
                        const SizedBox(height: 11),
                        DemoTag(s.$4),
                        const SizedBox(height: 7),
                        Text(
                          s.$1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          s.$2,
                          style: const TextStyle(
                            color: BlinkColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: BlinkButton(
                                'View Details',
                                onPressed: () =>
                                    go(context, '/exchange/detail'),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: BlinkButton(
                                'Chat',
                                outline: true,
                                onPressed: () => go(context, '/chat'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: BlinkButton(
              'Create Service Post',
              icon: Icons.add_rounded,
              onPressed: () => go(context, '/exchange/create'),
            ),
          ),
        ],
      ),
    );
  }
}

class ExchangeDetailScreen extends StatelessWidget {
  const ExchangeDetailScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Service Details',
    active: 'explore',
    child: ScreenList(
      children: [
        const SizedBox(height: 8),
        BlinkUserLine(
          person: people.first,
          subtitle: 'Service provider · 2h ago',
        ),
        const BlinkPhoto(id: 1015, height: 230),
        const SectionHeading(
          'Custom website development',
          subtitle: 'Web development · Available now',
        ),
        const Text(
          'Description',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        const Text(
          'Custom responsive business websites, high-performance web applications and ongoing support. Built around your needs with professional design and clean code.',
          style: TextStyle(
            fontSize: 12.5,
            color: BlinkColors.muted,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            DemoTag('Web App'),
            SizedBox(width: 8),
            DemoTag('UI / UX'),
            SizedBox(width: 8),
            DemoTag('Maintenance'),
          ],
        ),
        const SizedBox(height: 23),
        BlinkButton(
          'Propose Price',
          onPressed: () => go(context, '/exchange/offer'),
        ),
        const SizedBox(height: 10),
        BlinkButton(
          'Chat with Provider',
          outline: true,
          onPressed: () => go(context, '/chat'),
        ),
      ],
    ),
  );
}

class ProposeOfferScreen extends StatefulWidget {
  const ProposeOfferScreen({super.key});
  @override
  State<ProposeOfferScreen> createState() => _ProposeOfferScreenState();
}

class _ProposeOfferScreenState extends State<ProposeOfferScreen> {
  String currency = 'BDT';
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Propose Offer',
    logoTitle: false,
    active: 'explore',
    child: ScreenList(
      children: [
        const SectionHeading(
          'Propose Offer',
          subtitle: 'Make a fair offer for the service',
        ),
        const BlinkField(
          label: 'Offer amount',
          hint: 'Enter amount',
          icon: Icons.payments_outlined,
          keyboardType: TextInputType.number,
        ),
        const Text(
          'Currency',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: currency,
          items: [
            'BDT',
            'USD',
            'EUR',
            'GBP',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => currency = v ?? currency),
        ),
        const SizedBox(height: 17),
        const BlinkField(
          label: 'Your message',
          hint: 'Tell the provider more about your request...',
          lines: 5,
        ),
        const DemoNotice(
          'The provider can accept or decline your offer. You can make another offer later.',
        ),
        const SizedBox(height: 17),
        BlinkButton(
          'Submit Offer',
          onPressed: () => demoToast(
            context,
            'UI preview: connect to /exchange price offers.',
          ),
        ),
      ],
    ),
  );
}

class CreateServiceScreen extends StatelessWidget {
  const CreateServiceScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Create Service',
    logoTitle: false,
    active: 'explore',
    child: ScreenList(
      children: [
        const SectionHeading(
          'Create Service',
          subtitle: 'Tell your community what you offer',
        ),
        const BlinkField(label: 'Service title', hint: 'Service title'),
        const BlinkField(
          label: 'Description',
          hint: 'Describe your service',
          lines: 5,
        ),
        const BlinkField(label: 'Category', hint: 'e.g. Software Development'),
        BlinkPanel(
          child: Column(
            children: [
              BlinkOptionRow(
                icon: Icons.add_photo_alternate_outlined,
                text: 'Media attachments',
                onTap: () =>
                    demoToast(context, 'Connect gallery/media picker.'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.sell_outlined,
                text: 'Pricing',
                detail: 'Negotiable',
                onTap: () => demoToast(context),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.public,
                text: 'Visibility',
                detail: 'Public',
                onTap: () => demoToast(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 19),
        BlinkButton(
          'Save Post',
          onPressed: () =>
              demoToast(context, 'UI preview: connect to POST /exchange.'),
        ),
      ],
    ),
  );
}
