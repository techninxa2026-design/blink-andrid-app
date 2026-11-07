import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'blink_auth_api.dart';
import 'live_api.dart';

/// Shared upload protocol used by both the web app and Flutter.
class BlinkTaskUploads {
  BlinkTaskUploads._();

  static Future<String> uploadImage(File file, {required bool creator}) async {
    final name = file.path.toLowerCase();
    if (!['.jpg','.jpeg','.png','.webp'].any(name.endsWith)) {
      throw const LiveApiError('Select a JPEG, PNG or WebP image.');
    }
    final size = await file.length();
    if (size <= 0 || size > 10 * 1024 * 1024) {
      throw const LiveApiError('Image must be under 10 MB.');
    }
    final prefix = creator ? '/creator-tasks' : '/task-participations';
    final response = obj(await LiveApi.upload(prefix + '/images', file, field: 'image'));
    final id = field(response, 'id');
    if (id.isEmpty) throw const LiveApiError('Upload finished without a media ID.');
    return id;
  }

  static Future<String> uploadVideo(File file, {required bool creator,
      void Function(int percent)? onProgress}) async {
    final path = file.path.toLowerCase();
    final mime = path.endsWith('.mp4') ? 'video/mp4' :
      path.endsWith('.webm') ? 'video/webm' :
      path.endsWith('.mov') ? 'video/quicktime' : null;
    if (mime == null) throw const LiveApiError('Select MP4, MOV or WebM video.');
    final bytes = await file.length();
    if (bytes <= 0) throw const LiveApiError('Selected video is empty.');
    final prefix = creator ? '/creator-tasks/uploads' : '/task-participations/videos';
    final filename = file.uri.pathSegments.isEmpty ? 'video.mp4' : file.uri.pathSegments.last;
    final started = obj(await LiveApi.call('POST', prefix, {
      'filename': filename, 'mimeType': mime, 'totalBytes': bytes,
    }));
    final id = field(started, 'uploadId');
    final chunkBytes = int.tryParse(field(started, 'chunkBytes')) ?? 8 * 1024 * 1024;
    final total = int.tryParse(field(started, 'totalChunks')) ?? 0;
    var next = int.tryParse(field(started, 'nextChunk', '0')) ?? 0;
    if (id.isEmpty || chunkBytes <= 0 || total < 1) {
      throw const LiveApiError('Video upload session unavailable.');
    }
    final token = await BlinkAuthApi.getToken();
    if (token == null || token.isEmpty) throw const LiveApiError('Please sign in again.');
    final reader = await file.open();
    try {
      while (next < total) {
        final index = next;
        await reader.setPosition(index * chunkBytes);
        final chunk = await reader.read(min(chunkBytes, bytes - index * chunkBytes));
        var done = false;
        Object? previous;
        for (var attempt = 0; attempt < 3 && !done; attempt++) {
          try {
            final request = http.MultipartRequest('POST',
              Uri.parse(LiveApi.root + prefix + '/' + Uri.encodeComponent(id) + '/chunks/$index'));
            request.headers['Authorization'] = 'Bearer $token';
            request.files.add(http.MultipartFile.fromBytes('chunk', chunk, filename: 'video-chunk'));
            final stream = await request.send().timeout(const Duration(minutes: 3));
            final response = await http.Response.fromStream(stream);
            dynamic data;
            try { data = jsonDecode(response.body); } catch (_) {}
            if (response.statusCode < 200 || response.statusCode >= 300) {
              throw LiveApiError('Video upload error (HTTP ' + response.statusCode.toString() + ')');
            }
            next = int.tryParse(field(data, 'nextChunk')) ?? (index + 1);
            done = true;
          } catch (e) {
            previous = e;
            try {
              final status = obj(await LiveApi.call('GET',
                prefix + '/' + Uri.encodeComponent(id)));
              final serverNext = int.tryParse(field(status, 'nextChunk')) ?? index;
              if (serverNext > index) {
                next = serverNext; done = true;
              }
            } catch (_) { /* Retry this exact chunk. */ }
          }
        }
        if (!done) throw LiveApiError('Video upload interrupted: $previous');
        onProgress?.call((next * 100 ~/ total).clamp(0, 100).toInt());
      }
      await LiveApi.call('POST', prefix + '/' + Uri.encodeComponent(id) + '/complete');
      return id;
    } catch (_) {
      try { await LiveApi.call('DELETE', prefix + '/' + Uri.encodeComponent(id)); } catch (_) {}
      rethrow;
    } finally {
      await reader.close();
    }
  }
}
