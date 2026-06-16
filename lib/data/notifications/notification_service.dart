import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local/scheduled notifications — NO server. Covers 암기 복습 리마인더
/// (망각곡선 1·3·7일), 골든타임 경고. Live Activities(잠금화면 카운트다운)는
/// 네이티브(iOS WidgetKit + APNs)가 필요해 별도 단계로 둡니다.
///
/// All calls are safe no-ops on web / before init / when permission denied.
class NotificationService {
  NotificationService._();
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _reviewChannel = 'ocl_review';
  static const _lifeChannel = 'ocl_life';
  static const _dailyChannel = 'ocl_daily';

  static const int _dailyId = 700001;
  static const int _evolveId = 700002;
  static const int _goldenId = 911001;
  static const int _goldenLiveId = 911002;
  static const int _studyId = 600001;
  static const int _deathId = 911003;
  static const int _dangerId = 911004;

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {/* fall back to UTC */}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin.initialize(const InitializationSettings(android: android, iOS: darwin));
      _ready = true;
    } catch (_) {/* unsupported platform */}
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb || !_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (_) {}
    return false;
  }

  static NotificationDetails _details(String channel, String name, String desc) => NotificationDetails(
        android: AndroidNotificationDetails(channel, name,
            channelDescription: desc, importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      );

  static int _reviewId(String subject, int i) => ((subject.hashCode & 0x3fffff) * 8 + i) & 0x7fffffff;

  /// 암기 모드 복습 알림 (1·3·7일 뒤 저녁 8시).
  static Future<void> scheduleReviews({
    required String subject,
    required List<DateTime> dates,
    required String spiritName,
  }) async {
    if (kIsWeb || !_ready) return;
    await requestPermission();
    final details = _details(_reviewChannel, '복습 알림', '망각곡선 복습 리마인더');
    for (int i = 0; i < dates.length; i++) {
      final at = DateTime(dates[i].year, dates[i].month, dates[i].day, 20);
      final when = tz.TZDateTime.from(at, tz.local);
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) continue;
      try {
        await _plugin.zonedSchedule(
          _reviewId(subject, i),
          '$spiritName의 복습 알림',
          '$subject 복습할 시간이에요. 기억나는 만큼 떠올려봐요.',
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }

  /// 골든타임 경고 — 사망 후 5일째(만료 2일 전).
  static Future<void> scheduleGoldenWarning({required DateTime diedAt, required String spiritName}) async {
    if (kIsWeb || !_ready) return;
    await requestPermission();
    final at = diedAt.add(const Duration(days: 5));
    final when = tz.TZDateTime.from(at, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    try {
      await _plugin.zonedSchedule(
        _goldenId,
        '$spiritName이(가) 기다리고 있어요',
        '골든타임이 곧 끝나요. 해독제로 깨워줄 수 있어요.',
        when,
        _details(_lifeChannel, '토리 알림', '골든타임·생명 알림'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  static Future<void> cancelGoldenWarning() async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancel(_goldenId);
    } catch (_) {}
  }

  /// 골든타임 라이브 카운트다운 — 잠금화면 상주 알림.
  /// Android: `usesChronometer + chronometerCountDown` 으로 실시간 카운트다운(Live Update).
  /// iOS: ActivityKit Live Activity는 네이티브가 필요해, 여기선 상주 알림(정적)으로 대체.
  static Future<void> showGoldenCountdown({required DateTime deadline, required String spiritName}) async {
    if (kIsWeb || !_ready) return;
    await requestPermission();
    final android = AndroidNotificationDetails(
      _lifeChannel, '토리 알림',
      channelDescription: '골든타임 카운트다운',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: deadline.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
    );
    const ios = DarwinNotificationDetails(presentBanner: false, presentList: true);
    try {
      await _plugin.show(
        _goldenLiveId,
        '$spiritName이(가) 잠들었어요',
        '골든타임이 끝나기 전에 해독제로 깨워주세요.',
        NotificationDetails(android: android, iOS: ios),
      );
    } catch (_) {}
  }

  static Future<void> cancelGoldenCountdown() async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancel(_goldenLiveId);
    } catch (_) {}
  }

  /// 공부 중 진행 타이머 — 잠금화면 상주 카운트업(경과 시간 실시간).
  static Future<void> showStudyTimer({required int startEpochMs, required String label}) async {
    if (kIsWeb || !_ready) return;
    await requestPermission();
    final android = AndroidNotificationDetails(
      _dailyChannel, '학습 타이머',
      channelDescription: '진행 중인 학습 타이머',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: startEpochMs,
      usesChronometer: true, // 기본: 경과 카운트업
    );
    const ios = DarwinNotificationDetails(presentBanner: false, presentList: true);
    try {
      await _plugin.show(_studyId, '공부 중 · $label', '집중하고 있어요', NotificationDetails(android: android, iOS: ios));
    } catch (_) {}
  }

  static Future<void> cancelStudyTimer() async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancel(_studyId);
    } catch (_) {}
  }

  /// 백그라운드 사망 감지 시 — 소리 알림 + 골든타임 상주 카운트다운.
  static Future<void> notifyDeath({required String spiritName, required DateTime deadline}) async {
    if (kIsWeb || !_ready) return;
    await requestPermission();
    try {
      await _plugin.show(
        _deathId,
        '$spiritName이(가) 잠들었어요',
        '각성 계약 목표를 지키지 못했어요. 골든타임 안에 깨워주세요.',
        _details(_lifeChannel, '토리 알림', '생명 알림'),
      );
    } catch (_) {}
    await showGoldenCountdown(deadline: deadline, spiritName: spiritName);
  }

  /// 백그라운드 위험 감지 시 — 경고 알림.
  static Future<void> notifyDanger({required String spiritName, required int health}) async {
    if (kIsWeb || !_ready) return;
    await requestPermission();
    try {
      await _plugin.show(
        _dangerId,
        '$spiritName이(가) 위험해요',
        '오늘 목표를 채우지 않으면 토리가 잠들 수 있어요. (생명 $health)',
        _details(_lifeChannel, '토리 알림', '생명 알림'),
      );
    } catch (_) {}
  }

  static tz.TZDateTime _nextInstanceOf(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// 연속 출석 — 매일 같은 시각 학습 리마인더.
  static Future<void> scheduleDailyReminder({int hour = 20}) async {
    if (kIsWeb || !_ready) return;
    await requestPermission();
    try {
      await _plugin.zonedSchedule(
        _dailyId,
        '오늘도 토리와 함께',
        '잠깐이라도 공부해서 연속 기록을 이어가요.',
        _nextInstanceOf(hour),
        _details(_dailyChannel, '데일리 리마인더', '매일 학습 리마인더'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
      );
    } catch (_) {}
  }

  static Future<void> cancelDailyReminder() async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancel(_dailyId);
    } catch (_) {}
  }

  /// 진화 임박 — 다음 단계가 코앞일 때 내일 아침 알림.
  static Future<void> scheduleEvolutionSoon({required String spiritName, required String nextStage}) async {
    if (kIsWeb || !_ready) return;
    await requestPermission();
    try {
      await _plugin.zonedSchedule(
        _evolveId,
        '$spiritName, 곧 진화해요',
        '조금만 더 공부하면 $nextStage(으)로 진화할 수 있어요.',
        _nextInstanceOf(9),
        _details(_lifeChannel, '토리 알림', '진화·생명 알림'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
