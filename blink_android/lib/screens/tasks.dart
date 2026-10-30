import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/nav.dart';
import '../core/data.dart';
import '../widgets/ui.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Creator Tasks',
    active: 'explore',
    trailing: IconButton(
      onPressed: () => go(context, '/creator'),
      icon: const Icon(Icons.dashboard_outlined, color: BlinkColors.orange),
    ),
    child: ListView(
      children: [
        const SectionHeading(
          'Today’s Tasks',
          subtitle: 'Participate, create, and earn Blink Points',
        ),
        const BlinkChips(labels: ['All', 'Explore', 'Trending']),
        const SizedBox(height: 13),
        ...<(String, String, String, int)>[
          (
            'Visit and review a local café',
            'Earn for honest reviews',
            '2.0 BP',
            1011,
          ),
          (
            'Create a genuine product review',
            'Post your real experience',
            '3.5 BP',
            1015,
          ),
          (
            'Take a new place picture',
            'Discover your neighborhood',
            '1.5 BP',
            1018,
          ),
          (
            'Share an outdoor adventure',
            'Capture a beautiful moment',
            '2.5 BP',
            1016,
          ),
        ].map(
          (item) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
            child: BlinkPanel(
              child: InkWell(
                onTap: () => go(context, '/task/detail'),
                child: Row(
                  children: [
                    BlinkPhoto(id: item.$4, width: 73, height: 77),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: BlinkColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.$3,
                            style: const TextStyle(
                              fontSize: 12,
                              color: BlinkColors.orange,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: BlinkColors.muted,
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

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Task Details',
    active: 'explore',
    child: ScreenList(
      children: [
        const SizedBox(height: 12),
        BlinkUserLine(person: people[0], subtitle: 'Created by Arafat Hossain'),
        const SectionHeading(
          'Visit and review a local café',
          subtitle: 'Earn 2.0 BP for completing this task',
        ),
        const DemoTag('2.0 BP reward'),
        const SizedBox(height: 17),
        const Text(
          'Requirements',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 9),
        BlinkPanel(
          child: Column(
            children: const [
              _TaskRequirement('Go to a café in your area'),
              Divider(),
              _TaskRequirement('Take an original photo'),
              Divider(),
              _TaskRequirement('Share your genuine experience'),
            ],
          ),
        ),
        const SizedBox(height: 19),
        const Text(
          'Description',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 7),
        const Text(
          'Discover a local café and share what you liked about it. A creator will review your submission before awarding BP.',
          style: TextStyle(
            color: BlinkColors.muted,
            fontSize: 12.5,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 21),
        BlinkButton(
          'Participate & Submit',
          onPressed: () => go(context, '/task/submit'),
        ),
      ],
    ),
  );
}

class _TaskRequirement extends StatelessWidget {
  final String label;
  const _TaskRequirement(this.label);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.check_circle_outline_rounded,
        color: BlinkColors.orange,
        size: 20,
      ),
      const SizedBox(width: 11),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
    ],
  );
}

class SubmitTaskScreen extends StatelessWidget {
  const SubmitTaskScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Submit Task',
    logoTitle: false,
    active: 'explore',
    child: ScreenList(
      children: [
        const SectionHeading(
          'Submit Task',
          subtitle: 'Show the creator what you completed',
        ),
        const BlinkField(
          label: 'Your explanation',
          hint: 'Explain how you completed this task...',
          lines: 6,
        ),
        BlinkPanel(
          child: Column(
            children: [
              BlinkOptionRow(
                icon: Icons.add_photo_alternate_outlined,
                text: 'Add image evidence',
                onTap: () => demoToast(context, 'Requires media picker.'),
              ),
              const Divider(),
              BlinkOptionRow(
                icon: Icons.video_library_outlined,
                text: 'Add video evidence',
                onTap: () => demoToast(context, 'Requires media picker.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        const DemoNotice(
          'Submissions require creator verification before BP is awarded. Evidence should be authentic.',
        ),
        const SizedBox(height: 19),
        BlinkButton(
          'Submit for Review',
          onPressed: () => demoToast(
            context,
            'UI preview: connect to /task-participations.',
          ),
        ),
      ],
    ),
  );
}

class CreatorDashboardScreen extends StatelessWidget {
  const CreatorDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => BlinkScreen(
    title: 'Creator Dashboard',
    active: 'explore',
    child: ListView(
      children: [
        const SectionHeading(
          'Creator Dashboard',
          subtitle: 'Your creative impact, all in one place',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: BlinkPanel(child: BlinkCount('3', 'Active tasks')),
              ),
              SizedBox(width: 9),
              Expanded(
                child: BlinkPanel(child: BlinkCount('12', 'Participants')),
              ),
              SizedBox(width: 9),
              Expanded(
                child: BlinkPanel(child: BlinkCount('24.5', 'BP Earned')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BlinkButton(
            'Create New Task',
            icon: Icons.add_circle_outline,
            onPressed: () => demoToast(
              context,
              'Connect create-task form and /tasks endpoint.',
            ),
          ),
        ),
        const SectionHeading('Recent Activity'),
        ...[
          'Arafat submitted new task evidence',
          'Labib completed café review',
          'Samira requested verification',
          'Nusrat earned BP from a task',
        ].asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: BlinkPanel(
              child: BlinkUserLine(
                person: people[e.key % people.length],
                subtitle: e.value,
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
