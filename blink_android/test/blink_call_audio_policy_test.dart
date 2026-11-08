import 'package:flutter_test/flutter_test.dart';
import 'package:blink_android/calls/blink_call_audio_policy.dart';

void main() {
  test('voice calls use earpiece rather than loudspeaker by default', () {
    expect(BlinkCallAudioPolicy.defaultSpeaker(video: false), false);
    expect(BlinkCallAudioPolicy.defaultSpeaker(video: true), true);
  });

  test('voice call requests microphone processing and no camera', () {
    final options = BlinkCallAudioPolicy.captureConstraints(video: false, native: false);
    final audio = options['audio'] as Map<String, dynamic>;
    expect(audio['echoCancellation'], true);
    expect(audio['noiseSuppression'], true);
    expect(audio['autoGainControl'], true);
    expect(audio['channelCount'], 1);
    expect(options['video'], false);
  });

  test('video call keeps same echo suppression with camera', () {
    final options = BlinkCallAudioPolicy.captureConstraints(video: true, native: false);
    final audio = options['audio'] as Map<String, dynamic>;
    expect(audio['echoCancellation'], true);
    expect(audio['noiseSuppression'], true);
    expect(audio['autoGainControl'], true);
    expect(options['video'], isA<Map<String, dynamic>>());
  });
  for (final video in [false, true]) {
    test('native capture enables parsed WebRTC echo control, video=$video', () {
      final options = BlinkCallAudioPolicy.captureConstraints(video: video);
      final audio = options['audio'] as Map<String, dynamic>;
      expect(audio['mandatory'], isEmpty);
      final optional = audio['optional'] as List<Map<String, dynamic>>;
      final processing = {for (final item in optional) ...item};
      expect(processing['googEchoCancellation'], true);
      expect(processing['googNoiseSuppression'], true);
      expect(processing['googAutoGainControl'], true);
      expect(options['video'], video ? isA<Map<String, dynamic>>() : false);
    });
  }
}
