import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_video_thumbnail/get_video_thumbnail.dart' as thumbnail;
import 'package:get_video_thumbnail/index.dart' as thumbnail_format;

/// Prepares a valid JPEG cover for a Reel. Android uses a native extractor
/// that never sends width/height=0 into MediaMetadataRetriever. It can also
/// supply a branded JPEG when a particular codec cannot yield a frame.
class BlinkReelCover {
  BlinkReelCover._();

  static const MethodChannel _channel =
      MethodChannel('blink_android/reel_cover');

  static bool isJpeg(Uint8List data) =>
      data.length >= 4 &&
      data[0] == 0xFF &&
      data[1] == 0xD8 &&
      data[data.length - 2] == 0xFF &&
      data[data.length - 1] == 0xD9;

  static Future<Uint8List> generate(File video) async {
    if (!await video.exists() || await video.length() == 0) {
      throw const ReelCoverException(
        'The video file is empty or was removed. Record the Reel again.');
    }
    if (Platform.isAndroid) {
      try {
        final data = await _channel.invokeMethod<Uint8List>(
          'thumbnailJpeg',
          {'path': video.path, 'timeMs': 250},
        );
        if (data != null && isJpeg(data)) return data;
      } on PlatformException catch (error) {
        debugPrint('Blink Reel native cover fallback: ${error.code}');
      } on MissingPluginException {
        debugPrint('Blink Reel native cover channel unavailable; trying plugin.');
      }
    }

    // iOS fallback / older Android builds that do not yet have the channel.
    // Always supply both dimensions so Android cannot pass an invalid 0 height.
    for (final timeMs in <int>[0, 250]) {
      try {
        final bytes = await thumbnail.VideoThumbnail.thumbnailData(
          video: video.path,
          imageFormat: thumbnail_format.ImageFormat.JPEG,
          maxWidth: 480,
          maxHeight: 720,
          timeMs: timeMs,
          quality: 82,
        );
        if (isJpeg(bytes)) return bytes;
      } catch (error) {
        debugPrint('Blink Reel legacy cover attempt failed: $error');
      }
    }
    throw const ReelCoverException(
      'Unable to prepare a Reel cover. Try another video or record again.');
  }
}

class ReelCoverException implements Exception {
  const ReelCoverException(this.message);
  final String message;
  @override
  String toString() => message;
}
