import 'dart:convert';

import 'package:blink_android/calls/blink_call_history.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> entry(String status, {String kind = 'audio'}) => {
  'mediaType': 'call',
  'senderId': 'user-a',
  'body': jsonEncode({
    'version': 1,
    'callId': 'sample-id',
    'kind': kind,
    'outcome': status,
    'durationSeconds': 95,
  }),
};

void main() {
  test('missed call is distinct for caller and recipient', () {
    final value = BlinkCallHistory.parse(entry('missed'))!;
    expect(value.label(isCaller: true), contains('No answer'));
    expect(value.label(isCaller: false), 'Missed voice call');
  });

  test('completed video shows duration', () {
    final value = BlinkCallHistory.parse(entry('completed', kind: 'video'))!;
    expect(value.isVideo, true);
    expect(value.label(isCaller: false), 'Video call · 1m 35s');
  });

  test('ignored if record is a normal user text or malformed call JSON', () {
    expect(BlinkCallHistory.parse({'mediaType': null, 'body': '{}'}), isNull);
    expect(BlinkCallHistory.parse({'mediaType': 'call', 'body': '{bad'}), isNull);
  });
}
