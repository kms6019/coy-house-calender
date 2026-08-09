import 'package:cloud_firestore/cloud_firestore.dart';

/// 실제로 OS에 예약된 일정 알람 1건. [alarmAt]이 지났으면 울린 것으로 본다.
class AlarmRecord {
  final String id;
  final String eventId;
  final String title;
  final DateTime occurrenceStart;
  final DateTime alarmAt;

  const AlarmRecord({
    required this.id,
    required this.eventId,
    required this.title,
    required this.occurrenceStart,
    required this.alarmAt,
  });

  static AlarmRecord? fromDoc(String id, Map<String, dynamic> map) {
    final alarmAt = (map['alarmAt'] as Timestamp?)?.toDate();
    final occurrenceStart = (map['occurrenceStart'] as Timestamp?)?.toDate();
    if (alarmAt == null || occurrenceStart == null) return null;
    return AlarmRecord(
      id: id,
      eventId: map['eventId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      occurrenceStart: occurrenceStart,
      alarmAt: alarmAt,
    );
  }
}

/// 같은 회차를 몇 번 재예약해도 문서가 늘지 않도록 결정적 문서 ID를 쓴다.
String alarmRecordId(String eventId, DateTime alarmAt) =>
    '${eventId}_${alarmAt.millisecondsSinceEpoch}';

/// 정리 대상 문서 ID. [entries]는 alarmAt 내림차순.
///
/// 지우는 것은 두 가지뿐이다.
/// 1. 아직 안 울렸는데([now] 이후) 더 이상 예약돼 있지 않은 것 — 일정 삭제/알람 해제/시간 변경
/// 2. 남길 개수 [maxEntries]를 넘긴 오래된 것
///
/// 이미 울린 기록은 원본 일정이 사라져도 남는다.
List<String> alarmRecordsToDelete(
  List<({String id, DateTime alarmAt})> entries,
  Set<String> keepIds,
  DateTime now, {
  int maxEntries = 100,
}) {
  final doomed = <String>[];
  var kept = 0;
  for (final entry in entries) {
    final isPending = entry.alarmAt.isAfter(now);
    if ((isPending && !keepIds.contains(entry.id)) || kept >= maxEntries) {
      doomed.add(entry.id);
      continue;
    }
    kept++;
  }
  return doomed;
}

/// 일정 알람 예약 기록. 알림이 실제로 뜰 때는 Dart 코드가 돌지 않으므로
/// "예약 시점에 기록 → 시각이 지나면 울린 것으로 확정"하는 방식으로 남긴다.
/// 원본 일정을 지우거나 고쳐도 기록은 그대로 남는다.
class AlarmHistoryService {
  static const _maxEntries = 100;

  final FirebaseFirestore _db;
  AlarmHistoryService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('alarmHistory');

  Future<void> recordScheduled(
    String uid, {
    required String eventId,
    required String title,
    required DateTime occurrenceStart,
    required DateTime alarmAt,
  }) async {
    await _collection(uid).doc(alarmRecordId(eventId, alarmAt)).set({
      'eventId': eventId,
      'title': title,
      'occurrenceStart': Timestamp.fromDate(occurrenceStart),
      'alarmAt': Timestamp.fromDate(alarmAt),
    }, SetOptions(merge: true));
  }

  /// 아직 안 울린 예약 중 [keepIds]에 없는 것을 지우고, 오래된 기록을 [_maxEntries]로 정리.
  ///
  /// 일정 삭제·알람 해제·시간 변경으로 예약이 사라진 경우를 한곳에서 반영한다.
  /// 이미 울린(=[now] 이전) 기록은 건드리지 않는다.
  Future<void> reconcile(String uid, Set<String> keepIds, DateTime now) async {
    final snap = await _collection(uid)
        .orderBy('alarmAt', descending: true)
        .get();

    final entries = <({String id, DateTime alarmAt})>[];
    for (final doc in snap.docs) {
      final alarmAt = (doc.data()['alarmAt'] as Timestamp?)?.toDate();
      if (alarmAt == null) continue;
      entries.add((id: doc.id, alarmAt: alarmAt));
    }

    final doomed = alarmRecordsToDelete(
      entries,
      keepIds,
      now,
      maxEntries: _maxEntries,
    ).toSet();
    if (doomed.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs.where((d) => doomed.contains(d.id))) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// 최신순 알람 기록. 아직 안 울린 예약분도 포함하므로 화면에서 걸러 쓴다.
  Stream<List<AlarmRecord>> stream(String uid) {
    return _collection(uid)
        .orderBy('alarmAt', descending: true)
        .limit(_maxEntries)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AlarmRecord.fromDoc(d.id, d.data()))
              .nonNulls
              .toList(),
        );
  }
}
