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

  factory NotificationHistoryEntry.fromDoc(String id, Map<String, dynamic> map) {
    return NotificationHistoryEntry(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      eventId: map['eventId'] as String? ?? '',
      receivedAt: (map['receivedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 파트너 알림 기록 — Cloud Function(sendToPartner)이 쓰고 앱은 읽기만 한다.
class NotificationHistoryService {
  final FirebaseFirestore _db;
  NotificationHistoryService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('notificationHistory');

  Stream<List<NotificationHistoryEntry>> streamFor(String uid) {
    return _collection(uid)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationHistoryEntry.fromDoc(d.id, d.data()))
            .toList());
  }
}
