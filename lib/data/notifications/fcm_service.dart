import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/router/app_router.dart';
import '../firebase/account_repository.dart';

/// FCM(서버 푸시) 클라이언트. 사용자 간 알림(선생님↔학생)은 Cloud Functions 가
/// 데이터 컬렉션 변경(숙제/제출/학습/풀이)을 트리거로 발송한다. 이 클라이언트는:
///   1) 권한 요청 + 기기 토큰을 users/{uid}.fcmTokens 에 저장,
///   2) 포그라운드 수신 시 로컬 알림으로 표시,
///   3) 알림 클릭 시 딥링크(/open?type=&id=)로 상세 화면 이동
///      — 포그라운드/백그라운드/종료(터미네이티드) 3상태 모두 처리.
///
/// 네이티브 설정(google-services.json / APNs)이 없으면 모든 호출은 안전한 no-op.
class FcmService {
  FcmService._();

  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static const _channel = 'ocl_push';
  static bool _ready = false;

  /// 라우터가 아직 준비되기 전에 도착한 (종료 상태) 클릭 경로 보관.
  static String? _pendingRoute;

  /// 앱 시작 시 1회. 권한·로컬 알림·포그라운드/클릭 핸들러를 건다.
  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      // 로컬 알림(포그라운드 표시 + 탭 콜백) 초기화.
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _local.initialize(
        const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: (resp) => _go(resp.payload),
      );
      // 안드로이드 채널 생성(서버 payload 의 channelId 와 일치).
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channel, '푸시 알림',
            description: '선생님·학생 알림',
            importance: Importance.high,
          ));

      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      // 포그라운드 수신 → 로컬 알림으로 표시(payload=딥링크 경로).
      FirebaseMessaging.onMessage.listen(_showForeground);
      // 백그라운드에서 알림 탭으로 앱 복귀 → 즉시 이동.
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _go(_routeFor(m)));
      // 종료 상태에서 알림 탭으로 앱 최초 실행 → 라우터 준비 후 이동.
      final initial = await fm.getInitialMessage();
      if (initial != null) _pendingRoute = _routeFor(initial);

      _ready = true;
    } catch (_) {/* FCM 미설정 — 무시 */}
  }

  /// 로그인(uid 확정) 이후 토큰을 서버에 저장. 갱신도 구독.
  static Future<void> syncToken(AccountRepository repo) async {
    if (kIsWeb) return;
    try {
      final fm = FirebaseMessaging.instance;
      final token = await fm.getToken();
      if (token != null) await repo.saveFcmToken(token);
      fm.onTokenRefresh.listen((t) => repo.saveFcmToken(t));
    } catch (_) {/* 미설정/오프라인 — 무시 */}
  }

  /// 로그아웃/탈퇴 직전 호출(uid 유효할 때) — 현재 기기 토큰을 서버에서 제거하고
  /// 로컬 토큰도 폐기해 다음 로그인 계정과 격리한다(M-1: 오배달 방지).
  static Future<void> clearCurrentToken(AccountRepository repo) async {
    if (kIsWeb) return;
    try {
      final fm = FirebaseMessaging.instance;
      final token = await fm.getToken();
      if (token != null) await repo.removeFcmToken(token);
      await fm.deleteToken();
    } catch (_) {/* 미설정/오프라인 — 무시 */}
  }

  /// 라우터가 만들어진 직후 호출 — 종료 상태에서 들어온 클릭을 흘려보낸다.
  static void flushPendingRoute() {
    final p = _pendingRoute;
    if (p == null) return;
    _pendingRoute = null;
    _go(p);
  }

  /// RemoteMessage.data → 딥링크 경로(/open?type=&id=). 없으면 null.
  static String? _routeFor(RemoteMessage m) {
    final type = m.data['type'];
    final id = m.data['refId'];
    if (type == null || type.toString().isEmpty) return null;
    return Uri(path: '/open', queryParameters: {'type': '$type', 'id': '${id ?? ''}'}).toString();
  }

  /// 경로로 이동. 라우터가 아직 없으면 보류했다 flush 한다.
  static void _go(String? route) {
    if (route == null || route.isEmpty) return;
    final router = rootRouter;
    if (router == null) {
      _pendingRoute = route;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        router.push(route);
      } catch (_) {}
    });
  }

  static Future<void> _showForeground(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    try {
      await _local.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(_channel, '푸시 알림',
              channelDescription: '선생님·학생 알림', importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        payload: _routeFor(msg), // 탭하면 딥링크로 이동.
      );
    } catch (_) {}
  }
}

/// 백그라운드 메시지 핸들러 — 반드시 top-level + vm:entry-point.
/// main() 에서 FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler) 로 등록.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // 시스템이 알림 트레이에 자동 표시하므로 여기선 별도 처리 불필요.
  // 트레이 알림을 탭하면 onMessageOpenedApp / getInitialMessage 가 이동을 담당.
}
