import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/wish_model.dart';

WishModel _wish(String id,
    {bool done = false, DateTime? createdAt, String? memo}) {
  return WishModel(
    id: id,
    coupleId: 'c1',
    createdByUid: 'u1',
    title: '위시 $id',
    memo: memo,
    done: done,
    createdAt: createdAt ?? DateTime(2026, 7, 1),
  );
}

void main() {
  test('직렬화 왕복 (memo null, done 기본 false)', () {
    final map = {
      'id': 'w1',
      'coupleId': 'c1',
      'createdByUid': 'u1',
      'title': '캠핑 가기',
      'memo': null,
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
    };
    final w = WishModel.fromMap(map);
    expect(w.title, '캠핑 가기');
    expect(w.memo, isNull);
    expect(w.done, isFalse);
    final out = w.toMap();
    expect(out['done'], false);
    expect((out['createdAt'] as Timestamp).toDate(), DateTime(2026, 7, 1));
  });

  test('copyWith done 토글', () {
    final w = _wish('w1');
    expect(w.copyWith(done: true).done, isTrue);
    expect(w.copyWith(done: true).id, 'w1');
  });

  test('sortWishes: 미완료 먼저, 그룹 내 최신순', () {
    final list = [
      _wish('old-done', done: true, createdAt: DateTime(2026, 7, 1)),
      _wish('new-open', createdAt: DateTime(2026, 7, 10)),
      _wish('new-done', done: true, createdAt: DateTime(2026, 7, 12)),
      _wish('old-open', createdAt: DateTime(2026, 7, 2)),
    ];
    final sorted = sortWishes(list);
    expect(sorted.map((w) => w.id).toList(),
        ['new-open', 'old-open', 'new-done', 'old-done']);
  });
}
