import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/couple_model.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ── Couple ──────────────────────────────────────────────

  Future<CoupleModel> createCouple(String ownerUid) async {
    final coupleId = _uuid.v4();
    final inviteCode = coupleId.replaceAll('-', '').substring(0, 6).toUpperCase();
    final now = DateTime.now();
    final couple = CoupleModel(
      coupleId: coupleId,
      ownerUid: ownerUid,
      partnerUid: '',
      inviteCode: inviteCode,
      isLinked: false,
      ownerColor: 0xFF42A5F5,   // blue[400]
      partnerColor: 0xFFF48FB1, // pink[200]
      createdAt: now,
    );
    await _db.collection('couples').doc(coupleId).set(couple.toMap());
    await _db.collection('users').doc(ownerUid).set({'coupleId': coupleId}, SetOptions(merge: true));
    return couple;
  }

  Future<CoupleModel?> joinByInviteCode(String code, String partnerUid) async {
    final query = await _db
        .collection('couples')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .where('isLinked', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final couple = CoupleModel.fromMap(doc.data());

    if (couple.ownerUid == partnerUid) return null; // 자기 자신 입력 방지

    await _db.runTransaction((tx) async {
      tx.update(doc.reference, {
        'partnerUid': partnerUid,
        'isLinked': true,
      });
      tx.set(_db.collection('users').doc(partnerUid), {
        'coupleId': couple.coupleId,
      }, SetOptions(merge: true));
    });

    return couple.copyWith(partnerUid: partnerUid, isLinked: true);
  }

  Stream<CoupleModel?> coupleStream(String coupleId) {
    return _db
        .collection('couples')
        .doc(coupleId)
        .snapshots()
        .map((doc) => doc.exists ? CoupleModel.fromMap(doc.data()!) : null);
  }

  Stream<UserModel?> userStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          try {
            return UserModel.fromMap(doc.data()!);
          } catch (_) {
            // 문서가 불완전한 경우 coupleId만 읽어서 최소 모델 반환
            final data = doc.data()!;
            return UserModel(
              uid: uid,
              email: data['email'] as String? ?? '',
              displayName: data['displayName'] as String? ?? '',
              coupleId: data['coupleId'] as String? ?? '',
              fcmToken: '',
              createdAt: DateTime.now(),
            );
          }
        });
  }

  // ── Events ──────────────────────────────────────────────

  Stream<List<EventModel>> eventsStream(String coupleId) {
    return _db
        .collection('events')
        .where('coupleId', isEqualTo: coupleId)
        .orderBy('startDateTime')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => EventModel.fromMap(doc.data()))
            .toList());
  }

  Future<EventModel> addEvent(EventModel event) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final newEvent = EventModel(
      id: id,
      coupleId: event.coupleId,
      createdByUid: event.createdByUid,
      title: event.title,
      description: event.description,
      startDateTime: event.startDateTime,
      endDateTime: event.endDateTime,
      isAllDay: event.isAllDay,
      color: event.color,
      hasAlarm: event.hasAlarm,
      alarmMinutesBefore: event.alarmMinutesBefore,
      createdAt: now,
      updatedAt: now,
    );
    await _db.collection('events').doc(id).set(newEvent.toMap());
    return newEvent;
  }

  Future<void> updateEvent(EventModel event) {
    return _db.collection('events').doc(event.id).update(
      event.copyWith(updatedAt: DateTime.now()).toMap(),
    );
  }

  Future<void> deleteEvent(String eventId) {
    return _db.collection('events').doc(eventId).delete();
  }
}
