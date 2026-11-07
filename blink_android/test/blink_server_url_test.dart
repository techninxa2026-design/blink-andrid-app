import 'package:flutter_test/flutter_test.dart';
import 'package:blink_android/core/blink_auth_api.dart';
import 'package:blink_android/core/blink_home_api.dart';

void main() {
  test('Android emulator default uses 10.0.2.2 instead of device localhost', () {
    expect(BlinkAuthApi.baseUrl, 'http://10.0.2.2:3000');
  });

  test('normalizes the actual NestJS API origin', () {
    expect(BlinkAuthApi.normalizeServerUrl(' http://192.168.0.104:3000/ '),
      'http://192.168.0.104:3000');
    expect(BlinkAuthApi.normalizeServerUrl('https://api.example.com/'),
      'https://api.example.com');
    expect(BlinkAuthApi.normalizeServerUrl('http://10.0.2.2:3000'),
      'http://10.0.2.2:3000');
  });

  for (final invalid in [
    '127.0.0.1:3000',
    'ftp://192.168.1.12:3000',
    'http://192.168.1.12:3000/moments',
    'http://192.168.1.12:3000?token=test',
    'http://person:secret@192.168.1.12:3000',
    'https://api.example.com/#fragment',
    '',
  ]) {
    test('rejects unsafe or incorrect API address: $invalid', () {
      expect(() => BlinkAuthApi.normalizeServerUrl(invalid),
        throwsA(isA<BlinkAuthException>()));
    });
  }

  test('legacy expired error includes API connection diagnostics', () {
    final message = BlinkHomeApi.momentActionError(
      const BlinkHomeError('Moment is unavailable or expired.', status: 404));
    expect(message, contains('check API connection settings'));
    expect(message, contains(BlinkAuthApi.baseUrl));
    expect(message, contains('Refresh the feed'));
    expect(message, contains('update and restart'));
  });

  test('valid React/BP errors are not rewritten as server mismatches', () {
    const error = BlinkHomeError(
      'You cannot gift BP to your own Moment.', status: 400);
    expect(BlinkHomeApi.momentActionError(error), error.message);
  });
}
