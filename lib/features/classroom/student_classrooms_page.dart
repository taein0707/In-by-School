import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/classroom_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/ui.dart';

/// 학생: 내가 속한 교실 목록 + 코드로 직접 참여(P8 #4).
class StudentClassroomsPage extends ConsumerWidget {
  const StudentClassroomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final memberships = ref.watch(myClassroomsProvider).valueOrNull ?? const [];

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
        onPressed: () => openJoinByCodeSheet(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('교실 참여', style: AppType.label1.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: memberships.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.meeting_room_outlined, size: 48, color: c.labelAssistive),
                    const SizedBox(height: AppSpace.s12),
                    Text('아직 참여한 교실이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
                    const SizedBox(height: 4),
                    Text('선생님께 받은 참여 코드를 입력해보세요.', style: AppType.body2.copyWith(color: c.labelAssistive)),
                    const SizedBox(height: AppSpace.s16),
                    OutlinedButton.icon(
                      onPressed: () => openJoinByCodeSheet(context, ref),
                      icon: Icon(Icons.vpn_key_outlined, size: 18, color: c.accent),
                      label: Text('코드로 참여하기', style: AppType.label1.copyWith(color: c.accent)),
                    ),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: memberships
                    .map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s8),
                          child: InkWell(
                            borderRadius: AppRadius.b16,
                            onTap: () => context.push('/classrooms/${m.classroomId}', extra: m.classroomName),
                            child: OclCard(
                              child: Row(children: [
                                Icon(Icons.meeting_room_outlined, color: c.accent),
                                const SizedBox(width: AppSpace.s12),
                                Expanded(child: Text(m.classroomName.isEmpty ? '교실' : m.classroomName, style: AppType.headline2)),
                                Icon(Icons.chevron_right, color: c.labelAssistive),
                              ]),
                            ),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

/// 코드 입력 → 즉시 참여 시트(승인 불필요). 학생 화면 어디서든 재사용.
void openJoinByCodeSheet(BuildContext context, WidgetRef ref) {
  final codeCtrl = TextEditingController();
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
          Future<void> join() async {
            final code = codeCtrl.text.trim();
            if (code.isEmpty) {
              setSheet(() => err = '참여 코드를 입력해주세요.');
              return;
            }
            setSheet(() {
              busy = true;
              err = null;
            });
            try {
              final name = ref.read(currentProfileProvider).valueOrNull?.displayName ?? '';
              final cls = await ref
                  .read(classroomRepositoryProvider)
                  .joinClassroomByCode(code: code, studentName: name)
                  .timeout(const Duration(seconds: 15));
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(SnackBar(content: Text('${cls.name.isEmpty ? '교실' : cls.name}에 참여했어요!')));
            } on FirebaseException catch (e) {
              setSheet(() {
                busy = false;
                err = e.code == 'not-found' ? '코드에 맞는 교실을 찾지 못했어요.' : '참여하지 못했어요. 잠시 후 다시 시도해주세요.';
              });
            } catch (_) {
              setSheet(() {
                busy = false;
                err = '참여하지 못했어요. 코드를 확인해주세요.';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpace.s20, AppSpace.s20, AppSpace.s20, MediaQuery.of(ctx).viewInsets.bottom + AppSpace.s24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('교실 참여', style: AppType.title3),
              const SizedBox(height: 4),
              Text('선생님께 받은 참여 코드를 입력하면 바로 참여돼요.', style: AppType.body2.copyWith(color: c.labelAlt)),
              const SizedBox(height: AppSpace.s16),
              TextField(
                controller: codeCtrl,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                style: AppType.title3.copyWith(color: c.labelNormal, letterSpacing: 4),
                textAlign: TextAlign.center,
                onSubmitted: (_) => join(),
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  filled: true,
                  fillColor: c.bg,
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
                  focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
                  contentPadding: const EdgeInsets.all(AppSpace.s16),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: AppSpace.s12),
                Text(err!, style: AppType.body2.copyWith(color: c.negative)),
              ],
              const SizedBox(height: AppSpace.s20),
              OclButton(busy ? '참여하는 중…' : '참여하기', onPressed: busy ? null : join),
            ]),
          );
        },
      );
    },
  );
}
