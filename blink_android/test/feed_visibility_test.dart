import 'package:flutter_test/flutter_test.dart';
import 'package:blink_android/core/blink_home_api.dart';
import 'package:blink_android/screens/home.dart' show filterMomentsForViewer;

void main() {
  final createdAt = DateTime.utc(2026, 10, 30);

  BlinkMoment moment(String id, String owner, String type) => BlinkMoment(
    id: id,
    senderId: owner,
    mediaUrl: '/uploads/$id',
    mediaType: type,
    createdAt: createdAt,
    author: owner,
  );

  BlinkReel reel(String id, String owner) => BlinkReel(
    id: id,
    authorId: owner,
    authorName: owner,
    videoUrl: '/reels/media/$id/stream',
    thumbnailUrl: '/reels/media/$id/thumbnail',
    reactionCount: 0,
    commentCount: 0,
    views: 0,
  );

  test('A sees all public Moments from B, C, D, E, not A', () {
    final all = [
      ...List.generate(4, (n) => moment('a$n', 'A', n.isEven ? 'photo' : 'video')),
      ...List.generate(4, (n) => moment('b$n', 'B', n.isEven ? 'photo' : 'video')),
      ...List.generate(4, (n) => moment('c$n', 'C', n.isEven ? 'photo' : 'video')),
      moment('d0', 'D', 'video'),
      moment('e0', 'E', 'photo'),
    ];

    final public = filterMomentsForViewer(all, 'A', mine: false);
    expect(public, hasLength(10));
    expect(public.map((m) => m.senderId).toSet(), {'B', 'C', 'D', 'E'});
    expect(public.any((m) => m.mediaType == 'video'), isTrue);
    expect(public.any((m) => m.mediaType == 'photo'), isTrue);

    final mine = filterMomentsForViewer(all, 'A', mine: true);
    expect(mine.map((m) => m.id), ['a0', 'a1', 'a2', 'a3']);
  });

  test('B sees A, C, D, E and only B in My Moments', () {
    final all = [
      moment('a0', 'A', 'photo'),
      moment('b0', 'B', 'video'),
      moment('c0', 'C', 'photo'),
      moment('d0', 'D', 'video'),
      moment('e0', 'E', 'photo'),
    ];
    expect(filterMomentsForViewer(all, 'B', mine: false).map((m) => m.senderId),
      ['A', 'C', 'D', 'E']);
    expect(filterMomentsForViewer(all, 'B', mine: true).map((m) => m.id), ['b0']);
  });

  test('Reels feed shows all other authors, regardless of friendship', () {
    final reels = [
      reel('ar1', 'A'), reel('br1', 'B'), reel('cr1', 'C'),
      reel('dr1', 'D'), reel('br2', 'B'),
    ];
    final visible = visibleReelsForViewer(reels, 'A');
    expect(visible.map((r) => r.id), ['br1', 'cr1', 'dr1', 'br2']);
    expect(visibleReelsForViewer(reels, 'B').map((r) => r.id),
      ['ar1', 'cr1', 'dr1']);
  });

  test('No authenticated identity never exposes feed records', () {
    expect(filterMomentsForViewer([moment('b0', 'B', 'photo')], '', mine: false),
      isEmpty);
    expect(visibleReelsForViewer([reel('b1', 'B')], ''), isEmpty);
  });

  test('legacy Moment expired errors explain server deployment mismatch', () {
    final message = BlinkHomeApi.momentActionError(
      const BlinkHomeError('Moment is unavailable or expired.', status: 404));
    expect(message, contains('update and restart'));
    expect(message, contains('Refresh the feed'));
  });

  test('unrelated errors are not hidden by Moment recovery guidance', () {
    final message = BlinkHomeApi.momentActionError(
      const BlinkHomeError('Network connection interrupted', status: 503));
    expect(message, 'Network connection interrupted');
  });
}
