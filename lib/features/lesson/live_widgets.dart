import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/lesson/lesson.dart';
import '../../domain/lesson/live.dart';

/// 슬라이드 유형 → 라이브 집계를 저장/구독할 컬렉션(없으면 null).
String? tallyCollectionFor(LessonSlideType type) {
  if (type == LessonSlideType.wordCloud || type == LessonSlideType.keyword) return 'lessonWordCloud';
  if (type == LessonSlideType.livePoll || type == LessonSlideType.multipleChoice || type == LessonSlideType.ox) {
    return 'lessonVotes';
  }
  return null;
}

/// 워드클라우드 — 빈도가 높을수록 크게(교사/학생 공용).
class LiveWordCloud extends StatelessWidget {
  final Map<String, int> counts;
  const LiveWordCloud(this.counts, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ranked = LiveAggregate.top(counts);
    if (ranked.isEmpty) return _waiting(c, '단어를 기다리는 중…');
    final maxN = ranked.first.value;
    return Wrap(
      spacing: AppSpace.s12,
      runSpacing: AppSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final e in ranked)
          Text(
            e.key,
            style: TextStyle(
              fontFamily: AppType.family,
              fontWeight: FontWeight.w700,
              color: c.accent,
              fontSize: 16 + 28 * (e.value / maxN),
            ),
          ),
      ],
    );
  }
}

