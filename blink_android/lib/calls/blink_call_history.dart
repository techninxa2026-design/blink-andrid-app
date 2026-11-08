import 'dart:convert';

/// Immutable, server-written call events inside Blink's existing Inbox.
class BlinkCallHistory {
  const BlinkCallHistory({
    required this.callId,
    required this.kind,
    required this.outcome,
    required this.durationSeconds,
  });

  final String callId;
  final String kind;
  final String outcome;
  final int durationSeconds;

  bool get isVideo => kind == 'video';

  static BlinkCallHistory? parse(dynamic message) {
    if (message is! Map || message['mediaType'] != 'call') return null;
    final body = message['body'];
    if (body is! String) return null;
    try {
      final data = jsonDecode(body);
      if (data is! Map) return null;
      if (data['version'] != 1 ||
          data['callId'] is! String ||
          !['audio', 'video'].contains(data['kind']) ||
          !['missed', 'declined', 'cancelled', 'completed', 'dropped']
              .contains(data['outcome'])) return null;
      final duration = data['durationSeconds'];
      if (duration is! num || duration < 0 || !duration.isFinite) return null;
      return BlinkCallHistory(
        callId: data['callId'] as String,
        kind: data['kind'] as String,
        outcome: data['outcome'] as String,
        durationSeconds: duration.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  String label({required bool isCaller}) {
    final type = isVideo ? 'video' : 'voice';
    switch (outcome) {
      case 'missed':
        return isCaller ? 'No answer · ${_capital(type)} call'
            : 'Missed $type call';
      case 'declined':
        return isCaller ? '${_capital(type)} call declined'
            : 'Declined $type call';
      case 'cancelled':
        return isCaller ? 'Cancelled $type call' : 'Missed $type call';
      case 'dropped':
        return '${_capital(type)} call disconnected';
      case 'completed':
        final elapsed = durationSeconds < 60
            ? '${durationSeconds}s'
            : '${durationSeconds ~/ 60}m ${durationSeconds % 60}s';
        return '${_capital(type)} call · $elapsed';
      default:
        return '${_capital(type)} call';
    }
  }

  String _capital(String name) =>
      name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';
}
