# 이벤트 색상·이모지 아이콘 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 일정 생성/수정에서 개별 색상(12색) + 이모지 아이콘(프리셋 24개) 지정, 그리드/리스트/상세에 표시.

**Architecture:** `EventModel.icon: String?` 필드 추가(하위호환 null). 폼에 색상/아이콘 행 2개 + 그리드 다이얼로그(`kCouplePalette` 재사용, `kEventIcons` 신설). 표시는 셀(점 대신 이모지)/멀티데이 바·리스트·상세(제목 prefix).

**Tech Stack:** Flutter + Riverpod 2.x + cloud_firestore.

**Spec:** `docs/superpowers/specs/2026-07-17-event-color-icon-design.md`

## Global Constraints

- `icon` 없거나 null인 구 문서 → 표시 변화 없음 (하위호환).
- 이모지 프리셋 24개 순서 그대로: ❤️ 💕 🎂 🎉 ✈️ 🍽️ ☕ 🍿 🏥 💊 💪 🏃 🛒 🎁 📚 💼 🏠 🧹 🚗 ⛰️ 🎬 🎮 🐶 ⭐
- 새 일정 기본 색 = 내 커플 색 (couple null이면 0xFF42A5F5) — 기존 저장 로직과 동일 규칙.
- 기존 copyWith는 null 병합이라 icon 해제 불가 → `copyWithIcon(String? icon)` 별도 메서드 (repeatUntil의 copyWithRepeat 전례).
- 테스트 import `package:coy_house_calender/...`. Flutter PATH: `$env:PATH += ";C:\flutter_windows_3.41.6-stable\flutter\bin"`.
- lint: `(_, __)` → `(_, _)`. 커밋: conventional commits 한국어 제목.

---

### Task 1: EventModel.icon + 이모지 상수 (TDD)

**Files:**
- Modify: `lib/models/event_model.dart`
- Create: `lib/theme/event_icons.dart`
- Test: `test/models/event_model_test.dart` (기존 파일에 그룹 추가)

**Interfaces:**
- Produces: `EventModel.icon` (String?, 기본 null), fromMap/toMap/copyWith 보존, `EventModel copyWithIcon(String? icon)` — null로 덮어쓰기 가능
- Produces: `const List<String> kEventIcons` (24개)

- [ ] **Step 1: 실패하는 테스트 추가**

`test/models/event_model_test.dart`의 `main()` 안에 그룹 추가:

```dart
  group('icon 필드', () {
    test('필드 없는 구 문서는 null', () {
      expect(EventModel.fromMap(_baseMap()).icon, isNull);
    });

    test('직렬화 왕복', () {
      final e = EventModel.fromMap(_baseMap()..['icon'] = '🎂');
      expect(e.icon, '🎂');
      expect(e.toMap()['icon'], '🎂');
    });

    test('copyWith는 icon 보존', () {
      final e = EventModel.fromMap(_baseMap()..['icon'] = '🎂');
      expect(e.copyWith(title: 'x').icon, '🎂');
    });

    test('copyWithIcon은 null로 해제 가능', () {
      final e = EventModel.fromMap(_baseMap()..['icon'] = '🎂');
      expect(e.copyWithIcon(null).icon, isNull);
      expect(e.copyWithIcon('⭐').icon, '⭐');
      expect(e.copyWithIcon('⭐').title, e.title);
    });
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/models/event_model_test.dart`
Expected: FAIL (icon getter 없음 — 컴파일 에러)

- [ ] **Step 3: 구현**

`lib/models/event_model.dart`:
- 필드 `final String? icon;` 추가, 생성자에 `this.icon,` 추가.
- `fromMap`: `icon: map['icon'] as String?,`
- `toMap`: `'icon': icon,`
- 기존 `copyWith` 본문 EventModel 생성 인자에 `icon: icon,` 추가 (보존).
- 메서드 추가:

```dart
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
    );
  }
```

- 주의: `copyWithRepeat` 본문에도 `icon: icon,` 보존 추가 (빠뜨리면 반복 수정 시 아이콘 소실).

`lib/theme/event_icons.dart`:

```dart
/// 이벤트 이모지 아이콘 프리셋
const List<String> kEventIcons = [
  '❤️', '💕', '🎂', '🎉', '✈️', '🍽️',
  '☕', '🍿', '🏥', '💊', '💪', '🏃',
  '🛒', '🎁', '📚', '💼', '🏠', '🧹',
  '🚗', '⛰️', '🎬', '🎮', '🐶', '⭐',
];
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test`
Expected: 전체 PASS (기존 회귀 없음)

- [ ] **Step 5: 커밋**

```bash
git add lib/models/event_model.dart lib/theme/event_icons.dart test/models/event_model_test.dart
git commit -m "feat: EventModel에 이모지 아이콘 필드 추가"
```

---

### Task 2: 폼 색상·아이콘 선택

**Files:**
- Modify: `lib/screens/event/event_form_screen.dart`

**Interfaces:**
- Consumes: `kCouplePalette` (lib/theme/couple_palette.dart), `kEventIcons`, `copyWithIcon` (Task 1), `coupleStreamProvider`/`authStateProvider` (기존)

- [ ] **Step 1: 상태 + 초기화**

`_EventFormScreenState` 필드 추가 (`_repeatUntil` 아래):

