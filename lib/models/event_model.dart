import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum RepeatRule { none, daily, weekly, monthly, yearly }

class EventModel {
  final String id;
  final String coupleId;
  final String createdByUid;
  final String title;
  final String? description;
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

  const EventModel({
    required this.id,
    required this.coupleId,
    required this.createdByUid,
    required this.title,
    this.description,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'coupleId': coupleId,
      'createdByUid': createdByUid,
      'title': title,
      'description': description,
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
    };
  }

  EventModel copyWith({
    String? title,
    String? description,
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
    );
  }
}
