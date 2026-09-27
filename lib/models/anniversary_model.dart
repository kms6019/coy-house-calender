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

  const AnniversaryModel({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.isLunar = false,
    this.lunarMonth,
    this.lunarDay,
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
      },
    };
  }
}
