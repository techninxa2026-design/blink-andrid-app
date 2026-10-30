import 'package:flutter_test/flutter_test.dart';
import 'package:blink_android/core/live_api.dart';

void main() {
  group('Blink API data handling', () {
    test('parses user and feed map payloads safely', () {
      final user = obj({'id': 'u1', 'name': 'Blink user'});
      expect(field(user, 'name'), 'Blink user');
      expect(field(user, 'id'), 'u1');
      expect(field(user, 'avatarKey'), '');
      expect(field(null, 'name', 'Anonymous'), 'Anonymous');
    });

    test('returns an empty object or collection for invalid payloads', () {
      expect(obj(null), isEmpty);
      expect(obj('not a map'), isEmpty);
      expect(arr(null), isEmpty);
      expect(arr({'items': []}), isEmpty);
    });

    test('keeps the order of backend list payloads', () {
      final friends = arr([
        {'id': 'f1', 'name': 'One'},
        {'id': 'f2', 'name': 'Two'}
      ]);
      expect(friends.length, 2);
      expect(field(friends.first, 'id'), 'f1');
      expect(field(friends.last, 'id'), 'f2');
    });
  });
}
