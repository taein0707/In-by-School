import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/account_repository.dart';
import '../domain/account/user_profile.dart';
import '../domain/account/notif_prefs.dart';
import '../domain/notification/app_notification.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository());

/// 로그인 상태 변화(익명→이메일, 로그아웃) — 프로필 구독을 다시 트는 트리거.
final authStateProvider = StreamProvider<User?>((ref) {
  if (Firebase.apps.isEmpty) return const Stream.empty();
  return FirebaseAuth.instance.authStateChanges();
});

/// 현재 사용자 프로필(역할). null = 무소속 일반 학생(익명/미설정)으로 취급.
/// 인증이 바뀌면 authStateProvider 를 watch 해 자동 재구독한다.
final currentProfileProvider = StreamProvider<UserProfile?>((ref) {
  ref.watch(authStateProvider);
  if (Firebase.apps.isEmpty) return Stream.value(null);
  return ref.watch(accountRepositoryProvider).watchProfile();
}, name: 'currentProfileProvider users/{uid}');

/// 편의 — 동기 접근(없으면 null). 라우팅 redirect 등에서 사용.
final currentRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(currentProfileProvider).value?.role;
});

/// 로그인하면 본인 userEmails 인덱스를 백필(검색 가능하도록) — P9 #8.
/// 어딘가에서 watch 되어야 활성화된다(앱 루트에서 watch).
final emailIndexBackfillProvider = Provider<void>((ref) {
  if (Firebase.apps.isEmpty) return;
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user != null) {
    // fire-and-forget — 멱등(merge), 실패는 내부에서 흡수.
    ref.read(accountRepositoryProvider).ensureEmailIndex();
  }
});

/// 내 알림함.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(const []);
  if (ref.watch(authStateProvider).value == null) return Stream.value(const []);
  return ref.watch(accountRepositoryProvider).watchNotifications();
}, name: 'notificationsProvider notifications.where(toUid==uid)');

/// 알림 수신 설정(본인 전용).
final notifPrefsProvider = StreamProvider<NotifPrefs>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(const NotifPrefs());
  if (ref.watch(authStateProvider).value == null) return Stream.value(const NotifPrefs());
  return ref.watch(accountRepositoryProvider).watchNotifPrefs();
}, name: 'notifPrefsProvider users/{uid}/private/settings');
