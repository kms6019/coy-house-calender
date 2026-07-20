import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String coupleId;
  final String fcmToken;
  final DateTime createdAt;
  final bool showKoreanHolidays;
  final bool briefingEnabled;
  final int briefingHour;
  final int briefingMinute;
  final String themeMode;
  final int? themeSeedColor;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.coupleId,
    required this.fcmToken,
    required this.createdAt,
    this.showKoreanHolidays = true,
    this.briefingEnabled = false,
    this.briefingHour = 8,
    this.briefingMinute = 0,
    this.themeMode = 'system',
    this.themeSeedColor,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      coupleId: map['coupleId'] as String? ?? '',
      fcmToken: map['fcmToken'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      showKoreanHolidays: map['showKoreanHolidays'] as bool? ?? true,
      briefingEnabled: map['briefingEnabled'] as bool? ?? false,
      briefingHour: map['briefingHour'] as int? ?? 8,
      briefingMinute: map['briefingMinute'] as int? ?? 0,
      themeMode: map['themeMode'] as String? ?? 'system',
      themeSeedColor: map['themeSeedColor'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'coupleId': coupleId,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'showKoreanHolidays': showKoreanHolidays,
      'briefingEnabled': briefingEnabled,
      'briefingHour': briefingHour,
      'briefingMinute': briefingMinute,
      'themeMode': themeMode,
      'themeSeedColor': themeSeedColor,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? coupleId,
    String? fcmToken,
    DateTime? createdAt,
    bool? showKoreanHolidays,
    bool? briefingEnabled,
    int? briefingHour,
    int? briefingMinute,
    String? themeMode,
    int? themeSeedColor,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      coupleId: coupleId ?? this.coupleId,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      showKoreanHolidays: showKoreanHolidays ?? this.showKoreanHolidays,
      briefingEnabled: briefingEnabled ?? this.briefingEnabled,
      briefingHour: briefingHour ?? this.briefingHour,
      briefingMinute: briefingMinute ?? this.briefingMinute,
      themeMode: themeMode ?? this.themeMode,
      themeSeedColor: themeSeedColor ?? this.themeSeedColor,
    );
  }
}
