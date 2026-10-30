
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class BlinkAuthException implements Exception {
  final String message;
  final int? statusCode;

  const BlinkAuthException(
      this.message, {
        this.statusCode,
      });

  @override
  String toString() => message;
}

class _ApiResult {
  final int status;
  final Map<String, dynamic> body;

  const _ApiResult(this.status, this.body);
}

class BlinkAuthApi {
  BlinkAuthApi._();

  // Standard Android emulator default.
  // Override for a physical phone using --dart-define.
  static const String _url = String.fromEnvironment(
    'BLINK_API_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  static String get baseUrl =>
      _url.replaceFirst(RegExp(r'/$'), '');

  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'blink_access_token';
  static const _userKey = 'blink_user';

  static const _timeout = Duration(seconds: 20);

  static String _errorMessage(
      Map<String, dynamic> body,
      int status,
      String path,
      ) {
    // Do not reveal whether an email exists.
    if (path == '/auth/login' && status == 401) {
      return 'Invalid email or password.';
    }

    final message = body['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    if (message is List && message.isNotEmpty) {
      return message.map((e) => e.toString()).join('\n');
    }

    if (status == 400) {
      return 'Please check your information.';
    }
    if (status == 401) {
      return 'Your login session has expired.';
    }
    if (status == 409) {
      return 'Email or phone number already registered.';
    }
    if (status == 404) {
      return 'Blink API endpoint was not found.';
    }
    if (status >= 500) {
      return 'Blink server error. Please try again.';
    }

    return 'Request failed (HTTP $status).';
  }

  static Future<_ApiResult> _request(
      String method,
      String path, {
        Map<String, dynamic>? data,
        String? token,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      final headers = <String, String>{
        'Accept': 'application/json',
        if (data != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      late http.Response response;

      if (method == 'POST') {
        response = await http
            .post(
          uri,
          headers: headers,
          body: jsonEncode(data ?? {}),
        )
            .timeout(_timeout);
      } else {
        response = await http
            .get(uri, headers: headers)
            .timeout(_timeout);
      }

      Map<String, dynamic> body = {};

      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);

          if (decoded is Map<String, dynamic>) {
            body = decoded;
          } else {
            throw const FormatException();
          }
        } on FormatException {
          throw BlinkAuthException(
            'Invalid response from Blink server '
                '(HTTP ${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw BlinkAuthException(
          _errorMessage(
            body,
            response.statusCode,
            path,
          ),
          statusCode: response.statusCode,
        );
      }

      return _ApiResult(response.statusCode, body);
    } on BlinkAuthException {
      rethrow;
    } on TimeoutException {
      throw const BlinkAuthException(
        'Connection timed out. Check Blink server.',
      );
    } on SocketException {
      throw BlinkAuthException(
        'Cannot reach Blink API at $baseUrl. '
            'Check the server and network.',
      );
    } on HandshakeException {
      throw const BlinkAuthException(
        'Secure connection failed.',
      );
    } on http.ClientException {
      throw const BlinkAuthException(
        'Network error. Please check your connection.',
      );
    }
  }

  // -------------------------------------------------
  // REGISTER
  // POST /auth/register
  // Creates the real account in NestJS + MySQL.
  // -------------------------------------------------

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final result = await _request(
      'POST',
      '/auth/register',
      data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'phoneNumber': phoneNumber.trim(),
        'password': password,
      },
    );

    final user = result.body['user'];

    if (user is! Map<String, dynamic> ||
        user['id'] is! String) {
      throw const BlinkAuthException(
        'Registration returned an invalid user record.',
      );
    }

    return user;
  }

  // -------------------------------------------------
  // LOGIN
  // POST /auth/login
  //
  // Unknown email -> 401 -> exception.
  // Wrong password -> 401 -> exception.
  // Success -> JWT + user saved securely.
  // -------------------------------------------------

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await _request(
      'POST',
      '/auth/login',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final token = result.body['accessToken'];
    final user = result.body['user'];

    if (token is! String || token.isEmpty) {
      throw const BlinkAuthException(
        'Login failed: missing authentication token.',
      );
    }

    if (user is! Map<String, dynamic> ||
        user['id'] is! String ||
        user['email'] is! String) {
      throw const BlinkAuthException(
        'Login failed: invalid user information.',
      );
    }

    try {
      await _storage.write(
        key: _tokenKey,
        value: token,
      );

      await _storage.write(
        key: _userKey,
        value: jsonEncode(user),
      );
    } catch (_) {
      // Never leave a partially stored session.
      await logout();
      throw const BlinkAuthException(
        'Unable to save login securely on this device.',
      );
    }

    return user;
  }

  // -------------------------------------------------
  // REAL SESSION VALIDATION
  // GET /profile/me
  //
  // A stored JWT alone does not grant access.
  // The NestJS backend verifies the token.
  // -------------------------------------------------

  static Future<Map<String, dynamic>?> currentUser() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final result = await _request(
        'GET',
        '/profile/me',
        token: token,
      );

      final user = result.body;

      if (user['id'] is! String ||
          user['email'] is! String) {
        throw const BlinkAuthException(
          'Invalid authenticated profile response.',
        );
      }

      await _storage.write(
        key: _userKey,
        value: jsonEncode(user),
      );

      return user;
    } on BlinkAuthException catch (error) {
      if (error.statusCode == 401) {
        // JWT expired, invalid or signed with an old secret.
        await logout();
        return null;
      }

      // Server offline is NOT the same as invalid login.
      // Let the route guard display a retry screen.
      rethrow;
    }
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw const BlinkAuthException(
        'Please sign in to continue.',
      );
    }

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  static Future<Map<String, dynamic>?> cachedUser() async {
    final value = await _storage.read(key: _userKey);

    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final data = jsonDecode(value);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  // -------------------------------------------------
  // LOGOUT
  // -------------------------------------------------

  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
