import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/fs_error_observer.dart'; // [임시 진단]
import 'core/router/app_router.dart';
import 'data/firebase/firebase_options.dart';
import 'data/firebase/account_repository.dart';
import 'data/notifications/notification_service.dart';
import 'data/notifications/fcm_service.dart';
import 'data/background/background_tasks.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is optional at boot: if config/network is missing, the app still
  // runs (with local state) instead of crashing.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {/* run without backend */}
  await NotificationService.init();

  // Server push (선생님↔학생). Safe no-op without native FCM config.
  if (!kIsWeb && Firebase.apps.isNotEmpty) {
    try {
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
      await FcmService.init();
      // 이미 로그인돼 있으면 기기 토큰을 서버에 동기화.
      await FcmService.syncToken(AccountRepository());
    } catch (_) {/* FCM unavailable */}
  }

  // Daily background life check (off-app). Android: WorkManager; iOS: BGTask
  // (opportunistic). No-op on web.
  if (!kIsWeb) {
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        kLifeCheckTask,
        kLifeCheckTask,
        frequency: const Duration(hours: 24),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (_) {/* background scheduling unavailable */}
  }

  // First-run gating: show onboarding only until it's completed once.
  bool onboarded = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool('hasOnboarded') ?? false;
  } catch (_) {}

  runApp(ProviderScope(
    observers: [FsErrorObserver()], // [임시 진단] permission-denied provider 추적
    overrides: [onboardedProvider.overrideWithValue(onboarded)],
    child: const OclApp(),


  ));
}
