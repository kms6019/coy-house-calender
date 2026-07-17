import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'anniversary_model.dart';

class CoupleModel {
  final String coupleId;
  final String ownerUid;
  final String partnerUid;
  final String inviteCode;
  final bool isLinked;
  final int ownerColor;
  final int partnerColor;
  final DateTime createdAt;
  final List<AnniversaryModel> anniversaries;

  const CoupleModel({
    required this.coupleId,
    required this.ownerUid,
    required this.partnerUid,
    required this.inviteCode,
    required this.isLinked,
    required this.ownerColor,
    required this.partnerColor,
    required this.createdAt,
    this.anniversaries = const [],
  });

  Color get ownerColorValue => Color(ownerColor);
  Color get partnerColorValue => Color(partnerColor);

  factory CoupleModel.fromMap(Map<String, dynamic> map) {
    return CoupleModel(
      coupleId: map['coupleId'] as String,
      ownerUid: map['ownerUid'] as String,
      partnerUid: map['partnerUid'] as String? ?? '',
      inviteCode: map['inviteCode'] as String,
      isLinked: map['isLinked'] as bool? ?? false,
      ownerColor: map['ownerColor'] as int? ?? Colors.blue.toARGB32(),
      partnerColor: map['partnerColor'] as int? ?? Colors.pink.toARGB32(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      anniversaries: _parseAnniversaries(map['anniversaries']),
    );
  }

  static List<AnniversaryModel> _parseAnniversaries(dynamic raw) {
    if (raw is! List) return const [];
    final result = <AnniversaryModel>[];
    for (final item in raw) {
      try {
        result.add(AnniversaryModel.fromMap(Map<String, dynamic>.from(item as Map)));
      } catch (_) {
        // 불량 항목 개별 스킵
      }
    }
    return result;
  }

  Map<String, dynamic> toMap() {
    return {
      'coupleId': coupleId,
      'ownerUid': ownerUid,
      'partnerUid': partnerUid,
      'inviteCode': inviteCode,
      'isLinked': isLinked,
      'ownerColor': ownerColor,
      'partnerColor': partnerColor,
      'createdAt': Timestamp.fromDate(createdAt),
      'anniversaries': anniversaries.map((a) => a.toMap()).toList(),
    };
  }

  CoupleModel copyWith({
    String? partnerUid,
    bool? isLinked,
    int? ownerColor,
    int? partnerColor,
    List<AnniversaryModel>? anniversaries,
  }) {
    return CoupleModel(
      coupleId: coupleId,
      ownerUid: ownerUid,
      partnerUid: partnerUid ?? this.partnerUid,
      inviteCode: inviteCode,
      isLinked: isLinked ?? this.isLinked,
      ownerColor: ownerColor ?? this.ownerColor,
      partnerColor: partnerColor ?? this.partnerColor,
      createdAt: createdAt,
      anniversaries: anniversaries ?? this.anniversaries,
    );
  }
}
