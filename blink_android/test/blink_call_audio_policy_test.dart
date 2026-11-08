import 'package:flutter_test/flutter_test.dart';
import 'package:blink_android/calls/blink_call_audio_policy.dart';

void main() {
  test('voice calls use earpiece rather than loudspeaker by default', () {
    expect(BlinkCallAudioPolicy.defaultSpeaker(video: false), false);
    expect(BlinkCallAudioPolicy.defaultSpeaker(video: true), true);
  });

  test('voice call requests microphone processing and no camera', () {
    final options = BlinkCallAudioPolicy.captureConstraints(video: false);
    final audio = options['audio'] as Map<String, dynamic>;
    expect(audio['echoCancellation'], true);
    expect(audio['noiseSuppression'], true);
    expect(audio['autoGainControl'], true);
    expect(audio['channelCount'], 1);
    expect(options['video'], false);
  });

  test('video call keeps same echo suppression with camera', () {
    final options = BlinkCallAudioPolicy.captureConstraints(video: true);
    final audio = options['audio'] as Map<String, dynamic>;
    expect(audio['echoCancellation'], true);
    expect(audio['noiseSuppression'], true);
    expect(audio['autoGainControl'], true);
    expect(options['video'], isA<Map<String, dynamic>>());
  });
}
