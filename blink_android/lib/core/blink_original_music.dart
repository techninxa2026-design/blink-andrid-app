import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The same six original, procedurally synthesized Blink tunes used by the web.
/// No commercial audio is bundled or streamed.
class BlinkOriginalTrack {
  const BlinkOriginalTrack(this.id, this.title, this.emoji, this.bpm,
      this.wave, this.notes);
  final String id, title, emoji, wave;
  final int bpm;
  final List<int> notes;
}

const blinkOriginalTracks = <BlinkOriginalTrack>[
  BlinkOriginalTrack('sunny-pop', 'Sunny Pop', '☀️', 114, 'triangle',
      [60,64,67,72,67,64,65,69,72,69,67,64,60,64,67,72]),
  BlinkOriginalTrack('dream-cloud', 'Dream Cloud', '☁️', 84, 'sine',
      [57,60,64,69,64,60,55,59,62,67,62,59,57,60,64,69]),
  BlinkOriginalTrack('neon-night', 'Neon Night', '🌃', 128, 'square',
      [48,55,60,63,60,55,50,57,62,65,62,57,48,55,60,67]),
  BlinkOriginalTrack('golden-hour', 'Golden Hour', '🌅', 96, 'triangle',
      [52,56,59,64,59,56,54,57,61,66,61,57,52,56,59,64]),
  BlinkOriginalTrack('little-steps', 'Little Steps', '✨', 122, 'sine',
      [72,74,76,79,76,74,72,69,71,74,76,78,76,74,71,72]),
  BlinkOriginalTrack('soft-waves', 'Soft Waves', '🌊', 80, 'sine',
      [55,59,62,67,62,59,53,57,60,65,60,57,55,59,62,67]),
];

BlinkOriginalTrack? blinkOriginalTrack(String? id) {
  for (final track in blinkOriginalTracks) {
    if (track.id == id) return track;
  }
  return null;
}

double _wave(double phase, String type) {
  if (type == 'square') {
    final x = 3.2 * math.sin(phase);
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }
  if (type == 'triangle') return 2 / math.pi * math.asin(math.sin(phase));
  return math.sin(phase);
}

Uint8List _makeWav(BlinkOriginalTrack track) {
  const rate = 22050, seconds = 16;
  const frames = rate * seconds;
  final bytes = ByteData(44 + frames * 2);
  void ascii(int at, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(at + i, text.codeUnitAt(i));
    }
  }
  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + frames * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, frames * 2, Endian.little);

  final step = 60 / track.bpm / 2;
  const tau = math.pi * 2;
  for (var i = 0; i < frames; i++) {
    final t = i / rate;
    final index = (t / step).floor() % track.notes.length;
    final local = t % step;
    final envelope = math.min(1.0, local * 35) *
        math.pow(math.max(0.0, 1 - local / step), .9).toDouble();
    final freq = 440 * math.pow(2, (track.notes[index] - 69) / 12);
    final lead = _wave(tau * freq * t, track.wave) * envelope * .24;
    final bassNote = track.notes[(index ~/ 4) * 4] - 24;
    final bassFreq = 440 * math.pow(2, (bassNote - 69) / 12);
    final bass = math.sin(tau * bassFreq * t) * .15 *
        (.55 + .45 * math.cos(tau * t / (step * 8)));
    final beat = t % (step * 2);
    final kick = math.sin(tau * (80 - 38 * math.min(beat / .13, 1)) * beat) *
        math.exp(-beat * 23) * .19;
    final sample = (lead + bass + kick).clamp(-.9, .9);
    bytes.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Own one of these per screen. Never keep an unowned global audio player.
class BlinkOriginalPlayer {
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;
  bool get isPlaying => _playingId != null;
  String? get playingId => _playingId;

  Future<void> play(String id) async {
    final track = blinkOriginalTrack(id);
    if (track == null) throw ArgumentError.value(id, 'id', 'Unknown Blink tune');
    if (_playingId == id) {
      await stop();
      return;
    }
    await stop();
    final file = File('${Directory.systemTemp.path}/blink_original_$id.wav');
    if (!await file.exists()) {
      final bytes = await compute(_makeWav, track);
      await file.writeAsBytes(bytes, flush: true);
    }
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(DeviceFileSource(file.path));
    _playingId = id;
  }

  Future<void> stop() async {
    _playingId = null;
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
