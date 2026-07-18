# 대한민국 공휴일 표시 설계

2026-07-19. 커플 일정과 독립된 읽기 전용 오버레이로 대한민국 공휴일을 월간 달력과 홈 위젯에 표시한다.

## 범위

- 대한민국 공휴일 캘린더의 `DESCRIPTION:공휴일` 항목만 표시한다.
- 법정공휴일, 대체공휴일, 선거일, 임시공휴일을 포함한다.
- 기념일(`DESCRIPTION:기념일`)은 제외한다.
- 공휴일은 `EventModel`/Firestore에 저장하지 않는다. 따라서 파트너 푸시, 검색, 월간 리포트, 알림, 삼성캘린더 미러 대상이 아니다.
- 설정의 `대한민국 공휴일 표시` 스위치는 기본 ON이다.

## 데이터 소스와 캐시

- 즉시 동작하는 데이터 소스는 Google 공개 대한민국 공휴일 iCalendar 피드다.
  - `https://calendar.google.com/calendar/ical/ko.south_korea%23holiday%40group.v.calendar.google.com/public/basic.ics`
  - VEVENT 중 `DESCRIPTION` 첫 줄이 `공휴일`인 항목만 사용한다.
- 한국천문연구원 특일 정보 API가 최종 권장 소스지만 현재 Firebase Secret `KASI_SERVICE_KEY`가 없으므로 이번 구현의 런타임 의존성으로 삼지 않는다.
- `KoreanHolidayService` 경계 안에 원격 조회를 격리해 이후 공식 API 프록시로 교체할 수 있게 한다.
- 연도별 결과와 조회 시각을 SharedPreferences에 저장한다.
- 캐시가 7일 이내면 네트워크를 호출하지 않는다. 갱신 실패 시 만료된 캐시도 그대로 사용한다.
- 캐시도 없고 네트워크도 실패하면 빈 목록으로 조용히 대체해 기존 일정 사용을 막지 않는다.

## 모델과 상태

- `KoreanHoliday(date, name)` — 날짜는 로컬 자정으로 정규화한다.
- `HolidayPrefs` — 표시 여부 저장/조회.
- `koreanHolidayServiceProvider` — 서비스 singleton.
- `holidayDisplayEnabledProvider` — 설정값 비동기 provider.
- `koreanHolidaysProvider(year)` — 표시 ON일 때 해당 연도 공휴일을 조회한다.

## 앱 UI

- 월간 셀
  - 공휴일 날짜 숫자를 빨간색으로 표시한다.
  - 날짜 아래 공휴일 이름을 빨간색 한 줄로 표시한다.
  - 오늘이 공휴일이면 기존 보라색 오늘 원형과 흰 날짜 숫자를 우선하고, 공휴일 이름은 빨간색으로 유지한다.
- 날짜 상세 bottom sheet
  - 날짜 제목 아래에 빨간 깃발 아이콘과 공휴일 이름을 표시한다.
  - 일반 일정이 없어도 공휴일 정보는 표시한다.
- 원격 조회 실패는 달력 전체 오류 화면으로 승격하지 않는다.

## 홈 위젯

- `WidgetService.update()`가 설정값과 현재 연도 공휴일을 자체 조회해 백그라운드 FCM 경로에서도 동일하게 동작한다.
- 월간 셀 JSON에 `holiday`와 `h`(공휴일 이름)를 추가한다.
- Kotlin RemoteViews는 날짜와 공휴일 이름을 빨간색 span으로, 이벤트 제목은 기존 핑크색 span으로 렌더링한다.
- 오늘 셀은 기존 보라색 배경/흰색 텍스트를 우선한다.
- 리스트 위젯의 오늘 날짜 라벨에도 공휴일 이름을 덧붙인다.

## 테스트

- ICS 파서: 공휴일 포함, 기념일 제외, 줄 접기(unfold), escaped text, 날짜/이름 정규화.
- 캐시 직렬화 모델 round-trip.
- 월간 위젯 셀: 공휴일 플래그/이름, 이웃 달 공백, 기존 이벤트/오늘 동작 회귀.
- 달력 위젯 테스트: 공휴일 이름 렌더링.
- 전체 `flutter analyze`, `flutter test`, release APK 빌드.

## 배포

- 이번 구현은 Functions 변경 없이 앱 APK만 갱신하면 동작한다.
- 향후 공공데이터포털 키가 준비되면 Firebase Secret으로 보관하고 `KoreanHolidayService`의 원격 소스만 callable Function으로 교체한다.
