# 기념일 D-Day 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 커플 기념일 여러 개 등록 → 캘린더 상단 칩 + 안드로이드 홈위젯에 D-Day 표시.

**Architecture:** `couples/{coupleId}` 문서에 `anniversaries` 배열 필드 추가. 기존 `coupleStreamProvider`로 실시간 반영. D-Day 계산은 순수 함수(`lib/utils/dday_utils.dart`)로 분리해 단위 테스트. 위젯은 기존 SharedPreferences 파이프라인에 문자열 1개 추가.

**Tech Stack:** Flutter + Riverpod 2.x + cloud_firestore, go_router, home_widget, Kotlin RemoteViews.

**Spec:** `docs/superpowers/specs/2026-07-17-anniversary-dday-design.md`

## Global Constraints

- Firestore 쓰기는 항상 `set(..., SetOptions(merge: true))` (couples/users 문서).
- countUp 당일 = `D+1`. annual 당일 = `D-Day`, 도래 전 = `D-n`. 2/29 annual은 평년 2/28 취급.
- UI 문구 한국어. 기존 코드 스타일(ConsumerWidget, 한국어 주석 최소) 따름.
- 테스트 실행: `flutter test <파일>`. 정적 분석: `flutter analyze`.
- 커밋 메시지: conventional commits 한국어 본문 (기존 히스토리 스타일).

---

### Task 1: AnniversaryModel + D-Day 계산 유틸 (TDD)

**Files:**
- Create: `lib/models/anniversary_model.dart`
- Create: `lib/utils/dday_utils.dart`
- Test: `test/utils/dday_utils_test.dart`

**Interfaces:**
- Produces: `AnniversaryModel(id, title, date, type)` + `fromMap`/`toMap`, `enum AnniversaryType { countUp, annual }`
- Produces: `String dDayLabel(AnniversaryModel a, DateTime now)`, `DateTime nextAnnualDate(DateTime base, DateTime today)`, `List<AnniversaryModel> sortedForDisplay(List<AnniversaryModel> list, DateTime now)`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/utils/dday_utils_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_calender/models/anniversary_model.dart';
import 'package:test_calender/utils/dday_utils.dart';

AnniversaryModel _ann(String type, DateTime date) => AnniversaryModel(
      id: 'id-$type-${date.toIso8601String()}',
      title: 't',
      date: date,
      type: type == 'annual' ? AnniversaryType.annual : AnniversaryType.countUp,
    );

