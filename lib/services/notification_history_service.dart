import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationHistoryEntry {
  final String? id;
  final String title;
  final String body;
  final String eventId;
  final DateTime? receivedAt;

  const NotificationHistoryEntry({
    this.id,
    required this.title,
    required this.body,
    required this.eventId,
    this.receivedAt,
  });

  /// FCM data 페이로드(문자열 맵)에서 알림기록 항목을 만든다.
  /// event_sync 타입이 아니거나 eventId가 없으면 기록하지 않는다(null).
  static NotificationHistoryEntry? fromFcmData(Map<String, dynamic> data) {
    if (data['type'] != 'event_sync') return null;
    final eventId = data['eventId'] as String? ?? '';
    if (eventId.isEmpty) return null;
    return NotificationHistoryEntry(
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      eventId: eventId,
    );
  }

  factory NotificationHistoryEntry.fromDoc(String id, Map<String, dynamic> map) {
    return NotificationHistoryEntry(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      eventId: map['eventId'] as String? ?? '',
      receivedAt: (map['receivedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'eventId': eventId,
      'receivedAt': FieldValue.serverTimestamp(),
    };
  }
}

class NotificationHistoryService {
  static const _maxEntries = 50;

  final FirebaseFirestore _db;
  NotificationHistoryService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('notificationHistory');

  Future<void> record(String uid, NotificationHistoryEntry entry) async {
    await _collection(uid).add(entry.toMap());

    final overflow = await _collection(uid)
        .orderBy('receivedAt', descending: true)
        .get();
    if (overflow.docs.length <= _maxEntries) return;
    final batch = _db.batch();
    for (final doc in overflow.docs.skip(_maxEntries)) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<List<NotificationHistoryEntry>> streamFor(String uid) {
    return _collection(uid)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationHistoryEntry.fromDoc(d.id, d.data()))
            .toList());
  }
}