/// 투표/선택 결과 막대(교사/학생 공용).
class LiveTallyBars extends StatelessWidget {
  final Map<String, int> counts;
  const LiveTallyBars(this.counts, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ranked = LiveAggregate.top(counts);
    if (ranked.isEmpty) return _waiting(c, '응답을 기다리는 중…');
    final total = ranked.fold<int>(0, (a, e) => a + e.value);
    return Column(
      children: [
        for (final e in ranked)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key, style: AppType.body2.copyWith(color: c.labelNormal))),
                Text('${e.value}명 · ${(e.value * 100 / total).round()}%', style: AppType.caption1.copyWith(color: c.labelAlt)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: AppRadius.bFull,
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : e.value / total,
                  minHeight: 8,
                  backgroundColor: c.fillStrong,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

Widget _waiting(AppColors c, String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s24),
      decoration: BoxDecoration(color: c.bgAlt, borderRadius: AppRadius.b14),
      child: Center(child: Text(text, style: AppType.body2.copyWith(color: c.labelAlt))),
    );

/// 포스트잇 색.
Color postitColor(String name) => switch (name) {
      'pink' => const Color(0xFFFFD6E0),
      'blue' => const Color(0xFFCFE3FF),
      'green' => const Color(0xFFD7F2D9),
      'orange' => const Color(0xFFFFE3C2),
      _ => const Color(0xFFFFF3B0), // yellow
    };

const List<String> kReactionEmojis = ['👍', '❤️', '⭐', '👏'];
const List<String> kPostitColors = ['yellow', 'pink', 'blue', 'green', 'orange'];

/// 아이디어보드(P10-4) — 포스트잇을 좌표(0..1)에 배치. 교사는 드래그/메뉴, 학생은 읽기.
/// 좋아요 반응은 양쪽 모두 가능.
class IdeaBoardView extends StatefulWidget {
  final List<LessonIdea> ideas;
  final Map<String, Map<String, int>> reactions;
  final void Function(String targetId, String emoji)? onReact;
  final void Function(String id, double x, double y)? onMove; // 교사 전용(드래그)
  final void Function(LessonIdea idea)? onTapIdea; // 교사 메뉴
  final double height;
  const IdeaBoardView({
    super.key,
    required this.ideas,
    this.reactions = const {},
    this.onReact,
    this.onMove,
    this.onTapIdea,
    this.height = 360,
  });

  @override
  State<IdeaBoardView> createState() => _IdeaBoardViewState();
}

class _IdeaBoardViewState extends State<IdeaBoardView> {
  String? _dragId;
  Offset _dragNorm = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (widget.ideas.isEmpty) return _waiting(c, '학생들의 포스트잇을 기다리는 중…');
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      final h = widget.height;
      return Container(
        height: h,
        decoration: BoxDecoration(color: c.bgAlt, borderRadius: AppRadius.b16, border: Border.all(color: c.lineAlt)),
        clipBehavior: Clip.hardEdge,
        child: Stack(children: [for (final idea in widget.ideas) _postit(c, idea, w, h)]),
      );
    });
  }

  Widget _postit(AppColors c, LessonIdea idea, double w, double h) {
    final dragging = _dragId == idea.id;
    final nx = dragging ? _dragNorm.dx : idea.x;
    final ny = dragging ? _dragNorm.dy : idea.y;
    const pw = 140.0;
    final width = pw * idea.scale;
    final left = (nx * w - width / 2).clamp(0.0, (w - width).clamp(0.0, w));
    final top = (ny * h - 36).clamp(0.0, (h - 72).clamp(0.0, h));
    final counts = widget.reactions[idea.id] ?? const {};

    Widget card = Container(
      width: width,
      padding: const EdgeInsets.all(AppSpace.s10),
      decoration: BoxDecoration(
        color: postitColor(idea.color),
        borderRadius: AppRadius.b12,
        border: idea.groupId.isEmpty ? null : Border.all(color: c.accent, width: 2),
        boxShadow: AppShadow.emphasize,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(idea.text, maxLines: 4, overflow: TextOverflow.ellipsis,
            style: AppType.body2.copyWith(color: const Color(0xFF222222), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text(idea.authorName.isEmpty ? '학생' : idea.authorName, style: AppType.caption2.copyWith(color: const Color(0x99000000)))),
          if (idea.locked) const Icon(Icons.lock, size: 12, color: Color(0x99000000)),
        ]),
        if (widget.onReact != null) ...[
          const SizedBox(height: 2),
          Wrap(spacing: 2, children: [
            for (final e in kReactionEmojis)
              InkWell(
                onTap: () => widget.onReact!(idea.id, e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  child: Text('$e${(counts[e] ?? 0) > 0 ? ' ${counts[e]}' : ''}', style: const TextStyle(fontSize: 12)),
                ),
              ),
          ]),
        ],
      ]),
    );

    if (widget.onMove != null && !idea.locked) {
      card = GestureDetector(
        onTap: () => widget.onTapIdea?.call(idea),
        onPanStart: (_) => setState(() {
          _dragId = idea.id;
          _dragNorm = Offset(idea.x, idea.y);
        }),
        onPanUpdate: (d) => setState(() {
          _dragNorm = Offset(
            (_dragNorm.dx + d.delta.dx / w).clamp(0.0, 1.0),
            (_dragNorm.dy + d.delta.dy / h).clamp(0.0, 1.0),
          );
        }),
        onPanEnd: (_) {
          widget.onMove!(idea.id, _dragNorm.dx, _dragNorm.dy);
          setState(() => _dragId = null);
        },
        child: card,
      );
    } else if (widget.onTapIdea != null) {
      card = GestureDetector(onTap: () => widget.onTapIdea!(idea), child: card);
    }

    return Positioned(left: left, top: top, child: Transform.rotate(angle: idea.rotation, child: card));
  }
}

Color pointerColor(String name) => switch (name) {
      'red' => const Color(0xFFFF3B30),
      'blue' => const Color(0xFF0A84FF),
      'laser' => const Color(0xFFFF2D55),
      _ => const Color(0xFFFFC400), // yellow
    };

/// 슬라이드 영역 위에 교사 포인터를 겹쳐 그린다(학생/교사 공용).
/// 좌표는 0..1 정규화 → 영역 크기에 맞춰 위치. 비활성이면 부드럽게 사라진다.
class LivePointerLayer extends StatelessWidget {
  final LessonPointer? pointer;
  final Widget child;
  const LivePointerLayer({super.key, required this.pointer, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final h = cons.hasBoundedHeight ? cons.maxHeight : 280.0;
        final p = pointer;
        return Stack(
          children: [
            child,
            if (p != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                left: (p.x * w) - 24,
                top: (p.y * h) - 24,
                child: AnimatedOpacity(
                  opacity: p.active ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: _Ripple(color: pointerColor(p.color)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Ripple extends StatefulWidget {
  final Color color;
  const _Ripple({required this.color});

  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                // 퍼지는 파동
                Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0) * 0.6,
                  child: Container(
                    width: 16 + 32 * t,
                    height: 16 + 32 * t,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 2)),
                  ),
                ),
                // 가운데 점
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 8)],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
