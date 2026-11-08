import 'package:blink_android/core/inbox_message_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final first = <String, dynamic>{
    'id': 'one', 'body': 'Hello', 'createdAt': '2026-01-01T10:00:00Z',
  };
  final second = <String, dynamic>{
    'id': 'two', 'body': 'How are you?', 'createdAt': '2026-01-01T10:00:01Z',
  };

  test('keeps an acknowledged message when a stale poll completes', () {
    final pending = <String, Map<String, dynamic>>{'two': second};
    final messages = reconcileInboxMessages([first], pending);
    expect(messages.map((m) => m['id']), ['one', 'two']);
    expect(pending.containsKey('two'), isTrue);
  });

  test('removes acknowledged copy once server snapshot includes it', () {
    final pending = <String, Map<String, dynamic>>{'two': second};
    final messages = reconcileInboxMessages([first, second], pending);
    expect(messages.map((m) => m['id']), ['one', 'two']);
    expect(pending, isEmpty);
  });

  test('orders messages by timestamp even when responses arrive out of order', () {
    final pending = <String, Map<String, dynamic>>{'one': first};
    final messages = reconcileInboxMessages([second], pending);
    expect(messages.map((m) => m['id']), ['one', 'two']);
  });

  test('does not invent or retain messages after confirmation', () {
    final pending = <String, Map<String, dynamic>>{'one': first};
    reconcileInboxMessages([first], pending);
    final messages = reconcileInboxMessages([], pending);
    expect(messages, isEmpty);
  });
}