```dart
  int? _color; // null = 내 커플 색 (기본)
  String? _icon;
```

import 추가:

```dart
import '../../theme/couple_palette.dart';
import '../../theme/event_icons.dart';
```

`initState`의 `if (widget.event != null) {` 블록에 추가:

```dart
      _color = widget.event!.color;
      _icon = widget.event!.icon;
```

- [ ] **Step 2: 저장 반영**

`_save()`의 기존 `final color = couple != null ...;` 선언 직후에 추가:

```dart
    final effectiveColor = _color ?? color;
```

신규 생성 draft의 `color: color,`를 `color: effectiveColor,`로 교체, draft 인자에 `icon: _icon,` 추가.

수정 경로: `saved = saved.copyWithRepeat(...)` 다음 줄에 추가:

```dart
        saved = saved.copyWith(color: effectiveColor).copyWithIcon(_icon);
```

(참고: copyWith에 color 파라미터가 없으면 추가 — 기존 copyWith 파라미터 목록 확인. 현재 copyWith에 `int? color` 있음.)

- [ ] **Step 3: UI 행 2개 (반복 섹션 `const Divider(),` 뒤, 알림 SwitchListTile 앞)**

```dart
            // 색상
            Builder(builder: (context) {
              final couple = ref.watch(coupleStreamProvider).valueOrNull;
              final authUid = ref.watch(authStateProvider).valueOrNull?.uid;
              final defaultColor = couple != null
                  ? (couple.ownerUid == authUid
                      ? couple.ownerColor
                      : couple.partnerColor)
                  : 0xFF42A5F5;
              final shown = _color ?? defaultColor;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_outlined),
                title: const Text('색상'),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(shown),
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () => _pickColor(shown),
              );
            }),
            // 아이콘
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('아이콘'),
              trailing: Text(_icon ?? '없음',
                  style: TextStyle(
                      fontSize: _icon != null ? 22 : 14,
                      color: _icon != null ? null : Colors.grey)),
              onTap: _pickIcon,
            ),
            const Divider(),
```

- [ ] **Step 4: 다이얼로그 메서드 2개 (클래스에 추가)**

```dart
  Future<void> _pickColor(int current) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('색상 선택'),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: kCouplePalette.map((c) {
              return InkWell(
                onTap: () => Navigator.pop(ctx, c),
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                  ),
                  child: c == current
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        ],
      ),
    );
    if (picked != null) setState(() => _color = picked);
  }

  Future<void> _pickIcon() async {
    // sentinel: '' = 없음 선택
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('아이콘 선택'),
        content: SizedBox(
          width: 300,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: kEventIcons.map((emoji) {
              return InkWell(
                onTap: () => Navigator.pop(ctx, emoji),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  decoration: _icon == emoji
                      ? BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('없음')),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        ],
      ),
    );
    if (picked == null) return;
    setState(() => _icon = picked.isEmpty ? null : picked);
  }
```

- [ ] **Step 5: 검증 + 커밋**

Run: `flutter analyze && flutter test`
Expected: 신규 이슈 0, 전체 PASS

```bash
git add lib/screens/event/event_form_screen.dart
git commit -m "feat: 이벤트 폼에 색상·아이콘 선택 추가"
```

---

### Task 3: 그리드/리스트/상세 아이콘 표시

**Files:**
- Modify: `lib/screens/calendar/month_grid.dart` (하루짜리 셀 점 + 멀티데이 바)
- Modify: `lib/screens/event/event_list_tile.dart` (제목 prefix)
- Modify: `lib/screens/event/event_detail_screen.dart` (제목 prefix)

**Interfaces:**
- Consumes: `EventModel.icon` (Task 1)

- [ ] **Step 1: month_grid — 셀 점을 이모지로 대체**

`_DayCell`의 하루짜리 이벤트 Row에서 색 점 `Container(width: 5, height: 5, ...)` 부분을 교체:

```dart
                        if (e.icon != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Text(e.icon!,
                                style: const TextStyle(fontSize: 8)),
                          )
                        else
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: e.colorValue,
                              shape: BoxShape.circle,
                            ),
                          ),
```

- [ ] **Step 2: month_grid — 멀티데이 바 제목 prefix**

바의 `Text(placement.event.title, ...)`를 교체:

```dart
                    child: Text(
                      placement.event.icon != null
                          ? '${placement.event.icon} ${placement.event.title}'
                          : placement.event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
```

- [ ] **Step 3: event_list_tile — 제목 prefix**

`title: Text(event.title),`을 교체:

```dart
      title: Text(
          event.icon != null ? '${event.icon} ${event.title}' : event.title),
```

- [ ] **Step 4: event_detail_screen — 제목 prefix**

제목 `Text(event.title, style: ...headlineSmall)`을 교체:

```dart
                child: Text(
                  event.icon != null
                      ? '${event.icon} ${event.title}'
                      : event.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
```

- [ ] **Step 5: 검증 + 커밋**

Run: `flutter analyze && flutter test`
Expected: 신규 이슈 0, 전체 PASS

```bash
git add lib/screens/calendar/month_grid.dart lib/screens/event/event_list_tile.dart lib/screens/event/event_detail_screen.dart
git commit -m "feat: 캘린더 그리드·리스트·상세에 이벤트 아이콘 표시"
```
