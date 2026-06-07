import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/notification_service.dart';

// 백그라운드 FCM 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 백그라운드 수신 — 필요 시 로컬 알림 표시 가능
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
    return MaterialApp.router(
      title: 'CoyHouse Calendar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF48FB1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
