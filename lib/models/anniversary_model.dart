import 'package:cloud_firestore/cloud_firestore.dart';

enum AnniversaryType { countUp, annual }

class AnniversaryModel {
  final String id;
  final String title;
  final DateTime date;
  final AnniversaryType type;

  const AnniversaryModel({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
  });

  factory AnniversaryModel.fromMap(Map<String, dynamic> map) {
    return AnniversaryModel(
      id: map['id'] as String,
      title: map['title'] as String,
      date: (map['date'] as Timestamp).toDate(),
      type: map['type'] == 'annual' ? AnniversaryType.annual : AnniversaryType.countUp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': Timestamp.fromDate(date),
      'type': type == AnniversaryType.annual ? 'annual' : 'countUp',
    };
  }
}
