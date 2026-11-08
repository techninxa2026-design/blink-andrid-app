/// Reconciles an authoritative Inbox GET snapshot with POST acknowledgements
/// that might have arrived while that GET was still in flight.
///
/// Acknowledgements are keyed by the server message ID. Once a server GET
/// includes that ID, the temporary entry is discarded. This prevents a stale
/// refresh from hiding a just-sent message or showing duplicate copies.
List<dynamic> reconcileInboxMessages(
  List<dynamic> serverMessages,
  Map<String, Map<String, dynamic>> awaitingSnapshot,
) {
  String idOf(dynamic item) =>
      item is Map ? item['id']?.toString() ?? '' : '';
  String createdAtOf(dynamic item) =>
      item is Map ? item['createdAt']?.toString() ?? '' : '';

  final received = serverMessages.map(idOf).toSet();
  awaitingSnapshot.removeWhere((id, _) => received.contains(id));

  final merged = <dynamic>[...serverMessages, ...awaitingSnapshot.values];
  merged.sort((a, b) {
    final ordered = createdAtOf(a).compareTo(createdAtOf(b));
    return ordered != 0 ? ordered : idOf(a).compareTo(idOf(b));
  });
  return merged;
}
