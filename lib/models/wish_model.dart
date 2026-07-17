import 'package:cloud_firestore/cloud_firestore.dart';

class WishModel {
  final String id;
  final String coupleId;
  final String createdByUid;
  final String title;
  final String? memo;
  final bool done;
  final DateTime createdAt;

  const WishModel({
    required this.id,
    required this.coupleId,
    required this.createdByUid,
    required this.title,
    this.memo,
    this.done = false,
    required this.createdAt,
  });

  factory WishModel.fromMap(Map<String, dynamic> map) {
    return WishModel(
      id: map['id'] as String,
      coupleId: map['coupleId'] as String,
      createdByUid: map['createdByUid'] as String,
      title: map['title'] as String,
      memo: map['memo'] as String?,
      done: map['done'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'coupleId': coupleId,
      'createdByUid': createdByUid,
      'title': title,
      'memo': memo,
      'done': done,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  WishModel copyWith({String? title, String? memo, bool? done}) {
    return WishModel(
      id: id,
      coupleId: coupleId,
      createdByUid: createdByUid,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      done: done ?? this.done,
      createdAt: createdAt,
    );
  }
}

/// 미완료 먼저, 각 그룹 내 최신(createdAt desc)순
List<WishModel> sortWishes(List<WishModel> wishes) {
  final sorted = [...wishes];
  sorted.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}
