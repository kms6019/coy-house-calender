import 'package:coy_house_calender/models/event_model.dart';
import 'package:flutter/material.dart';

/// 기기 이벤트(제목/시작/종료/종일)를 앱 EventModel draft로 변환
EventModel deviceEventToDraft({
  required String title,
  required DateTime start,
  DateTime? end,
  required bool isAllDay,
  required String coupleId,
  required String myUid,
  required int color,
}) {
  final now = DateTime.now();

  return EventModel(
    id: '',
    coupleId: coupleId,
    createdByUid: myUid,
    title: title,
    description: null,
    startDateTime: start,
    endDateTime: end,
    isAllDay: isAllDay,
    color: color,
    hasAlarm: false,
    alarmMinutesBefore: 30,
    createdAt: now,
    updatedAt: now,
    repeat: RepeatRule.none,
    icon: null,
  );
}

/// 중복 판정: 기존 events에 제목(트림)·시작시각(분 단위)·종일 여부가 같은 이벤트가 있으면 true
bool isDuplicateEvent(
  List<EventModel> existing, {
  required String title,
  required DateTime start,
  required bool isAllDay,
}) {
  final normalizedTitle = title.trim();

  return existing.any((event) {
    if (event.title.trim() != normalizedTitle || event.isAllDay != isAllDay) {
      return false;
    }

    if (isAllDay) {
      return DateUtils.dateOnly(event.startDateTime) ==
          DateUtils.dateOnly(start);
    }

    return _dateTimeToMinute(event.startDateTime) == _dateTimeToMinute(start);
  });
}

DateTime _dateTimeToMinute(DateTime value) {
  if (value.isUtc) {
    return DateTime.utc(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
  }

  return DateTime(value.year, value.month, value.day, value.hour, value.minute);
}
