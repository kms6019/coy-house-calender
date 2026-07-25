# 지난 알람 목록 (Past Alarm List) 설계

작성일: 2026-07-25

## 문제

설정의 "알림 기록" 화면은 FCM `event_sync` 푸시, 즉 **파트너가 일정을 바꿨을 때 오는 알림**만
Firestore에 저장해 보여준다. 정작 사용자가 설정한 **일정 알람**과 **아침 브리핑**은
`flutter_local_notifications`로 기기에서만 울리고 어디에도 남지 않는다. 알림을 놓치면
무슨 알람이 울렸는지 되짚어볼 방법이 없다.

## 목표

지난 일정 알람을 최신순 목록으로 본다. 항목을 누르면 해당 일정 상세로 이동한다.

## 접근 방식 결정

**기록 방식(발화 시점에 저장)을 쓰지 않는다.** 안드로이드에서
`flutter_local_notifications`가 제공하는 콜백은 `onDidReceiveNotificationResponse`
하나뿐이고, 이건 사용자가 알림을 **탭했을 때만** 호출된다. 알림이 화면에 표시됐다는 신호는
받을 수 없다. 즉 놓친 알람 — 정확히 사용자가 되짚어보고 싶은 그 알람 — 이 기록되지 않는다.

**대신 이벤트 데이터에서 역산한다.** 알람 시각은 `회차 시작 시각 - alarmMinutesBefore`로
결정론적으로 계산된다. 저장이 필요 없고, 기능을 만들기 전에 울린 알람까지 소급해서 보이며,
새 Firestore 필드나 쓰기 비용이 없다.

감수하는 한계: 파생 뷰이므로 감사 로그가 아니다. 일정을 지우거나 알람을 끄면 그 일정의 지난
알람도 목록에서 사라진다. `alarmMinutesBefore`를 나중에 바꾸면 과거 항목도 새 간격으로
표시된다. 되짚어보기용 편의 기능에는 충분한 정확도다.

## 설계

### 1. 핵심 로직 — `lib/utils/alarm_history_utils.dart`

```dart
class PastAlarm {
  final EventModel event;
  final DateTime alarmAt;
}

/// [now] 기준 과거 [withinDays]일 이내에 울렸을 일정 알람. 최신순.
List<PastAlarm> pastAlarms(
  List<EventModel> events,
  DateTime now, {
  int withinDays = 30,
})
```

판정 규칙:

1. `hasAlarm`이 false인 이벤트는 제외한다.
2. 반복 이벤트는 `expandRecurringForRange`로 `[now - withinDays, now]` 범위를 전개해
   회차별로 계산한다. `excludedDates`와 `repeatUntil`은 이 함수가 이미 처리한다.
3. `alarmAt = occurrence.startDateTime - alarmMinutesBefore`.
4. `alarmAt`이 미래면 제외한다(아직 안 울림). `now`와 같은 순간은 포함한다.
5. `alarmAt`이 `now - withinDays`보다 이전이면 제외한다.
6. `alarmAt` 내림차순 정렬. 같으면 제목 오름차순으로 안정화한다.

`alarmMinutesBefore`가 커서 알람 시각이 과거이고 일정 시작은 미래인 경우도 포함된다.
이미 울린 알람이 맞기 때문이다.

아침 브리핑은 이번 범위에서 제외한다. 브리핑 내용은 그날의 일정 목록에서 생성되는데,
일정이 그 뒤 바뀌면 실제로 울린 문구를 복원할 수 없다. 잘못된 내용을 보여주느니 빼는 게 낫다.

### 2. UI — `lib/screens/settings/notification_history_screen.dart`

기존 화면에 탭 2개를 둔다. 알림 관련 기록이 한 화면에 모이는 게 찾기 쉽다.

- **일정 알람** (기본 탭): `pastAlarms` 결과. `제목` / `M/d HH:mm 알림 · 일정 M/d HH:mm`.
  탭하면 `/event/detail`로 이동한다.
- **파트너 알림**: 기존 Firestore 기록 목록 그대로.

두 탭 모두 비었을 때 안내 문구를 보여준다.

### 3. 데이터 흐름

이미 구독 중인 `eventsStreamProvider`를 읽어 계산한다. 새 컬렉션·필드·쓰기가 없다.

## 에러 처리

`pastAlarms`는 순수 함수이고 예외를 던지지 않는다. `eventsStreamProvider`가 로딩 중이면
기존 화면과 같이 로딩 표시를 낸다.

## 테스트

`test/utils/alarm_history_utils_test.dart`:

- `hasAlarm`이 false인 이벤트는 제외된다
- 알람 시각이 `시작 - alarmMinutesBefore`로 계산된다
- 미래 알람은 제외된다
- `withinDays`보다 오래된 알람은 제외된다
- 반복 이벤트의 지난 회차들이 각각 항목이 된다
- `excludedDates`에 걸린 회차는 제외된다
- `repeatUntil` 이후 회차는 제외된다
- 알람은 지났지만 일정 시작은 미래인 경우 포함된다
- 결과가 `alarmAt` 내림차순으로 정렬된다

## 수동 확인

1. 알람 켠 일정을 과거 시각으로 만들고 "알림 기록" → "일정 알람" 탭에 뜨는지 확인
2. 항목을 누르면 일정 상세로 이동하는지 확인
3. 알람을 끈 일정은 목록에 없는지 확인
4. "파트너 알림" 탭이 기존과 동일하게 동작하는지 확인
