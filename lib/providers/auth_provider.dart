import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'calendar_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);

  // FCM 토큰 수집 및 저장 (Android/iOS 전용)
  _saveFcmTokenIfNeeded(user.uid, ref);

  return ref.watch(firestoreServiceProvider).userStream(user.uid);
});

Future<void> _saveFcmTokenIfNeeded(String uid, Ref ref) async {
  if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ref.read(authServiceProvider).updateFcmToken(uid, token);
    }
  } catch (_) {
    // FCM 토큰 저장 실패는 조용히 무시
  }
}
