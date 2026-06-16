import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/account_providers.dart';
import '../../app/presence_providers.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/presence/presence_tracker.dart';
import '../../data/webrtc/screen_broadcaster.dart';
import '../../domain/account/user_profile.dart';
import '../../domain/presence/student_presence.dart';

/// P6 — 앱 전역을 감싸는 학생 참여 추적 스코프(웹 전용).
/// 학생이면서 웹(폭 >=700)일 때만 추적기를 켜고 presence 를 기록한다.
/// 화면 공유 요청이 오면 동의 오버레이를 띄운다(허가 우선 — 동의해야 캡처).
/// 모바일/비-웹/교사에서는 [child] 를 그대로 통과시킨다(기능 영향 없음).
class StudentPresenceScope extends ConsumerStatefulWidget {
  final Widget child;
  const StudentPresenceScope({super.key, required this.child});

  @override
  ConsumerState<StudentPresenceScope> createState() => _StudentPresenceScopeState();
}

class _StudentPresenceScopeState extends ConsumerState<StudentPresenceScope> {
  PresenceTracker? _tracker;
  ScreenBroadcaster? _broadcaster;
  Timer? _heartbeat;
  bool _started = false;
  bool _broadcasting = false;
  String? _sessionId;
  int _awayCount = 0;
  StudentPresence _last = StudentPresence.active;

  bool get _sharing => _broadcasting;

  void _start() {
    if (_started) return;
    _started = true;
    _last = StudentPresence.active;
    final tracker = createPresenceTracker();
    _tracker = tracker;
    tracker.start(_onPresence);
    ref.read(presenceRepositoryProvider).writePresence(status: StudentPresence.active);
    _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      ref
          .read(presenceRepositoryProvider)
          .writePresence(status: _broadcasting ? StudentPresence.screenSharing : _last);
    });
  }

  void _stop() {
    if (!_started) return;
    _started = false;
    if (_broadcasting) _endSharing();
    _heartbeat?.cancel();
    _heartbeat = null;
    _tracker?.dispose();
    _tracker = null;
    ref.read(presenceRepositoryProvider).writePresence(status: StudentPresence.offline);
  }

  // 화면 공유 중에는 탭 전환/무입력과 무관하게 screenSharing 유지(상태만 추적).
  void _onPresence(StudentPresence s) {
    if (_broadcasting) {
      _last = s;
      return;
    }
    final repo = ref.read(presenceRepositoryProvider);
    if (s == StudentPresence.away && _last != StudentPresence.away) {
      _awayCount += 1;
      repo.writePresence(status: s, awayCount: _awayCount, lastAwayAt: DateTime.now());
    } else {
      repo.writePresence(status: s);
    }
    _last = s;
  }

  Future<void> _accept(ScreenShareRequest req) async {
    final presence = ref.read(presenceRepositoryProvider);
    final webrtc = ref.read(webrtcRepositoryProvider);
    _broadcaster ??= createScreenBroadcaster();
    await webrtc.createSession(sessionId: req.id, teacherUid: req.teacherUid, studentUid: req.studentUid);
    final ok = await _broadcaster!.start(
      repo: webrtc,
      sessionId: req.id,
      teacherUid: req.teacherUid,
      studentUid: req.studentUid,
      onEnded: _endSharing,
    );
    await presence.respondShareRequest(req.id, accept: ok);
    if (ok) {
      _broadcasting = true;
      _sessionId = req.id;
      presence.writePresence(status: StudentPresence.screenSharing);
      if (mounted) setState(() {});
    } else {
      await webrtc.closeSession(req.id);
    }
  }

  Future<void> _reject(ScreenShareRequest req) =>
      ref.read(presenceRepositoryProvider).respondShareRequest(req.id, accept: false);

  // 학생이 공유를 끝냄(중단 버튼 또는 브라우저 '공유 중지' 자동 감지).
  void _endSharing() {
    if (!_broadcasting) return;
    _broadcasting = false;
    final sessionId = _sessionId;
    _sessionId = null;
    _broadcaster?.stop();
    if (sessionId != null) ref.read(webrtcRepositoryProvider).closeSession(sessionId);
    ref.read(presenceRepositoryProvider).writePresence(status: _last);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isStudent = profile?.role == UserRole.student;
    final webActive = kIsWeb && MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final activeNow = isStudent && webActive;

    if (activeNow != _started) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (activeNow) {
          _start();
        } else {
          _stop();
        }
      });
    }

    if (!activeNow) return widget.child;

    final incoming = ref.watch(incomingShareRequestsProvider).valueOrNull ?? const [];
    final pending = incoming.where((r) => r.status == ScreenShareStatus.pending).toList();
    final req = pending.isEmpty ? null : pending.first;

    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_sharing) Positioned(top: 0, left: 0, right: 0, child: _SharingBanner(onStop: _endSharing)),
        if (req != null && !_sharing)
          _ConsentOverlay(onAllow: () => _accept(req), onDeny: () => _reject(req)),
      ],
    );
  }
}

/// 화면 공유 동의 오버레이 — 학생 허가 우선.
class _ConsentOverlay extends StatelessWidget {
  final Future<void> Function() onAllow;
  final Future<void> Function() onDeny;
  const _ConsentOverlay({required this.onAllow, required this.onDeny});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      children: [
        const Positioned.fill(child: ModalBarrier(color: Colors.black54, dismissible: false)),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: c.bgElevated,
              borderRadius: AppRadius.b20,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.screen_share_outlined, size: 40, color: c.accent),
                    const SizedBox(height: AppSpace.s12),
                    Text('화면 공유 요청', textAlign: TextAlign.center, style: AppType.heading2),
                    const SizedBox(height: AppSpace.s8),
                    Text('선생님이 화면 공유를 요청했습니다.',
                        textAlign: TextAlign.center, style: AppType.body2.copyWith(color: c.labelAlt)),
                    const SizedBox(height: AppSpace.s20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onDeny(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.labelNeutral,
                            side: BorderSide(color: c.line),
                            padding: const EdgeInsets.symmetric(vertical: AppSpace.s14),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.b14),
                          ),
                          child: const Text('거절'),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => onAllow(),
                          style: FilledButton.styleFrom(
                            backgroundColor: c.accent,
                            padding: const EdgeInsets.symmetric(vertical: AppSpace.s14),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.b14),
                          ),
                          child: const Text('허용'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 화면 공유 중 상단 배너.
class _SharingBanner extends StatelessWidget {
  final VoidCallback onStop;
  const _SharingBanner({required this.onStop});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.accent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
          child: Row(children: [
            const Text('📺', style: TextStyle(fontSize: 16)),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text('선생님에게 화면을 공유하고 있어요.',
                  style: AppType.label1.copyWith(color: Colors.white)),
            ),
            TextButton(
              onPressed: onStop,
              child: Text('공유 중단', style: AppType.label1.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}
