import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coy_house_calender/models/couple_model.dart';
import 'package:coy_house_calender/providers/auth_provider.dart';
import 'package:coy_house_calender/providers/calendar_provider.dart';
import 'package:coy_house_calender/screens/settings/anniversary_screen.dart';
import 'package:coy_house_calender/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CoupleModel _couple({List<Map<String, dynamic>> anniversaries = const []}) =>
    CoupleModel.fromMap({
      'coupleId': 'c1',
      'ownerUid': 'u1',
      'partnerUid': 'u2',
      'inviteCode': 'ABC123',
      'isLinked': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'anniversaries': anniversaries,
    });

Future<void> _pumpScreen(WidgetTester tester, CoupleModel couple) async {
  // Z플립5 화면(약 410x890dp)
  tester.view.devicePixelRatio = 2.25;
  tester.view.physicalSize = const Size(923, 2000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        coupleStreamProvider.overrideWith((ref) => Stream.value(couple)),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(kPrimaryPurple.toARGB32()),
        home: const AnniversaryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('키보드가 올라와 있어도 음력 스위치를 켤 수 있다', (tester) async {
    // 키보드가 화면 아래쪽을 반쯤 덮은 상태
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await _pumpScreen(tester, _couple());

    await tester.tap(find.widgetWithText(FilledButton, '기념일 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('매년 반복'));
    await tester.pumpAndSettle();

    final lunarSwitch = find.byType(Switch);
    await tester.ensureVisible(lunarSwitch);
    await tester.pumpAndSettle();
    await tester.tap(lunarSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(lunarSwitch).value, isTrue);
    expect(find.text('음력 ${DateTime.now().year}년 1월 1일'), findsOneWidget);
  });

  testWidgets('음력 기념일은 해까지 보이고, 해를 바꿔 고를 수 있다', (tester) async {
    await _pumpScreen(
      tester,
      _couple(
        anniversaries: [
          {
            'id': 'a1',
            'title': '엄마 생신',
            'date': Timestamp.fromDate(DateTime(2027, 4, 1)),
            'type': 'annual',
            'isLunar': true,
            'lunarYear': 1960,
            'lunarMonth': 3,
            'lunarDay': 5,
          },
        ],
      ),
    );

    // 목록 부제에 태어난 해
    expect(find.textContaining('음력 1960년 3월 5일'), findsOneWidget);

    // 수정 창 → 날짜 → 해만 1961 로
    await tester.tap(find.text('엄마 생신'));
    await tester.pumpAndSettle();
    expect(find.text('음력 1960년 3월 5일'), findsOneWidget);
    await tester.tap(find.text('날짜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1960년'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1961년').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('음력 1961년 3월 5일'), findsOneWidget);
  });
}
