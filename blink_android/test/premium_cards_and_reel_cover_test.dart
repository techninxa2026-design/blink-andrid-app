import 'dart:typed_data';

import 'package:blink_android/core/reel_cover.dart';
import 'package:blink_android/core/theme.dart';
import 'package:blink_android/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Reel cover validation rejects empty, PNG and truncated JPEG data', () {
    expect(BlinkReelCover.isJpeg(Uint8List(0)), isFalse);
    expect(BlinkReelCover.isJpeg(Uint8List.fromList([0x89, 0x50, 0x4e, 0x47])),
        isFalse);
    expect(BlinkReelCover.isJpeg(Uint8List.fromList([0xff, 0xd8, 0, 0])),
        isFalse);
    expect(BlinkReelCover.isJpeg(Uint8List.fromList(
      [0xff, 0xd8, 0xff, 0xe0, 1, 2, 0xff, 0xd9])), isTrue);
  });

  for (final width in [280.0, 320.0, 360.0, 412.0]) {
    testWidgets('premium cards fit ${width.toInt()}px with enlarged text',
        (tester) async {
      tester.view.physicalSize = Size(width, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var taps = 0;
      var actions = 0;
      await tester.pumpWidget(MaterialApp(
        theme: blinkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.7)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              BlinkProListCard(
                icon: Icons.business_center_outlined,
                eyebrow: 'BLINK EXCHANGE / BUSINESS',
                title: 'Long business partnership opportunity title',
                subtitle: 'A longer professional introduction that must remain '
                    'readable and should not overlap the orange metadata badges.',
                badges: const [
                  BlinkInfoPill('International supplier cooperation',
                    icon: Icons.location_on_outlined, highlight: true),
                  BlinkInfoPill('OPEN', icon: Icons.visibility_outlined),
                ],
                footer: Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton(
                    onPressed: () => actions++, child: const Text('View details')),
                  FilledButton(
                    onPressed: () => actions++, child: const Text('Contact')),
                ]),
                onTap: () => taps++,
              ),
              const BlinkProCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verified Creator Task',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    BlinkInfoPill('12 BP',
                      icon: Icons.stars_outlined, highlight: true),
                    BlinkInfoPill('PUBLISHED',
                      icon: Icons.check_circle_outline),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Contact'));
      await tester.pump();
      expect(actions, 1);
      expect(taps, 0);

      await tester.tap(find.text('Long business partnership opportunity title'));
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
