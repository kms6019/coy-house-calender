import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'models/anniversary_model.dart';
import 'models/event_model.dart';
import 'providers/auth_provider.dart' show currentUserModelProvider;
import 'router/app_router.dart';
import 'services/notification_service.dart';
import 'services/samsung_calendar_sync_service.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';

// 백그라운드 FCM 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 상대 일정 변경 푸시 → 앱 안 열어도 삼성캘린더/위젯 동기화
  if (message.data['type'] != 'event_sync') return;
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;
    final userDoc = await db.collection('users').doc(uid).get();
    final coupleId = userDoc.data()?['coupleId'] as String? ?? '';
    if (coupleId.isEmpty) return;

    final snap = await db
        .collection('events')
        .where('coupleId', isEqualTo: coupleId)
        .get();
    final events =
        snap.docs.map((d) => EventModel.fromMap(d.data())).toList();

    final coupleDoc = await db.collection('couples').doc(coupleId).get();
    final anniversaries = (coupleDoc.data()?['anniversaries'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(AnniversaryModel.fromMap)
            .toList() ??
        const <AnniversaryModel>[];

    await SamsungCalendarSyncService().syncAll(events);
    await WidgetService.update(events, anniversaries: anniversaries);
  } catch (_) {
    // 백그라운드 동기화 실패는 조용히 무시 — 다음 앱 실행 때 따라잡음
  }
}

Future<void> _initFcm() async {
  // FCM은 Android/iOS에서만 동작
  if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) return;

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;

  // 알림 권한 요청
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // 포그라운드 메시지 처리
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // 포그라운드에서는 앱이 열려 있으므로 별도 처리 불필요
    // 필요 시 로컬 알림으로 표시 가능
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();
  await _initFcm();
  await initializeDateFormatting('ko_KR');
  runApp(const ProviderScope(child: CoyHouseCalenderApp()));
}

class CoyHouseCalenderApp extends ConsumerWidget {
  const CoyHouseCalenderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    final seedColor = user?.themeSeedColor ?? kPrimaryPurple.toARGB32();
    return MaterialApp.router(
      title: 'CoyHouse Calendar',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(seedColor),
      darkTheme: buildDarkTheme(seedColor),
      themeMode: resolveThemeMode(user?.themeMode ?? 'system'),
      routerConfig: router,
    );
  }
}