void main() {
  group('dDayLabel countUp', () {
    test('기준일 당일은 D+1', () {
      expect(dDayLabel(_ann('countUp', DateTime(2026, 1, 1)), DateTime(2026, 1, 1)), 'D+1');
    });
    test('경과일 카운트업', () {
      expect(dDayLabel(_ann('countUp', DateTime(2026, 1, 1)), DateTime(2026, 1, 2)), 'D+2');
      expect(dDayLabel(_ann('countUp', DateTime(2025, 7, 17)), DateTime(2026, 7, 17)), 'D+366');
    });
    test('시각 무시 (자정 기준)', () {
      expect(
        dDayLabel(_ann('countUp', DateTime(2026, 1, 1, 23, 59)), DateTime(2026, 1, 2, 0, 1)),
        'D+2',
      );
    });
  });

  group('dDayLabel annual', () {
    test('도래 전 D-n', () {
      expect(dDayLabel(_ann('annual', DateTime(2000, 8, 1)), DateTime(2026, 7, 17)), 'D-15');
    });
    test('당일 D-Day', () {
      expect(dDayLabel(_ann('annual', DateTime(2000, 7, 17)), DateTime(2026, 7, 17)), 'D-Day');
    });
    test('직후엔 내년 도래일 기준', () {
      expect(dDayLabel(_ann('annual', DateTime(2000, 7, 16)), DateTime(2026, 7, 17)), 'D-364');
    });
    test('2/29 기준일은 평년 2/28 취급', () {
      expect(dDayLabel(_ann('annual', DateTime(2024, 2, 29)), DateTime(2026, 2, 1)), 'D-27');
    });
  });

  group('sortedForDisplay', () {
    test('annual 임박순 먼저, countUp은 기준일 오래된 순으로 뒤에', () {
      final now = DateTime(2026, 7, 17);
      final list = [
        _ann('countUp', DateTime(2025, 1, 1)),
        _ann('annual', DateTime(2000, 12, 25)),
        _ann('annual', DateTime(2000, 8, 1)),
        _ann('countUp', DateTime(2024, 1, 1)),
      ];
      final sorted = sortedForDisplay(list, now);
      expect(sorted[0].date.month, 8); // annual 8/1 (D-15)
      expect(sorted[1].date.month, 12); // annual 12/25
      expect(sorted[2].date.year, 2024); // countUp 오래된 것
      expect(sorted[3].date.year, 2025);
    });
  });

  group('AnniversaryModel 직렬화', () {
    test('toMap → fromMap 왕복', () {
      final a = AnniversaryModel(
        id: 'x1',
        title: '처음 만난 날',
        date: DateTime(2024, 3, 1),
        type: AnniversaryType.countUp,
      );
      final b = AnniversaryModel.fromMap(a.toMap());
      expect(b.id, 'x1');
      expect(b.title, '처음 만난 날');
      expect(b.date, DateTime(2024, 3, 1));
      expect(b.type, AnniversaryType.countUp);
    });
    test('toMap의 date는 Timestamp', () {
      final m = _ann('annual', DateTime(2024, 3, 1)).toMap();
      expect(m['date'], isA<Timestamp>());
      expect(m['type'], 'annual');
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/utils/dday_utils_test.dart`
Expected: FAIL (컴파일 에러 — `anniversary_model.dart` 없음)

- [ ] **Step 3: 최소 구현**

`lib/models/anniversary_model.dart`:

```dart
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
```

`lib/utils/dday_utils.dart`:

```dart
import 'package:flutter/material.dart' show DateUtils;
import '../models/anniversary_model.dart';

/// countUp: 기준일 당일 = D+1 (사귄 날 당일을 1일로 센다)
/// annual: 다음 도래일까지 D-n, 당일 D-Day
String dDayLabel(AnniversaryModel a, DateTime now) {
  final today = DateUtils.dateOnly(now);
  final base = DateUtils.dateOnly(a.date);
  if (a.type == AnniversaryType.countUp) {
    return 'D+${today.difference(base).inDays + 1}';
  }
  final diff = nextAnnualDate(base, today).difference(today).inDays;
  return diff == 0 ? 'D-Day' : 'D-$diff';
}

/// base의 다음 연간 도래일. 2/29는 평년 2/28 취급.
DateTime nextAnnualDate(DateTime base, DateTime today) {
  DateTime occurrence(int year) {
    if (base.month == 2 && base.day == 29 && !_isLeapYear(year)) {
      return DateTime(year, 2, 28);
    }
    return DateTime(year, base.month, base.day);
  }

  final thisYear = occurrence(today.year);
  return thisYear.isBefore(today) ? occurrence(today.year + 1) : thisYear;
}

bool _isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// 표시 순서: annual 도래 임박순 → countUp 기준일 오래된 순
List<AnniversaryModel> sortedForDisplay(List<AnniversaryModel> list, DateTime now) {
  final today = DateUtils.dateOnly(now);
  final annuals = list.where((a) => a.type == AnniversaryType.annual).toList()
    ..sort((a, b) => nextAnnualDate(DateUtils.dateOnly(a.date), today)
        .compareTo(nextAnnualDate(DateUtils.dateOnly(b.date), today)));
  final countUps = list.where((a) => a.type == AnniversaryType.countUp).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return [...annuals, ...countUps];
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/utils/dday_utils_test.dart`
Expected: PASS (전체)

- [ ] **Step 5: 커밋**

```bash
git add lib/models/anniversary_model.dart lib/utils/dday_utils.dart test/utils/dday_utils_test.dart
git commit -m "feat: 기념일 모델 및 D-Day 계산 유틸 추가"
```

---

### Task 2: CoupleModel에 anniversaries 필드 (TDD)

**Files:**
- Modify: `lib/models/couple_model.dart`
- Test: `test/models/couple_model_test.dart`

**Interfaces:**
- Consumes: `AnniversaryModel.fromMap/toMap` (Task 1)
- Produces: `CoupleModel.anniversaries` (`List<AnniversaryModel>`, 기본 빈 리스트, 불량 항목 개별 스킵), `copyWith(anniversaries: ...)`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/models/couple_model_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_calender/models/couple_model.dart';

Map<String, dynamic> _baseCoupleMap() => {
      'coupleId': 'c1',
      'ownerUid': 'u1',
      'partnerUid': 'u2',
      'inviteCode': 'ABC123',
      'isLinked': true,
      'ownerColor': 0xFF42A5F5,
      'partnerColor': 0xFFF48FB1,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    };

void main() {
  test('anniversaries 필드 없으면 빈 리스트', () {
    final c = CoupleModel.fromMap(_baseCoupleMap());
    expect(c.anniversaries, isEmpty);
  });

  test('정상 항목 파싱', () {
    final map = _baseCoupleMap()
      ..['anniversaries'] = [
        {
          'id': 'a1',
          'title': '처음 만난 날',
          'date': Timestamp.fromDate(DateTime(2024, 3, 1)),
          'type': 'countUp',
        },
      ];
    final c = CoupleModel.fromMap(map);
    expect(c.anniversaries.length, 1);
    expect(c.anniversaries.first.title, '처음 만난 날');
  });

  test('불량 항목은 개별 스킵, 나머지는 유지', () {
    final map = _baseCoupleMap()
      ..['anniversaries'] = [
        {'id': 'bad'}, // title/date 없음 → 스킵
        {
          'id': 'a2',
          'title': '생일',
          'date': Timestamp.fromDate(DateTime(2000, 8, 1)),
          'type': 'annual',
        },
      ];
    final c = CoupleModel.fromMap(map);
    expect(c.anniversaries.length, 1);
    expect(c.anniversaries.first.id, 'a2');
  });

  test('toMap에 anniversaries 포함', () {
    final map = _baseCoupleMap()
      ..['anniversaries'] = [
        {
          'id': 'a1',
          'title': 't',
          'date': Timestamp.fromDate(DateTime(2024, 3, 1)),
          'type': 'countUp',
        },
      ];
    final c = CoupleModel.fromMap(map);
    expect((c.toMap()['anniversaries'] as List).length, 1);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/models/couple_model_test.dart`
Expected: FAIL (`anniversaries` getter 없음 — 컴파일 에러)

- [ ] **Step 3: CoupleModel 수정**

`lib/models/couple_model.dart` — import 추가 + 필드/파싱/직렬화/copyWith:

```dart
import 'anniversary_model.dart';
```

클래스에 필드 추가:

```dart
  final List<AnniversaryModel> anniversaries;
```

생성자 파라미터 추가 (`required` 아님, 기본값):

```dart
    this.anniversaries = const [],
```

`fromMap`에 추가:

```dart
      anniversaries: _parseAnniversaries(map['anniversaries']),
```

클래스 안에 static 파서 추가:

```dart
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
```

`toMap`에 추가:

```dart
      'anniversaries': anniversaries.map((a) => a.toMap()).toList(),
```

`copyWith`에 파라미터 `List<AnniversaryModel>? anniversaries` 추가, 본문에 `anniversaries: anniversaries ?? this.anniversaries,` 추가.

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/models/couple_model_test.dart && flutter test test/utils/dday_utils_test.dart`
Expected: PASS (전체)

- [ ] **Step 5: 커밋**

```bash
git add lib/models/couple_model.dart test/models/couple_model_test.dart
git commit -m "feat: CoupleModel에 기념일 목록 필드 추가"
```

---

### Task 3: Firestore 저장 + 기념일 관리 화면 + 라우트

**Files:**
- Modify: `lib/services/firestore_service.dart` (Couple 섹션 끝에 메서드 추가)
- Create: `lib/screens/settings/anniversary_screen.dart`
- Modify: `lib/router/app_router.dart` (라우트 1개)
- Modify: `lib/screens/settings/settings_screen.dart` (진입 ListTile)

**Interfaces:**
- Consumes: `AnniversaryModel`, `AnniversaryType`, `dDayLabel`, `sortedForDisplay` (Task 1), `CoupleModel.anniversaries`/`copyWith` (Task 2), `coupleStreamProvider`, `firestoreServiceProvider` (기존)
- Produces: `FirestoreService.updateAnniversaries(String coupleId, List<AnniversaryModel> anniversaries)`, 라우트 `/settings/anniversaries`, `AnniversaryScreen`

- [ ] **Step 1: FirestoreService 메서드 추가**

`lib/services/firestore_service.dart` — import에 `import '../models/anniversary_model.dart';` 추가, Couple 섹션에:

```dart
  Future<void> updateAnniversaries(
      String coupleId, List<AnniversaryModel> anniversaries) {
    return _db.collection('couples').doc(coupleId).set({
      'anniversaries': anniversaries.map((a) => a.toMap()).toList(),
    }, SetOptions(merge: true));
  }
```

- [ ] **Step 2: 기념일 관리 화면 작성**

`lib/screens/settings/anniversary_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/anniversary_model.dart';
import '../../providers/calendar_provider.dart';
import '../../utils/dday_utils.dart';

class AnniversaryScreen extends ConsumerWidget {
  const AnniversaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupleAsync = ref.watch(coupleStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('기념일 관리')),
      body: coupleAsync.when(
        data: (couple) {
          if (couple == null) {
            return const Center(child: Text('파트너 연결 후 사용할 수 있습니다'));
          }
          final list = sortedForDisplay(couple.anniversaries, DateTime.now());
          if (list.isEmpty) {
            return Center(
              child: Text('기념일을 추가해보세요',
                  style: TextStyle(color: Colors.grey[400])),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final a = list[i];
              return ListTile(
                leading: Icon(
                  a.type == AnniversaryType.countUp
                      ? Icons.favorite
                      : Icons.cake,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(a.title),
                subtitle: Text(
                  '${DateFormat('yyyy.MM.dd').format(a.date)} · ${a.type == AnniversaryType.countUp ? '카운트업' : '매년 반복'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dDayLabel(a, DateTime.now()),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _confirmDelete(context, ref, couple.coupleId,
                          couple.anniversaries, a),
                    ),
                  ],
                ),
                onTap: () => _showForm(context, ref, couple.coupleId,
                    couple.anniversaries, existing: a),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('불러오지 못했습니다')),
      ),
      floatingActionButton: coupleAsync.valueOrNull == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showForm(
                context,
                ref,
                coupleAsync.value!.coupleId,
                coupleAsync.value!.anniversaries,
              ),
              child: const Icon(Icons.add),
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String coupleId,
    List<AnniversaryModel> current,
    AnniversaryModel target,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기념일 삭제'),
        content: Text("'${target.title}'을(를) 삭제할까요?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = current.where((a) => a.id != target.id).toList();
    await ref
        .read(firestoreServiceProvider)
        .updateAnniversaries(coupleId, updated);
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref,
    String coupleId,
    List<AnniversaryModel> current, {
    AnniversaryModel? existing,
  }) async {
    final result = await showDialog<AnniversaryModel>(
      context: context,
      builder: (ctx) => _AnniversaryFormDialog(existing: existing),
    );
    if (result == null) return;
    final updated = [
      ...current.where((a) => a.id != result.id),
      result,
    ];
    await ref
        .read(firestoreServiceProvider)
        .updateAnniversaries(coupleId, updated);
  }
}

class _AnniversaryFormDialog extends StatefulWidget {
  final AnniversaryModel? existing;
  const _AnniversaryFormDialog({this.existing});

  @override
  State<_AnniversaryFormDialog> createState() => _AnniversaryFormDialogState();
}

class _AnniversaryFormDialogState extends State<_AnniversaryFormDialog> {
  late final TextEditingController _titleController;
  late DateTime _date;
  late AnniversaryType _type;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existing?.title ?? '');
    _date = widget.existing?.date ?? DateUtils.dateOnly(DateTime.now());
    _type = widget.existing?.type ?? AnniversaryType.countUp;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '기념일 추가' : '기념일 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '제목'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('날짜'),
            trailing: Text(DateFormat('yyyy.MM.dd').format(_date)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1990),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 4),
          SegmentedButton<AnniversaryType>(
            segments: const [
              ButtonSegment(
                  value: AnniversaryType.countUp, label: Text('D+ 카운트업')),
              ButtonSegment(
                  value: AnniversaryType.annual, label: Text('매년 반복')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              context,
              AnniversaryModel(
                id: widget.existing?.id ?? const Uuid().v4(),
                title: title,
                date: DateUtils.dateOnly(_date),
                type: _type,
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: 라우트 + 설정 진입점**

`lib/router/app_router.dart` — import 추가:

```dart
import '../screens/settings/anniversary_screen.dart';
```

routes 리스트 `/settings` 다음에:

```dart
      GoRoute(
        path: '/settings/anniversaries',
        builder: (context, _) => const AnniversaryScreen(),
      ),
```

`lib/screens/settings/settings_screen.dart` — 파트너 연결 상태 블록과 앱 정보 사이 (`const Divider(),` 117행 뒤)에:

```dart
          // 기념일 관리
          ListTile(
            leading: const Icon(Icons.cake_outlined),
            title: const Text('기념일 관리'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/anniversaries'),
          ),
          const Divider(),
```

- [ ] **Step 4: 정적 분석 + 수동 확인**

Run: `flutter analyze`
Expected: No issues found

Run: `flutter run -d chrome` (또는 orca 탭 리로드) → 설정 → 기념일 관리 → 추가/수정/삭제 동작 확인. Firestore 콘솔에서 `couples/{id}.anniversaries` 배열 확인.

- [ ] **Step 5: 커밋**

```bash
git add lib/services/firestore_service.dart lib/screens/settings/anniversary_screen.dart lib/router/app_router.dart lib/screens/settings/settings_screen.dart
git commit -m "feat: 기념일 관리 화면 및 Firestore 저장 추가"
```

---

### Task 4: 캘린더 상단 D-Day 칩 줄

**Files:**
- Create: `lib/screens/calendar/anniversary_chips.dart`
- Modify: `lib/screens/calendar/calendar_screen.dart`

**Interfaces:**
- Consumes: `AnniversaryModel`, `dDayLabel`, `sortedForDisplay` (Task 1), `coupleAsync` (calendar_screen 기존 변수)
- Produces: `AnniversaryChips(anniversaries: List<AnniversaryModel>)` — 빈 리스트면 `SizedBox.shrink()`

- [ ] **Step 1: 칩 위젯 작성**

`lib/screens/calendar/anniversary_chips.dart`:

```dart
import 'package:flutter/material.dart';
import '../../models/anniversary_model.dart';
import '../../utils/dday_utils.dart';

class AnniversaryChips extends StatelessWidget {
  final List<AnniversaryModel> anniversaries;

  const AnniversaryChips({super.key, required this.anniversaries});

  @override
  Widget build(BuildContext context) {
    if (anniversaries.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final sorted = sortedForDisplay(anniversaries, now);
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final a = sorted[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  a.type == AnniversaryType.countUp
                      ? Icons.favorite
                      : Icons.cake,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  '${a.title} ${dDayLabel(a, now)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: calendar_screen에 삽입**

`lib/screens/calendar/calendar_screen.dart`:

import 추가:

```dart
import 'anniversary_chips.dart';
```

보라색 헤더 Column 안, 상단 Row(`Padding(padding: const EdgeInsets.fromLTRB(4, 4, 12, 4), ...)` 블록)와 요일 라벨 Row 사이에:

```dart
                  coupleAsync.maybeWhen(
                    data: (couple) => couple == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: AnniversaryChips(
                                anniversaries: couple.anniversaries),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
```

- [ ] **Step 3: 정적 분석 + 수동 확인**

Run: `flutter analyze`
Expected: No issues found

chrome/orca 탭에서 확인: 기념일 있으면 헤더에 칩 줄, 0개면 칩 줄 없음(레이아웃 안 깨짐).

- [ ] **Step 4: 커밋**

```bash
git add lib/screens/calendar/anniversary_chips.dart lib/screens/calendar/calendar_screen.dart
git commit -m "feat: 캘린더 상단 기념일 D-Day 칩 표시"
```

---

### Task 5: 홈위젯 D-Day 표시

**Files:**
- Modify: `lib/services/widget_service.dart`
- Modify: `lib/providers/calendar_provider.dart` (`widgetSyncProvider`)
- Modify: `android/app/src/main/res/layout/calendar_widget.xml`
- Modify: `android/app/src/main/kotlin/com/example/test_calender/CalendarWidgetProvider.kt`

**Interfaces:**
- Consumes: `AnniversaryModel`, `AnniversaryType`, `dDayLabel`, `sortedForDisplay` (Task 1), `coupleStreamProvider` (기존)
- Produces: `WidgetService.update(List<EventModel> allEvents, {List<AnniversaryModel> anniversaries})`, SharedPreferences 키 `calendar_widget_dday` (빈 문자열 = 표시 안 함)

- [ ] **Step 1: WidgetService에 D-Day 문자열 추가**

`lib/services/widget_service.dart` — import 추가:

```dart
import '../models/anniversary_model.dart';
import '../utils/dday_utils.dart';
```

`update` 시그니처 변경 및 본문에 추가:

```dart
  static Future<void> update(
    List<EventModel> allEvents, {
    List<AnniversaryModel> anniversaries = const [],
  }) async {
```

`calendar_widget_today` 저장 다음 줄에:

```dart
      await HomeWidget.saveWidgetData<String>(
          'calendar_widget_dday', _dDayLine(anniversaries, now));
```

클래스에 private 헬퍼 추가:

```dart
  /// 도래 임박 annual 1개 + 대표(가장 오래된) countUp 1개. 없으면 빈 문자열.
  static String _dDayLine(List<AnniversaryModel> anniversaries, DateTime now) {
    if (anniversaries.isEmpty) return '';
    final sorted = sortedForDisplay(anniversaries, now);
    final parts = <String>[];
    final annual = sorted
        .where((a) => a.type == AnniversaryType.annual)
        .take(1);
    final countUp = sorted
        .where((a) => a.type == AnniversaryType.countUp)
        .take(1);
    for (final a in [...countUp, ...annual]) {
      parts.add('${a.title} ${dDayLabel(a, now)}');
    }
    return parts.join(' · ');
  }
```

- [ ] **Step 2: widgetSyncProvider에 couple 연결**

`lib/providers/calendar_provider.dart`의 `widgetSyncProvider` 교체:

```dart
// 이벤트/기념일 변경 시 홈 위젯 자동 갱신
final widgetSyncProvider = Provider<void>((ref) {
  final events = ref.watch(eventsStreamProvider).valueOrNull;
  final couple = ref.watch(coupleStreamProvider).valueOrNull;
  if (events != null) {
    WidgetService.update(events,
        anniversaries: couple?.anniversaries ?? const []);
  }
});
```

- [ ] **Step 3: 위젯 XML에 D-Day 줄 추가**

`android/app/src/main/res/layout/calendar_widget.xml` — 헤더 LinearLayout 닫힌 뒤, 구분선 View 앞에:

```xml
    <!-- D-Day -->
    <TextView
        android:id="@+id/widget_dday"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:text=""
        android:textColor="#FFC2185B"
        android:textSize="11sp"
        android:textStyle="bold"
        android:maxLines="1"
        android:ellipsize="end"
        android:visibility="gone" />
```

- [ ] **Step 4: Kotlin 바인딩**

`CalendarWidgetProvider.kt`의 `updateWidget` 안, `views.setTextViewText(R.id.widget_today_label, todayLabel)` 다음에:

```kotlin
            val ddayLine = prefs.getString("flutter.calendar_widget_dday", "") ?: ""
            if (ddayLine.isNotEmpty()) {
                views.setTextViewText(R.id.widget_dday, ddayLine)
                views.setViewVisibility(R.id.widget_dday, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_dday, View.GONE)
            }
```

- [ ] **Step 5: 전체 테스트 + 정적 분석**

Run: `flutter test && flutter analyze`
Expected: 전체 PASS, No issues found

- [ ] **Step 6: 실기기 확인 (Z플립5)**

Run: `flutter run -d R3CW70R1BCW`
확인: 기념일 등록 → 홈 위젯에 D-Day 줄 표시, 기념일 전부 삭제 → 줄 사라짐.

- [ ] **Step 7: 커밋**

```bash
git add lib/services/widget_service.dart lib/providers/calendar_provider.dart android/app/src/main/res/layout/calendar_widget.xml android/app/src/main/kotlin/com/example/test_calender/CalendarWidgetProvider.kt
git commit -m "feat: 홈위젯에 기념일 D-Day 표시"
```
