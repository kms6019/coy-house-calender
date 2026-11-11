import 'package:cloud_firestore/cloud_firestore.dart';

enum AnniversaryType { countUp, annual }

class AnniversaryModel {
  final String id;
  final String title;
  final DateTime date;
  final AnniversaryType type;

  /// 매년 반복을 음력으로 셀 때. [lunarMonth]/[lunarDay] 가 기준이고, [date] 는
  /// 저장 시점의 다음 양력 도래일(음력을 모르는 옛 앱도 올해는 맞게 보이도록).
  final bool isLunar;
  final int? lunarMonth;
  final int? lunarDay;

  /// 음력 날짜의 원래 해 (태어난 해 등). 표시용 — 매년 도래일은 월·일로만 센다.
  /// 이 필드가 생기기 전에 저장한 음력 기념일은 null.
  final int? lunarYear;

  /// 누구의 기념일인지 (생일 등). null 이면 둘의 기념일.
  final String? ownerUid;

  const AnniversaryModel({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.isLunar = false,
    this.lunarMonth,
    this.lunarDay,
    this.lunarYear,
    this.ownerUid,
  });

  factory AnniversaryModel.fromMap(Map<String, dynamic> map) {
    return AnniversaryModel(
      id: map['id'] as String,
      title: map['title'] as String,
      date: (map['date'] as Timestamp).toDate(),
      type: map['type'] == 'annual' ? AnniversaryType.annual : AnniversaryType.countUp,
      isLunar: map['isLunar'] as bool? ?? false,
      lunarMonth: (map['lunarMonth'] as num?)?.toInt(),
      lunarDay: (map['lunarDay'] as num?)?.toInt(),
      lunarYear: (map['lunarYear'] as num?)?.toInt(),
      ownerUid: map['ownerUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': Timestamp.fromDate(date),
      'type': type == AnniversaryType.annual ? 'annual' : 'countUp',
      if (isLunar) ...{
        'isLunar': true,
        'lunarMonth': lunarMonth,
        'lunarDay': lunarDay,
        if (lunarYear != null) 'lunarYear': lunarYear,
      },
      if (ownerUid != null) 'ownerUid': ownerUid,
    };
  }
}
