import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'blink_auth_api.dart';

/// All data comes from the authenticated Blink NestJS API.
class LiveApi {
  static String get root => BlinkAuthApi.baseUrl;
  static String url(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.isEmpty) return '';
    return '$root${value.startsWith('/') ? value : '/uploads/$value'}';
  }

  static Future<dynamic> call(String method, String path, [Map<String, dynamic>? data]) async {
    final token = await BlinkAuthApi.getToken();
    if (token == null || token.isEmpty) throw const LiveApiError('Please log in again.');
    final uri = Uri.parse('$root$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    try {
      final http.Response response;
      switch (method.toUpperCase()) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: jsonEncode(data ?? {})).timeout(const Duration(seconds: 30));
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: jsonEncode(data ?? {})).timeout(const Duration(seconds: 30));
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: jsonEncode(data ?? {})).timeout(const Duration(seconds: 30));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
          break;
        default:
          response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
      }
      dynamic decoded;
      try { decoded = response.body.isEmpty ? null : jsonDecode(response.body); }
      catch (_) { throw LiveApiError('Unexpected API response (HTTP ${response.statusCode}).'); }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map ? decoded['message'] : null;
        throw LiveApiError(error is List ? error.join(', ') : error?.toString() ?? 'Request failed (HTTP ${response.statusCode}).');
      }
      return decoded;
    } on SocketException {
      throw LiveApiError('Cannot connect to Blink server: $root');
    } on TimeoutException {
      throw const LiveApiError('Blink server timed out.');
    } on http.ClientException catch (error) {
      throw LiveApiError('Network error: ${error.message}');
    }
  }

  static Future<dynamic> upload(String path, File file, {String field = 'file', Map<String, String>? fields}) async {
    final token = await BlinkAuthApi.getToken();
    if (token == null || token.isEmpty) throw const LiveApiError('Please log in again.');
    final request = http.MultipartRequest('POST', Uri.parse('$root$path'));
    request.headers['Authorization'] = 'Bearer $token';
    if (fields != null) request.fields.addAll(fields);
    final extension = file.path.toLowerCase();
    final mime = extension.endsWith('.png') ? 'image/png' :
      extension.endsWith('.webp') ? 'image/webp' :
      extension.endsWith('.jpg') || extension.endsWith('.jpeg') ? 'image/jpeg' :
      extension.endsWith('.mp4') ? 'video/mp4' :
      extension.endsWith('.mov') ? 'video/quicktime' :
      extension.endsWith('.m4a') ? 'audio/mp4' :
      extension.endsWith('.aac') ? 'audio/aac' :
      extension.endsWith('.webm') ? 'video/webm' : 'application/octet-stream';
    request.files.add(await http.MultipartFile.fromPath(field, file.path,
      contentType: MediaType.parse(mime)));
    final stream = await request.send().timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(stream);
    dynamic data;
    try { data = jsonDecode(response.body); } catch (_) { data = null; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LiveApiError(data is Map ? data['message'].toString() : 'Upload failed: ${response.statusCode}');
    }
    return data;
  }
}

class LiveApiError implements Exception {
  const LiveApiError(this.message);
  final String message;
  @override String toString() => message;
}

Map<String, dynamic> obj(dynamic input) => input is Map ? Map<String, dynamic>.from(input) : <String, dynamic>{};
List<dynamic> arr(dynamic input) => input is List ? input : <dynamic>[];
String field(dynamic input, String key, [String fallback = '']) => obj(input)[key]?.toString() ?? fallback;

void liveNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Widget liveAvatar(dynamic user, {double radius = 23}) {
  final name = field(user, 'name', 'Blink');
  final key = field(user, 'avatarKey');
  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFFFE9DD),
    backgroundImage: key.isNotEmpty ? NetworkImage(LiveApi.url(key)) : null,
    child: key.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'B',
      style: const TextStyle(color: Color(0xFFE74B00), fontWeight: FontWeight.bold)) : null,
  );
}

Widget liveError(String? error, VoidCallback retry) => Center(
  child: Padding(
    padding: const EdgeInsets.all(22),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(error ?? 'Unable to load', textAlign: TextAlign.center),
      TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
    ]),
  ),
);
