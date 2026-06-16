import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/vocab/vocab_word.dart';
import '../../shared/widgets/ui.dart';

/// 플래시카드 — 앞면(단어) 탭하면 뒤집어 뜻 확인 → 알아요/몰라요.
class FlashcardPage extends StatefulWidget {
  final List<VocabWord> deck;
  const FlashcardPage({super.key, required this.deck});
  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  int _i = 0;
  bool _flipped = false;
  int _correct = 0;
  final _weak = <VocabWord>[];
  final DateTime _start = DateTime.now();

  void _answer(bool known) {
    final w = widget.deck[_i];
    if (known) {
      _correct++;
    } else {
      _weak.add(w);
    }
    if (_i + 1 >= widget.deck.length) {
      final mins = DateTime.now().difference(_start).inMinutes;
      final result = VocabResult(
        total: widget.deck.length,
        correct: _correct,
        weak: _weak,
        focusedMin: mins < 1 ? 1 : mins,
      );
      context.pushReplacement('/vocab/result', extra: result);
    } else {
      setState(() {
        _i++;
        _flipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = widget.deck[_i];
    final progress = (_i + 1) / widget.deck.length;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('${_i + 1} / ${widget.deck.length}', style: AppType.headline2),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: AppRadius.bFull,
                child: LinearProgressIndicator(
                  value: progress, minHeight: 6, backgroundColor: c.fillStrong,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _flipped = !_flipped),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: FadeTransition(opacity: anim, child: child)),
                  child: Container(
                    key: ValueKey(_flipped),
                    width: double.infinity,
                    height: 280,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(AppSpace.s24),
                    decoration: BoxDecoration(
                      color: _flipped ? c.accentSoft : c.bgElevated,
                      borderRadius: AppRadius.b24,
                      border: Border.all(color: _flipped ? c.accent.withValues(alpha: 0.4) : c.lineAlt),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_flipped ? '뜻' : '단어', style: AppType.label2.copyWith(color: c.labelAlt)),
                        const SizedBox(height: AppSpace.s12),
                        Text(_flipped ? w.meaning : w.term,
                            textAlign: TextAlign.center,
                            style: (_flipped ? AppType.title2 : AppType.display3).copyWith(color: c.labelNormal)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Text('카드를 탭하면 뒤집혀요', style: AppType.caption1.copyWith(color: c.labelAssistive)),
              const Spacer(),
              Row(children: [
                Expanded(child: OclButton('몰라요', ghost: true, onPressed: () => _answer(false))),
                const SizedBox(width: AppSpace.s10),
                Expanded(child: OclButton('알아요', onPressed: () => _answer(true))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
