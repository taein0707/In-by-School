import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/classroom_providers.dart';
import '../../app/presence_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/presence/presence_evaluator.dart';
import '../../domain/presence/student_presence.dart';
import '../../shared/widgets/ui.dart';
import 'student_screen_view.dart';

/// 교사: 교실 참여 모니터(P6, 웹 전용) — 학생 실시간 상태 + 화면 보기 요청.
class ActivityMonitorPage extends ConsumerStatefulWidget {
  final String classroomId;
  final String? classroomName;
  const ActivityMonitorPage({super.key, required this.classroomId, this.classroomName});

  @override
  ConsumerState<ActivityMonitorPage> createState() => _ActivityMonitorPageState();
}

class _ActivityMonitorPageState extends ConsumerState<ActivityMonitorPage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // presence 가 갱신되지 않아도 offline(하트비트 만료)을 주기적으로 재평가.
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Color _color(AppColors c, StudentPresence s) => switch (s) {
        StudentPresence.active => c.positive,
        StudentPresence.idle => c.cautionary,
        StudentPresence.away => c.negative,
        StudentPresence.offline => c.labelAssistive,
        StudentPresence.screenSharing => c.accent,
      };

  String _hms(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    final appBar = AppBar(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
      title: Text(widget.classroomName?.isNotEmpty == true ? '${widget.classroomName!} · 참여 모니터' : '참여 모니터',
          style: AppType.headline1),
    );

    if (!kIsWeb) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.desktop_windows_outlined, size: 48, color: c.labelAssistive),
              const SizedBox(height: AppSpace.s12),
              Text('참여 모니터는 웹에서만 사용할 수 있어요.',
                  textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
            ]),
          ),
        ),
      );
    }

    final roster = ref.watch(classroomStudentsProvider(widget.classroomId)).valueOrNull ?? const [];
    final presenceList = ref.watch(classroomPresenceProvider(widget.classroomId)).valueOrNull ?? const [];
    final outgoing = ref.watch(outgoingShareRequestsProvider).valueOrNull ?? const [];
    final now = DateTime.now();

    final presenceByUid = {for (final p in presenceList) p.studentUid: p};
    // 학생별 최신 화면 공유 요청.
    final reqByUid = <String, ScreenShareRequest>{};
    for (final r in outgoing) {
      final cur = reqByUid[r.studentUid];
      if (cur == null || (r.createdAt ?? DateTime(0)).isAfter(cur.createdAt ?? DateTime(0))) {
        reqByUid[r.studentUid] = r;
      }
    }

    // 카운트.
    var active = 0, idle = 0, away = 0, sharing = 0, offline = 0;
    final effByUid = <String, StudentPresence>{};
    for (final m in roster) {
      final p = presenceByUid[m.userUid] ?? Presence(studentUid: m.userUid);
      final eff = effectivePresence(p, now);
      effByUid[m.userUid] = eff;
      switch (eff) {
        case StudentPresence.active:
          active++;
        case StudentPresence.idle:
          idle++;
        case StudentPresence.away:
          away++;
        case StudentPresence.screenSharing:
          sharing++;
        case StudentPresence.offline:
          offline++;
      }
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: appBar,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            OclCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('학생 ${roster.length}명', style: AppType.headline2),
                const SizedBox(height: AppSpace.s12),
                Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: [
                  _stat(c, '🟢 참여중', active, c.positive),
                  _stat(c, '🔴 이탈', away, c.negative),
                  _stat(c, '🟡 비활성', idle, c.cautionary),
                  _stat(c, '📺 화면공유', sharing, c.accent),
                  _stat(c, '⚪ 오프라인', offline, c.labelAssistive),
                ]),
              ]),
            ),
            if (away > 0) ...[
              const SizedBox(height: AppSpace.s12),
              Container(
                padding: const EdgeInsets.all(AppSpace.s14),
                decoration: BoxDecoration(
                  color: c.negative.withValues(alpha: 0.10),
                  borderRadius: AppRadius.b14,
                  border: Border.all(color: c.negative.withValues(alpha: 0.40)),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: c.negative),
                  const SizedBox(width: AppSpace.s10),
                  Expanded(
                    child: Text('$away명이 화면을 이탈했어요.',
                        style: AppType.body2.copyWith(color: c.negative, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: AppSpace.s16),
            if (roster.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
                child: Text('교실에 추가된 학생이 없어요.', style: AppType.body2.copyWith(color: c.labelAlt)),
              )
            else
              ...roster.map((m) {
                final eff = effByUid[m.userUid] ?? StudentPresence.offline;
                final p = presenceByUid[m.userUid];
                final req = reqByUid[m.userUid];
                // 학생이 공유 중이고 요청이 수락됐을 때만 실시간 영상을 띄운다.
                final showVideo = eff == StudentPresence.screenSharing &&
                    req != null &&
                    req.status == ScreenShareStatus.accepted;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _studentRow(c, m.displayName, m.userUid, eff, p, req),
                    if (showVideo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s12),
                        child: studentScreenView(
                          sessionId: req.id,
                          teacherUid: req.teacherUid,
                          studentUid: m.userUid,
                        ),
                      ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _stat(AppColors c, String label, int n, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s8),
      decoration: BoxDecoration(color: c.bgAlt, borderRadius: AppRadius.b12),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: AppType.label2.copyWith(color: c.labelNeutral)),
        const SizedBox(width: 6),
        Text('$n', style: AppType.label1.copyWith(color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _studentRow(AppColors c, String name, String uid, StudentPresence eff, Presence? p, ScreenShareRequest? req) {
    final detail = switch (eff) {
      StudentPresence.away => p?.lastAwayAt != null ? _hms(p!.lastAwayAt!) : '화면 이탈',
      StudentPresence.idle => '입력 없음',
      StudentPresence.screenSharing => '공유 중',
      StudentPresence.offline => '오프라인',
      StudentPresence.active => '참여중',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        child: Row(children: [
          Text(eff.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? '학생' : name, style: AppType.body1.copyWith(color: c.labelNormal)),
              Text('${eff.label} · $detail', style: AppType.caption1.copyWith(color: _color(c, eff))),
            ]),
          ),
          _shareControl(c, uid, eff, req),
        ]),
      ),
    );
  }

  Widget _shareControl(AppColors c, String uid, StudentPresence eff, ScreenShareRequest? req) {
    if (eff == StudentPresence.screenSharing ||
        (req?.status == ScreenShareStatus.accepted)) {
      return Text('공유 중', style: AppType.label2.copyWith(color: c.accent, fontWeight: FontWeight.w700));
    }
    if (req?.status == ScreenShareStatus.pending) {
      return Text('요청 중…', style: AppType.label2.copyWith(color: c.labelAlt));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      TextButton(
        onPressed: () => ref.read(presenceRepositoryProvider).requestScreenShare(uid),
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s4),
        ),
        child: Text('화면 보기 요청', style: AppType.label2.copyWith(color: c.accent)),
      ),
      if (req?.status == ScreenShareStatus.rejected)
        Text('화면 공유 거부', style: AppType.caption2.copyWith(color: c.negative)),
    ]);
  }
}
