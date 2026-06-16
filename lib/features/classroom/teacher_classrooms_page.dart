import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/classroom_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/classroom/classroom.dart';
import '../../shared/widgets/ui.dart';

/// 교사: 교실 목록 + 생성(P2-0 1단계).
class TeacherClassroomsPage extends ConsumerWidget {
  const TeacherClassroomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final classrooms = ref.watch(teacherClassroomsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('내 교실', style: AppType.headline1),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('교실 만들기', style: AppType.label1.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: classrooms.isEmpty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: classrooms.map((cls) => _classroomCard(context, ref, cls)).toList(),
              ),
      ),
    );
  }

  Widget _classroomCard(BuildContext context, WidgetRef ref, Classroom cls) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: OclCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            borderRadius: AppRadius.b12,
            onTap: () => context.push('/t/classrooms/${cls.id}', extra: cls.name),
            child: Row(children: [
              Icon(Icons.meeting_room_outlined, color: c.accent),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cls.name, style: AppType.headline2),
                  if (cls.description.isNotEmpty)
                    Text(cls.description, style: AppType.body2.copyWith(color: c.labelAlt)),
                ]),
              ),
              Icon(Icons.chevron_right, color: c.labelAssistive),
            ]),
          ),
          const SizedBox(height: AppSpace.s10),
          Divider(height: 1, color: c.lineAlt),
          const SizedBox(height: AppSpace.s8),
          _codeRow(context, ref, cls),
        ]),
      ),
    );
  }

  Widget _codeRow(BuildContext context, WidgetRef ref, Classroom cls) {
    final c = context.c;
    if (cls.joinCode.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            await ref.read(classroomRepositoryProvider).ensureJoinCode(cls);
          },
          icon: Icon(Icons.vpn_key_outlined, size: 18, color: c.accent),
          label: Text('참여 코드 생성', style: AppType.label1.copyWith(color: c.accent)),
        ),
      );
    }
    final link = '${Uri.base.origin}/join?code=${cls.joinCode}';
    return Row(children: [
      Icon(Icons.vpn_key_outlined, size: 18, color: c.labelAlt),
      const SizedBox(width: AppSpace.s8),
      Text('참여 코드', style: AppType.label2.copyWith(color: c.labelAlt)),
      const SizedBox(width: AppSpace.s8),
      Text(cls.joinCode, style: AppType.headline2.copyWith(color: c.labelStrong, letterSpacing: 2)),
      const Spacer(),
      IconButton(
        tooltip: '코드 복사',
        icon: Icon(Icons.copy_outlined, size: 18, color: c.labelNeutral),
        onPressed: () => _copy(context, cls.joinCode, '참여 코드를 복사했어요'),
      ),
      IconButton(
        tooltip: '초대 링크 복사',
        icon: Icon(Icons.link, size: 20, color: c.labelNeutral),
        onPressed: () => _copy(context, link, '초대 링크를 복사했어요'),
      ),
    ]);
  }

  void _copy(BuildContext context, String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.meeting_room_outlined, size: 48, color: c.labelAssistive),
          const SizedBox(height: AppSpace.s12),
          Text('아직 만든 교실이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
          const SizedBox(height: 4),
          Text('오른쪽 아래 버튼으로 첫 교실을 만들어보세요.', style: AppType.body2.copyWith(color: c.labelAssistive)),
        ]),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    // 시트가 닫힌 뒤에도 안내를 띄울 수 있게 페이지의 메신저를 미리 잡아둔다.
    final messenger = ScaffoldMessenger.of(context);
    var busy = false;
    String? err;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadius.r24)),
      builder: (sheetCtx) {
        final c = sheetCtx.c;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            // 생성 — 어떤 경우에도 무한 로딩이 남지 않도록 try/catch/타임아웃으로 감싼다.
            Future<void> submit() async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                setSheet(() => err = '교실 이름을 입력해주세요.');
                return;
              }
              setSheet(() {
                busy = true;
                err = null;
              });
              try {
                await ref
                    .read(classroomRepositoryProvider)
                    .createClassroom(name: name, description: descCtrl.text.trim())
                    .timeout(const Duration(seconds: 15));
                if (ctx.mounted) Navigator.pop(ctx);
              } on TimeoutException {
                // 로컬 캐시에는 이미 저장돼 목록에 표시된다 — 닫고 동기화는 백그라운드로.
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(const SnackBar(content: Text('연결이 느려요. 교실은 목록에 저장됐어요.')));
              } catch (e) {
                if (ctx.mounted) {
                  setSheet(() {
                    busy = false;
                    err = _createError(e);
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s20, AppSpace.s20,
                  MediaQuery.of(ctx).viewInsets.bottom + AppSpace.s24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('교실 만들기', style: AppType.title3),
                const SizedBox(height: AppSpace.s16),
                TextField(controller: nameCtrl, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '교실 이름 (예: 영어 1반)')),
                const SizedBox(height: AppSpace.s12),
                TextField(controller: descCtrl, style: AppType.body1.copyWith(color: c.labelNormal), decoration: _dec(c, '설명 (선택)')),
                if (err != null) ...[
                  const SizedBox(height: AppSpace.s12),
                  Text(err!, style: AppType.body2.copyWith(color: c.negative)),
                ],
                const SizedBox(height: AppSpace.s20),
                OclButton(busy ? '만드는 중…' : '만들기', onPressed: busy ? null : submit),
              ]),
            );
          },
        );
      },
    );
  }

  /// 생성 실패 사유를 사람이 읽을 수 있게 — 권한 문제(규칙 미배포 등)를 분명히 알린다.
  String _createError(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return '교실을 만들 권한이 없어요. 다시 로그인하거나 관리자에게 문의해주세요.';
    }
    return '교실을 만들지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  InputDecoration _dec(AppColors c, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.bg,
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
        contentPadding: const EdgeInsets.all(AppSpace.s16),
      );
}
