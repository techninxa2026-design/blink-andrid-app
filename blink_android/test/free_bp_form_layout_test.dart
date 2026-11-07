import 'package:blink_android/core/blink_home_api.dart';
import 'package:blink_android/core/theme.dart';
import 'package:blink_android/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('free Moment BP gifts', () {
    test('a member with zero earned BP can give BP without any balance field', () {
      for (final amount in BlinkHomeApi.momentGiftChoices) {
        final request = BlinkHomeApi.freeBpGiftPayload(
          momentId: 'moment-from-another-user',
          creatorId: 'creator',
          senderId: 'sender-with-zero-bp',
          amount: amount,
        );
        expect(request, {'amount': amount});
        expect(request.containsKey('balance'), isFalse);
        expect(request.containsKey('decrement'), isFalse);
        expect(request.containsKey('senderId'), isFalse);
        expect(request.containsKey('creatorId'), isFalse);
      }
    });

    test('prevents gifts to your own Moment', () {
      expect(() => BlinkHomeApi.freeBpGiftPayload(
        momentId: 'moment1', creatorId: 'self',
        senderId: 'self', amount: 5), throwsA(isA<BlinkHomeError>()));
    });

    test('rejects invalid gift choices and missing Moment identity', () {
      expect(() => BlinkHomeApi.freeBpGiftPayload(
        momentId: 'moment1', creatorId: 'owner',
        senderId: 'viewer', amount: 0), throwsA(isA<BlinkHomeError>()));
      expect(() => BlinkHomeApi.freeBpGiftPayload(
        momentId: 'moment1', creatorId: 'owner',
        senderId: 'viewer', amount: 101), throwsA(isA<BlinkHomeError>()));
      expect(() => BlinkHomeApi.freeBpGiftPayload(
        momentId: '', creatorId: 'owner',
        senderId: 'viewer', amount: 5), throwsA(isA<BlinkHomeError>()));
    });
  });

  Widget createForm({double scale = 1}) => MaterialApp(
    theme: blinkTheme(),
    builder: (context, page) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale)),
      child: page ?? const SizedBox.shrink()),
    home: BlinkCreateLayout(
      title: 'New Creator Task',
      subtitle: 'Enter your details with no overlapping or clipped controls.',
      icon: Icons.task_alt_rounded,
      primaryLabel: 'Save Creator Task',
      onSubmit: () {},
      content: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlinkFormSection(
            heading: 'Task details',
            helper: 'Fields should expand safely on small phones.',
            children: [
              TextField(decoration: InputDecoration(
                labelText: 'Title', hintText: 'A meaningful title')),
              SizedBox(height: 12),
              TextField(maxLines: 4, decoration: InputDecoration(
                labelText: 'Instructions')),
            ],
          ),
          SizedBox(height: 14),
          BlinkFormSection(
            heading: 'Photo attachments',
            children: [
              OutlinedButton(onPressed: null, child: Text('Choose photos')),
            ],
          ),
        ],
      ),
    ),
  );

  for (final width in [280.0, 320.0, 360.0, 412.0]) {
    testWidgets('create/edit form is scrollable at ${width.toInt()}px and large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 540);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(createForm(scale: 1.55));
        await tester.pump();
        expect(find.text('Save Creator Task'), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Choose photos'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('create dialog stays within compact phone bounds',
    (tester) async {
      tester.view.physicalSize = const Size(280, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        theme: blinkTheme(),
        home: Scaffold(body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => BlinkFormDialog(
                title: 'Create an IRL plan',
                subtitle: 'Complete this form on a smaller phone.',
                content: const Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(decoration: InputDecoration(labelText: 'Title')),
                  SizedBox(height: 12),
                  TextField(decoration: InputDecoration(labelText: 'Location')),
                ]),
                actions: [TextButton(onPressed: () =>
                    Navigator.pop(context), child: const Text('Cancel'))],
              ),
            ),
            child: const Text('Open'),
          ),
        )),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Create an IRL plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
