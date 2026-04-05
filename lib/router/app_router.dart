import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/invite_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/event/event_form_screen.dart';
import '../screens/event/event_detail_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../models/event_model.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(currentUserModelProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final userModel = ref.read(currentUserModelProvider);

      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      if (!isLoggedIn && !isAuthRoute) return '/login';

      if (isLoggedIn && isAuthRoute) {
        if (userModel.isLoading) return null;
        // 에러 또는 null이면 일단 /invite로 (Firestore 복구 시 자동 재라우팅)
        if (userModel.hasError || userModel.valueOrNull == null) return '/invite';
        final coupleId = userModel.valueOrNull!.coupleId;
        if (coupleId.isEmpty) return '/invite';
        return '/calendar';
      }

      // /invite에 있는데 coupleId가 생기면 /calendar로 이동
      if (isLoggedIn && state.matchedLocation.startsWith('/invite')) {
        if (userModel.isLoading) return null;
        final coupleId = userModel.valueOrNull?.coupleId ?? '';
        if (coupleId.isNotEmpty) return '/calendar';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, _) => const RegisterScreen()),
      GoRoute(path: '/invite', builder: (context, _) => const InviteScreen()),
      GoRoute(path: '/calendar', builder: (context, _) => const CalendarScreen()),
      GoRoute(
        path: '/event/new',
        builder: (_, state) {
          final date = state.extra as DateTime?;
          return EventFormScreen(initialDate: date);
        },
      ),
      GoRoute(
        path: '/event/detail',
        builder: (_, state) {
          final event = state.extra as EventModel;
          return EventDetailScreen(event: event);
        },
      ),
      GoRoute(
        path: '/event/edit',
        builder: (_, state) {
          final event = state.extra as EventModel;
          return EventFormScreen(event: event);
        },
      ),
      GoRoute(path: '/settings', builder: (context, _) => const SettingsScreen()),
    ],
  );
});
