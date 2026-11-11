import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coy_house_calender/models/couple_model.dart';
import 'package:coy_house_calender/providers/auth_provider.dart';
import 'package:coy_house_calender/providers/calendar_provider.dart';
import 'package:coy_house_calender/screens/settings/anniversary_screen.dart';
import 'package:coy_house_calender/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('키보드가 올라와 있어도 음력 스위치를 켤 수 있다', (tester) async {
    // Z플립5 화면(약 410x890dp)에 키보드가 반쯤 덮은 상태
    tester.view.devicePixelRatio = 2.25;
    tester.view.physicalSize = const Size(923, 2000);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);

    final couple = CoupleModel.fromMap({
      'coupleId': 'c1',
      'ownerUid': 'u1',
      'partnerUid': 'u2',
      'inviteCode': 'ABC123',
      'isLinked': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
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
    expect(find.text('음력 1월 1일'), findsOneWidget);
  });
}
