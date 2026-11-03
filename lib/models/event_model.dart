import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'event_place.dart';

/// Firestore 에는 이름(name)으로 저장된다. 순서는 반복 선택 목록 순서.
enum RepeatRule { none, daily, weekly, biweekly, monthly, yearly }

class EventModel {
  final String id;
  final String coupleId;
  final String createdByUid;
  final String title;
  final String? description;
  final String? reviewText;
  final String? reviewPhotoUrl;
  final DateTime startDateTime;
  final DateTime? endDateTime;
  final bool isAllDay;
  final int color;
  final bool hasAlarm;
  final int alarmMinutesBefore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RepeatRule repeat;
  final DateTime? repeatUntil;
  final List<DateTime> excludedDates;
  final String? icon;
  final bool isShared;
  final String status;
  final EventPlace? place;

  const EventModel({
    required this.id,
    required this.coupleId,
    required this.createdByUid,
    required this.title,
    this.description,
    this.reviewText,
    this.reviewPhotoUrl,
    required this.startDateTime,
    this.endDateTime,
    required this.isAllDay,
    required this.color,
    required this.hasAlarm,
    required this.alarmMinutesBefore,
    required this.createdAt,
    required this.updatedAt,
    this.repeat = RepeatRule.none,
    this.repeatUntil,
    this.excludedDates = const [],
    this.icon,
    this.isShared = false,
    this.status = 'confirmed',
    this.place,
  });

  Color get colorValue => Color(color);
  bool get isProposed => status == 'proposed';

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] as String,
      coupleId: map['coupleId'] as String,
      createdByUid: map['createdByUid'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      reviewText: map['reviewText'] as String?,
      reviewPhotoUrl: map['reviewPhotoUrl'] as String?,
      startDateTime: (map['startDateTime'] as Timestamp).toDate(),
      endDateTime: map['endDateTime'] != null
          ? (map['endDateTime'] as Timestamp).toDate()
          : null,
      isAllDay: map['isAllDay'] as bool? ?? false,
      color: map['color'] as int? ?? Colors.blue.toARGB32(),
      hasAlarm: map['hasAlarm'] as bool? ?? false,
      alarmMinutesBefore: map['alarmMinutesBefore'] as int? ?? 30,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      repeat: RepeatRule.values.asNameMap()[map['repeat'] as String? ?? 'none'] ??
          RepeatRule.none,
      repeatUntil: map['repeatUntil'] != null
          ? (map['repeatUntil'] as Timestamp).toDate()
          : null,
      excludedDates: (map['excludedDates'] as List?)
              ?.whereType<Timestamp>()
              .map((t) => t.toDate())
              .toList() ??
          const [],
      icon: map['icon'] as String?,
      isShared: map['isShared'] as bool? ?? false,
      status: map['status'] as String? ?? 'confirmed',
      place: EventPlace.fromMap(map['place']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'coupleId': coupleId,
      'createdByUid': createdByUid,
      'title': title,
      'description': description,
      'reviewText': reviewText,
      'reviewPhotoUrl': reviewPhotoUrl,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': endDateTime != null ? Timestamp.fromDate(endDateTime!) : null,
      'isAllDay': isAllDay,
      'color': color,
      'hasAlarm': hasAlarm,
      'alarmMinutesBefore': alarmMinutesBefore,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'repeat': repeat.name,
      'repeatUntil':
          repeatUntil != null ? Timestamp.fromDate(repeatUntil!) : null,
      'excludedDates': excludedDates.map(Timestamp.fromDate).toList(),
      'icon': icon,
      'isShared': isShared,
      'status': status,
      'place': place?.toMap(),
    };
  }

  EventModel copyWith({
    String? title,
    String? description,
    String? reviewText,
    String? reviewPhotoUrl,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? isAllDay,
    int? color,
    bool? hasAlarm,
    int? alarmMinutesBefore,
    DateTime? updatedAt,
    bool? isShared,
    String? status,
  }) {
    return EventModel(
      id: id,
      coupleId: coupleId,
      createdByUid: createdByUid,
      title: title ?? this.title,
      description: description ?? this.description,
      reviewText: reviewText ?? this.reviewText,
      reviewPhotoUrl: reviewPhotoUrl ?? this.reviewPhotoUrl,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      alarmMinutesBefore: alarmMinutesBefore ?? this.alarmMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      repeat: repeat,
      repeatUntil: repeatUntil,
      excludedDates: excludedDates,
      icon: icon,
      isShared: isShared ?? this.isShared,
      status: status ?? this.status,
      place: place,
    );
  }

  /// icon을 null로 덮어쓸 수 있는 전용 copy (copyWith는 null 병합)
  EventModel copyWithIcon(String? icon) {
    return EventModel(
      id: id,
      coupleId: coupleId,
      createdByUid: createdByUid,
      title: title,
      description: description,
      reviewText: reviewText,
      reviewPhotoUrl: reviewPhotoUrl,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      isAllDay: isAllDay,
      color: color,
      hasAlarm: hasAlarm,
      alarmMinutesBefore: alarmMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt,
      repeat: repeat,
      repeatUntil: repeatUntil,
      excludedDates: excludedDates,
      icon: icon,
      isShared: isShared,
      status: status,
      place: place,
    );
  }

  /// place를 null로 덮어쓸 수 있는 전용 copy (copyWith는 null 병합)
  EventModel copyWithPlace(EventPlace? place) {
    return EventModel(
      id: id,
      coupleId: coupleId,
      createdByUid: createdByUid,
      title: title,
      description: description,
      reviewText: reviewText,
      reviewPhotoUrl: reviewPhotoUrl,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      isAllDay: isAllDay,
      color: color,
      hasAlarm: hasAlarm,
      alarmMinutesBefore: alarmMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt,
      repeat: repeat,
      repeatUntil: repeatUntil,
      excludedDates: excludedDates,
      icon: icon,
      isShared: isShared,
      status: status,
      place: place,
    );
  }

  /// 새 문서로 저장할 사본 — id 와 생성·수정 시각만 바꾸고 나머지는 전부 유지.
  EventModel asNew({required String id, required DateTime now}) {
    return EventModel(
      id: id,
      coupleId: coupleId,
      createdByUid: createdByUid,
      title: title,
      description: description,
      reviewText: reviewText,
      reviewPhotoUrl: reviewPhotoUrl,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      isAllDay: isAllDay,
      color: color,
      hasAlarm: hasAlarm,
      alarmMinutesBefore: alarmMinutesBefore,
      createdAt: now,
      updatedAt: now,
      repeat: repeat,
      repeatUntil: repeatUntil,
      excludedDates: excludedDates,
      icon: icon,
      isShared: isShared,
      status: status,
      place: place,
    );
  }

  /// repeatUntil을 null로 덮어쓸 수 있는 반복 전용 copy (copyWith는 null 병합이라 해제 불가)
  EventModel copyWithRepeat({
    required RepeatRule repeat,
    required DateTime? repeatUntil,
    List<DateTime>? excludedDates,
  }) {
    return EventModel(
      id: id,
      coupleId: coupleId,
      createdByUid: createdByUid,
      title: title,
      description: description,
      reviewText: reviewText,
      reviewPhotoUrl: reviewPhotoUrl,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      isAllDay: isAllDay,
      color: color,
      hasAlarm: hasAlarm,
      alarmMinutesBefore: alarmMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt,
      repeat: repeat,
      repeatUntil: repeatUntil,
      excludedDates: excludedDates ?? this.excludedDates,
      icon: icon,
      isShared: isShared,
      status: status,
      place: place,
    );
  }
}
