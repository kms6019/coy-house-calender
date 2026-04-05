import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  });

  Color get colorValue => Color(color);

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
    );
  }
}
