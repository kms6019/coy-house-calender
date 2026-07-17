# 커플 색상 커스텀 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 설정에서 내 색상을 프리셋 12색 중 선택, 내가 만든 기존 일정 색도 batch 일괄 변경.

**Architecture:** 팔레트 상수 + 역할→필드 순수 함수(`lib/theme/couple_palette.dart`), `FirestoreService.updateMyColor`(couple merge set + events batch update), 설정 화면 색 점 탭 → 12색 그리드 다이얼로그.

**Tech Stack:** Flutter + Riverpod 2.x + cloud_firestore.

**Spec:** `docs/superpowers/specs/2026-07-17-couple-color-design.md`

## Global Constraints

- couples 문서 쓰기는 `set(..., SetOptions(merge: true))`.
- 팔레트 12색 hex는 스펙 값 그대로 (아래 코드에 포함).
- 자기 색만 변경. 파트너 현재 색은 다이얼로그에서 비활성(탭 불가, 반투명).
- 현재 색 재선택 = no-op. batch 실패 → 스낵바 "일부 일정 색이 변경되지 않았습니다.".
- 테스트 import `package:coy_house_calender/...`. Flutter PATH: `$env:PATH += ";C:\flutter_windows_3.41.6-stable\flutter\bin"`.
- 커밋: conventional commits 한국어 제목.

---

### Task 1: 팔레트 + 역할 필드 함수 + updateMyColor (TDD)

**Files:**
- Create: `lib/theme/couple_palette.dart`
- Modify: `lib/services/firestore_service.dart` (Couple 섹션에 메서드 추가)
- Test: `test/theme/couple_palette_test.dart` (신규)

**Interfaces:**
- Produces: `const List<int> kCouplePalette` (12개 ARGB int)
- Produces: `String myColorField(CoupleModel couple, String myUid)` → `'ownerColor'` | `'partnerColor'`
- Produces: `FirestoreService.updateMyColor({required CoupleModel couple, required String myUid, required int color})`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/theme/couple_palette_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/models/couple_model.dart';
import 'package:coy_house_calender/theme/couple_palette.dart';

CoupleModel _couple() => CoupleModel.fromMap({
      'coupleId': 'c1',
      'ownerUid': 'owner-uid',
      'partnerUid': 'partner-uid',
      'inviteCode': 'ABC123',
      'isLinked': true,
      'ownerColor': 0xFF42A5F5,
      'partnerColor': 0xFFF06292,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });

