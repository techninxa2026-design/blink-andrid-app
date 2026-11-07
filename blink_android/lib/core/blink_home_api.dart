import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import 'blink_auth_api.dart';

class BlinkHomeError implements Exception {
  const BlinkHomeError(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}

class BlinkMoment {
  const BlinkMoment({
    required this.id,
    required this.senderId,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.author,
    this.avatarKey,
    this.caption,
    this.musicTrackId,
  });

  final String id;
  final String senderId;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final String author;
  final String? avatarKey;
  final String? caption;
  final String? musicTrackId;

  factory BlinkMoment.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    final user = sender is Map<String, dynamic> ? sender : <String, dynamic>{};
    return BlinkMoment(
      id: (json['id'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      mediaUrl: (json['mediaUrl'] ?? '').toString(),
      mediaType: (json['mediaType'] ?? 'photo').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal() ?? DateTime.now(),
      author: (user['name'] ?? 'Blink member').toString(),
      avatarKey: user['avatarKey']?.toString(),
      caption: json['caption']?.toString(),
      musicTrackId: json['musicTrackId']?.toString(),
    );
  }
}

/// One public Reel returned by GET /reels (including other users' uploads).
class BlinkReel {
  final String id;
  final String authorId;
  final String authorName;
  final String? avatarKey;
  final String videoUrl;
  final String thumbnailUrl;
  final String? caption;
  final int reactionCount;
  final int commentCount;
  final int views;
  final String? myReaction;

  const BlinkReel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.reactionCount,
    required this.commentCount,
    required this.views,
    this.avatarKey,
    this.caption,
    this.myReaction,
  });

  factory BlinkReel.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final user = author is Map ? author : <String, dynamic>{};
    int count(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return BlinkReel(
      id: (json['id'] ?? '').toString(),
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (user['name'] ?? 'Blink member').toString(),
      avatarKey: user['avatarKey']?.toString(),
      videoUrl: (json['videoUrl'] ?? '').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? '').toString(),
      caption: json['caption']?.toString(),
      reactionCount: count(json['reactionCount']),
      commentCount: count(json['commentCount']),
      views: count(json['views']),
      myReaction: json['myReaction']?.toString(),
    );
  }
}

/// Safety filter: public Reel recommendations contain every other author,
/// irrespective of friendship. The backend enforces the same rule.
List<BlinkReel> visibleReelsForViewer(List<BlinkReel> reels, String viewerId) {
  if (viewerId.isEmpty) return <BlinkReel>[];
  return reels.where((reel) =>
      reel.id.isNotEmpty &&
      reel.authorId.isNotEmpty &&
      reel.authorId != viewerId).toList();
}

class BlinkReelPage {
  final List<BlinkReel> items;
  final int? nextOffset;
  const BlinkReelPage(this.items, this.nextOffset);
}

class BlinkHomeApi {
  BlinkHomeApi._();

  /// A Moment in the public feed should also be accepted by the interaction
  /// endpoint. A legacy API may still apply the old 24-hour expiry to react
  /// and BP routes even though the public feed displays the Moment.
  /// Do not claim a gift or reaction succeeded when the server rejected it.
  static String momentActionError(Object error) {
    if (error is BlinkHomeError) {
      final message = error.message.toLowerCase();
      final isMomentUnavailable =
          message.contains('moment') &&
          (message.contains('expired') ||
           message.contains('unavailable') ||
           message.contains('not found') ||
           message.contains('not public'));
      if (isMomentUnavailable) {
        return 'The Blink API at ${BlinkAuthApi.baseUrl} rejected this '
            'Moment. Refresh the feed and check API connection settings '
            'to use the same working NestJS server as Blink web. '
            'If the error continues, update and restart the NestJS API; '
            'older builds may incorrectly reject public Moments as expired.';
      }
    }
    return error.toString();
  }

  static String get baseUrl => BlinkAuthApi.baseUrl;

  static String mediaUrl(String raw) {
    if (raw.startsWith('https://') || raw.startsWith('http://')) return raw;
    if (raw.isEmpty) return '';
    return '$baseUrl${raw.startsWith('/') ? raw : '/uploads/$raw'}';
  }

  static Future<String> _token() async {
    final token = await BlinkAuthApi.getToken();
    if (token == null || token.isEmpty) {
      throw const BlinkHomeError('Please sign in again.', status: 401);
    }
    return token;
  }

