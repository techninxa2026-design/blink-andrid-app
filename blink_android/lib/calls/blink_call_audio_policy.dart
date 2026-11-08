/// Shared call audio policy for the supported Blink Android WebRTC pipeline.
/// Voice calls default to the earpiece to reduce acoustic feedback; video
/// calls allow hands-free speakerphone with native echo control.
class BlinkCallAudioPolicy {
  const BlinkCallAudioPolicy._();

  static bool defaultSpeaker({required bool video}) => video;

  static Map<String, dynamic> captureConstraints({required bool video}) =>
      <String, dynamic>{
        'audio': <String, dynamic>{
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'channelCount': 1,
        },
        'video': video
            ? <String, dynamic>{
                'facingMode': 'user',
                'width': 720,
                'height': 1280,
              }
            : false,
      };
}
