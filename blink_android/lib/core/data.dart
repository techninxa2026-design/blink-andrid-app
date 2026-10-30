/// Readable, replaceable fixture data for UI previews. No fake API calls.
class DemoPerson {
  final String name;
  final String handle;
  final int avatar;
  final String subtitle;
  const DemoPerson(
    this.name,
    this.handle,
    this.avatar, [
    this.subtitle = 'Creator',
  ]);
}

const people = <DemoPerson>[
  DemoPerson('Arafat Hossain', '@arafat', 12, 'Photographer · Dhaka'),
  DemoPerson('Nusrat Jahan', '@nusrat', 47, 'Creator · Dhaka'),
  DemoPerson('Labib Ahmed', '@labib', 33, 'Designer · Dhaka'),
  DemoPerson('Samira Islam', '@samira', 44, 'Traveler · Dhaka'),
  DemoPerson('Nabil Karim', '@nabil', 13, 'Developer · Chattogram'),
  DemoPerson('Rifat Islam', '@rifat', 15, 'Creator · Sylhet'),
];

class DemoPost {
  final int author;
  final String caption;
  final int photo;
  final String likes;
  final String comments;
  const DemoPost(
    this.author,
    this.caption,
    this.photo,
    this.likes,
    this.comments,
  );
}

const posts = <DemoPost>[
  DemoPost(0, 'Chasing sunsets and little moments 🌅', 1011, '2.4k', '128'),
  DemoPost(1, 'Found my happy place this weekend ✨', 1018, '986', '64'),
  DemoPost(2, 'Another beautiful day to create.', 1015, '1.2k', '49'),
  DemoPost(3, 'These are the views I live for 🌿', 1016, '765', '28'),
];

const demoMessages = <String>[
  'Hey! How is everything?',
  'Going well. Working on Blink 🧡',
  'Can you share the details?',
  'Sure, I’ll send them here.',
];