void main() {
  test('팔레트는 12색, 전부 불투명 ARGB', () {
    expect(kCouplePalette.length, 12);
    expect(kCouplePalette.toSet().length, 12); // 중복 없음
    for (final c in kCouplePalette) {
      expect(c >> 24 & 0xFF, 0xFF); // alpha FF
    }
  });

  test('owner는 ownerColor 필드', () {
    expect(myColorField(_couple(), 'owner-uid'), 'ownerColor');
  });

  test('partner는 partnerColor 필드', () {
    expect(myColorField(_couple(), 'partner-uid'), 'partnerColor');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/theme/couple_palette_test.dart`
Expected: FAIL (couple_palette.dart 없음)

- [ ] **Step 3: 구현**

`lib/theme/couple_palette.dart`:

```dart
import '../models/couple_model.dart';

/// 커플 색상 프리셋 (Material 계열 12색)
const List<int> kCouplePalette = [
  0xFFEF5350, // red400
  0xFFF06292, // pink300
  0xFFAB47BC, // purple400
  0xFF7E57C2, // deepPurple400
  0xFF5C6BC0, // indigo400
  0xFF42A5F5, // blue400
  0xFF26A69A, // teal400
  0xFF66BB6A, // green400
  0xFFFFB300, // amber600
  0xFFFFA726, // orange400
  0xFF8D6E63, // brown400
  0xFF78909C, // blueGrey400
];

/// 내 역할에 해당하는 couples 문서 색상 필드명
String myColorField(CoupleModel couple, String myUid) {
  return couple.ownerUid == myUid ? 'ownerColor' : 'partnerColor';
}
```

`lib/services/firestore_service.dart` — import 추가 `import '../theme/couple_palette.dart';`, Couple 섹션에 메서드 추가:

```dart
  /// 내 색상 변경: couples 문서 + 내가 만든 기존 이벤트 색 일괄 변경
  Future<void> updateMyColor({
    required CoupleModel couple,
    required String myUid,
    required int color,
  }) async {
    final field = myColorField(couple, myUid);
    await _db
        .collection('couples')
        .doc(couple.coupleId)
        .set({field: color}, SetOptions(merge: true));

    final snap = await _db
        .collection('events')
        .where('coupleId', isEqualTo: couple.coupleId)
        .where('createdByUid', isEqualTo: myUid)
        .get();
    for (var i = 0; i < snap.docs.length; i += 500) {
      final batch = _db.batch();
      for (final doc in snap.docs.skip(i).take(500)) {
        batch.update(doc.reference, {'color': color});
      }
      await batch.commit();
    }
  }
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/theme/couple_palette_test.dart && flutter analyze`
Expected: PASS(3), No issues

- [ ] **Step 5: 커밋**

```bash
git add lib/theme/couple_palette.dart lib/services/firestore_service.dart test/theme/couple_palette_test.dart
git commit -m "feat: 커플 색상 팔레트 및 색상 일괄 변경 서비스"
```

---

### Task 2: 설정 화면 색상 선택 다이얼로그

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart`

**Interfaces:**
- Consumes: `kCouplePalette`, `FirestoreService.updateMyColor` (Task 1), `firestoreServiceProvider`, `authStateProvider` (기존)

- [ ] **Step 1: 색 점 탭 가능하게 + 다이얼로그**

`lib/screens/settings/settings_screen.dart` — import 추가:

```dart
import '../../models/couple_model.dart';
import '../../theme/couple_palette.dart';
```

연결됨 상태 branch의 색 점 `Container(width: 12, height: 12, ...)`를 아래로 교체 (기존 trailing Row 안):

```dart
                        GestureDetector(
                          onTap: () => _pickMyColor(context, ref, couple, myUid!),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isOwner
                                  ? couple.ownerColorValue
                                  : couple.partnerColorValue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
                                size: 12, color: Colors.white70),
                          ),
                        ),
```

클래스에 메서드 추가:

```dart
  Future<void> _pickMyColor(BuildContext context, WidgetRef ref,
      CoupleModel couple, String myUid) async {
    final isOwner = couple.ownerUid == myUid;
    final myColor = isOwner ? couple.ownerColor : couple.partnerColor;
    final partnerColor = isOwner ? couple.partnerColor : couple.ownerColor;

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('내 색상'),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: kCouplePalette.map((c) {
              final isMine = c == myColor;
              final isPartner = c == partnerColor;
              return InkWell(
                onTap: isPartner ? null : () => Navigator.pop(ctx, c),
                customBorder: const CircleBorder(),
                child: Opacity(
                  opacity: isPartner ? 0.25 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                    ),
                    child: isMine
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
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

    if (picked == null || picked == myColor) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateMyColor(couple: couple, myUid: myUid, color: picked);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일부 일정 색이 변경되지 않았습니다.')),
        );
      }
    }
  }
```

주의: 연결됨 branch에서 `myUid`는 `ref.read(authStateProvider).valueOrNull?.uid`로 이미 선언돼 있음 (nullable) — `_pickMyColor` 호출부에서 `myUid!` 사용 전에 기존 코드 그대로면 null 가능성 낮지만, 안전하게 `if (myUid == null) return;` 가드를 색 점 onTap 직전이 아니라 호출부 람다 안에서 처리해도 됨: `onTap: myUid == null ? null : () => _pickMyColor(context, ref, couple, myUid)`.

- [ ] **Step 2: 검증**

Run: `flutter analyze && flutter test`
Expected: No issues, 전체 PASS

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/settings/settings_screen.dart
git commit -m "feat: 설정에서 내 색상 선택 (기존 일정 일괄 변경)"
```