  static String _message(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
        if (message is List) return message.join('\n');
      }
    } catch (_) {}
    return 'Blink API error (${response.statusCode}).';
  }

  static Future<dynamic> request(String method, String path, {Map<String, dynamic>? data}) async {
    final token = await _token();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (data != null) 'Content-Type': 'application/json',
      };
      final http.Response response;
      if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: jsonEncode(data ?? {}))
            .timeout(const Duration(seconds: 25));
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 25));
      } else {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 25));
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BlinkHomeError(_message(response), status: response.statusCode);
      }
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } on FormatException {
        throw const BlinkHomeError('Invalid data returned by Blink API.');
      }
    } on BlinkHomeError {
      rethrow;
    } on TimeoutException {
      throw const BlinkHomeError('Blink server timed out. Check your connection.');
    } on SocketException {
      throw const BlinkHomeError('Cannot reach Blink server. Check Wi-Fi and API address.');
    } on http.ClientException {
      throw const BlinkHomeError('Network error contacting Blink server.');
    }
  }

  static Future<List<BlinkMoment>> moments({
    bool mine = false,
    int skip = 0,
    int take = 100,
  }) async {
    // GET /moments remains compatible with the existing web client, while
    // optional skip/take allow Flutter to load more than the first 100 posts.
    if (skip < 0 || take < 1 || take > 100) {
      throw const BlinkHomeError('Invalid Moments page.');
    }
    final data = await request('GET', mine
        ? '/moments/mine?skip=$skip&take=$take'
        : '/moments?skip=$skip&take=$take');
    if (data is! List) throw const BlinkHomeError('Unexpected Moments response.');
    // /moments/mine excludes sender objects. Fill author using cached current user.
    final self = mine ? (await BlinkAuthApi.cachedUser()) : null;
    return data.whereType<Map<String, dynamic>>().map((json) {
      if (!mine || json['sender'] != null) return BlinkMoment.fromJson(json);
      return BlinkMoment.fromJson({
        ...json,
        'sender': {
          'name': self?['name'] ?? 'You',
          'avatarKey': self?['avatarKey'],
        },
      });
    }).toList();
  }

  static Future<int> activeCheckinsCount() async {
    final data = await request('GET', '/checkins');
    if (data is! List) throw const BlinkHomeError('Unexpected Check-Ins response.');
    return data.length;
  }

  static Future<Map<String, dynamic>> activity(String momentId) async {
    final data = await request('GET', '/moments/${Uri.encodeComponent(momentId)}/activity');
    if (data is! Map<String, dynamic>) throw const BlinkHomeError('Unexpected Moment activity response.');
    return data;
  }

  static Future<void> react(String id, String emoji) async {
    await request('POST', '/moments/${Uri.encodeComponent(id)}/react', data: {'emoji': emoji});
  }

  static Future<void> comment(String id, String body, {String? parentId}) async {
    await request('POST', '/moments/${Uri.encodeComponent(id)}/comments', data: {
      'body': body.trim(),
      if (parentId != null) 'parentId': parentId,
    });
  }

  static Future<void> deleteMoment(String id) async {
    await request('DELETE', '/moments/${Uri.encodeComponent(id)}');
  }

  static Future<void> deleteComment(String id) async {
    await request('DELETE', '/moments/comments/${Uri.encodeComponent(id)}');
  }

  static Future<void> recordView(String id) async {
    await request('POST', '/moments/${Uri.encodeComponent(id)}/view');
  }

  /// Public Reel feed: all authors, not only the signed-in member.
  /// Backend returns 20 Reels per page and nextOffset for pagination.
  static Future<BlinkReelPage> reels({int skip = 0}) async {
    final response = await request('GET', '/reels?skip=$skip');
    if (response is! Map<String, dynamic> || response['items'] is! List) {
      throw const BlinkHomeError('Unexpected Reels feed response.');
    }
    final rows = (response['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map(BlinkReel.fromJson)
        .where((reel) => reel.id.isNotEmpty && reel.videoUrl.isNotEmpty)
        .toList();
    final offset = response['nextOffset'];
    return BlinkReelPage(rows, offset is num ? offset.toInt() : null);
  }

  static Future<List<BlinkReel>> myReels() async {
    final response = await request('GET', '/reels/mine');
    if (response is! List) throw const BlinkHomeError('Unexpected My Reels response.');
    return response.whereType<Map<String, dynamic>>()
        .map(BlinkReel.fromJson).toList();
  }

  static Future<void> recordReelView(String id) async {
    await request('POST', '/reels/${Uri.encodeComponent(id)}/view');
  }

  static Future<Map<String, dynamic>> reactReel(String id, String? emoji) async {
    final response = await request('POST', '/reels/${Uri.encodeComponent(id)}/react',
      data: {'emoji': emoji});
    if (response is! Map<String, dynamic>) {
      throw const BlinkHomeError('Unexpected Reel reaction response.');
    }
    return response;
  }

  static Future<List<Map<String, dynamic>>> reelComments(String id) async {
    final response = await request('GET', '/reels/${Uri.encodeComponent(id)}/comments');
    if (response is! List) throw const BlinkHomeError('Unexpected Reel comments response.');
    return response.whereType<Map<String, dynamic>>().toList();
  }

  static Future<void> commentReel(String id, String body, {String? parentId}) async {
    await request('POST', '/reels/${Uri.encodeComponent(id)}/comments', data: {
      'body': body.trim(),
      if (parentId != null) 'parentId': parentId,
    });
  }

  static Future<void> deleteReel(String id) async {
    await request('DELETE', '/reels/${Uri.encodeComponent(id)}');
  }

  static Future<Map<String, dynamic>> _upload(
    String path,
    List<http.MultipartFile> files, {
    required String caption,
    String? musicTrackId,
  }) async {
    final token = await _token();
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['caption'] = caption.trim();
    if (musicTrackId != null && musicTrackId.isNotEmpty) {
      req.fields['musicTrackId'] = musicTrackId;
    }
    req.files.addAll(files);
    try {
      final streamed = await req.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BlinkHomeError(_message(response), status: response.statusCode);
      }
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      throw const BlinkHomeError('Unexpected upload response.');
    } on BlinkHomeError {
      rethrow;
    } on TimeoutException {
      throw const BlinkHomeError('Upload timed out. Check network and file size.');
    } on SocketException {
      throw const BlinkHomeError('Upload failed: Blink server unavailable.');
    } on http.ClientException {
      throw const BlinkHomeError('Upload network error.');
    }
  }

  static Future<void> uploadMoment(File file, {required String caption, String? musicTrackId}) async {
    final bytes = await file.length();
    if (bytes <= 0 || bytes > 50 * 1024 * 1024) {
      throw const BlinkHomeError('Moments must be under 50 MB.');
    }
    final name = file.path.toLowerCase();
    final mime = name.endsWith('.png') ? 'image/png'
        : name.endsWith('.webp') ? 'image/webp'
        : name.endsWith('.gif') ? 'image/gif'
        : name.endsWith('.mp4') ? 'video/mp4'
        : name.endsWith('.webm') ? 'video/webm'
        : name.endsWith('.mov') ? 'video/quicktime'
        : name.endsWith('.jpg') || name.endsWith('.jpeg') ? 'image/jpeg' : null;
    if (mime == null) throw const BlinkHomeError('Select a JPG, PNG, WebP, MP4, WebM or MOV file.');
    final parts = mime.split('/');
    final multi = await http.MultipartFile.fromPath('file', file.path,
        contentType: MediaType(parts[0], parts[1]));
    await _upload('/moments/upload', [multi], caption: caption, musicTrackId: musicTrackId);
  }

  static Future<void> uploadReel(File video, Uint8List jpegThumbnail, {required String caption}) async {
    final bytes = await video.length();
    if (bytes <= 0 || bytes > 200 * 1024 * 1024) {
      throw const BlinkHomeError('Reels must be under 200 MB.');
    }
    if (jpegThumbnail.isEmpty || jpegThumbnail.length > 5 * 1024 * 1024) {
      throw const BlinkHomeError('Could not prepare a valid JPEG Reel cover.');
    }
    final lower = video.path.toLowerCase();
    final mime = lower.endsWith('.mp4') ? 'video/mp4'
        : lower.endsWith('.mov') ? 'video/quicktime'
        : lower.endsWith('.webm') ? 'video/webm' : null;
    if (mime == null) throw const BlinkHomeError('Reel video must be MP4, MOV or WebM.');
    final parts = mime.split('/');
    final file = await http.MultipartFile.fromPath('video', video.path,
        contentType: MediaType(parts[0], parts[1]));
    final cover = http.MultipartFile.fromBytes('thumbnail', jpegThumbnail,
        filename: 'cover.jpg', contentType: MediaType('image', 'jpeg'));
    await _upload('/reels/upload', [file, cover], caption: caption);
  }
}
