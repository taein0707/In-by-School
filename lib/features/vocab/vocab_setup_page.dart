import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ocr/ocr_service.dart';
import '../../domain/vocab/vocab_word.dart';
import '../../shared/widgets/ui.dart';

/// 영단어 외우기 — 사진(OCR) 또는 직접 입력으로 단어를 모아 덱을 만든다.
class VocabSetupPage extends StatefulWidget {
  const VocabSetupPage({super.key});
  @override
  State<VocabSetupPage> createState() => _VocabSetupPageState();
}

class _VocabSetupPageState extends State<VocabSetupPage> {
  final _deck = <VocabWord>[];
  final _input = TextEditingController(text: 'abandon\t포기하다\nanalyze\t분석하다');
  bool _typing = false;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _scan(ImageSource src) async {
    setState(() => _busy = true);
    final words = await OcrService.scanWords(src);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (words.isNotEmpty) _deck..clear()..addAll(words);
    });
    if (words.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어를 인식하지 못했어요. 직접 입력으로 추가해 보세요.')),
      );
    }
  }

  void _generateFromText() {
    final words = VocabWord.parseLines(_input.text);
    setState(() {
      _deck..clear()..addAll(words);
      _typing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('영단어 외우기', style: AppType.headline2),
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
                children: [
                  const SectionLabel('단어 가져오기'),
                  Row(children: [
                    Expanded(child: _action(c, Icons.photo_camera_outlined, '사진 촬영',
                        OcrService.supported ? () => _scan(ImageSource.camera) : null)),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(child: _action(c, Icons.image_outlined, '갤러리',
                        OcrService.supported ? () => _scan(ImageSource.gallery) : null)),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(child: _action(c, Icons.edit_outlined, '직접 입력',
                        () => setState(() => _typing = !_typing))),
                  ]),
                  if (!OcrService.supported)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s8),
                      child: Text('사진 인식(OCR)은 실기기에서만 동작해요.', style: AppType.caption1.copyWith(color: c.labelAlt)),
                    ),
                  if (_busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                        const SizedBox(width: 10),
                        Text('단어를 읽고 있어요…', style: AppType.body2.copyWith(color: c.labelAlt)),
                      ]),
                    ),
                  if (_typing) ...[
                    const SizedBox(height: AppSpace.s12),
                    Text('한 줄에 하나씩 "단어  뜻" (탭/쉼표/공백 구분)', style: AppType.caption1.copyWith(color: c.labelAlt)),
                    const SizedBox(height: AppSpace.s8),
                    Container(
                      decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
                      padding: const EdgeInsets.all(AppSpace.s12),
                      child: TextField(
                        controller: _input,
                        maxLines: 6,
                        style: AppType.body2.copyWith(color: c.labelNormal),
                        decoration: const InputDecoration.collapsed(hintText: 'abandon  포기하다'),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    OclButton('단어 생성', ghost: true, onPressed: _generateFromText),
                  ],
                  if (_deck.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s16),
                    SectionLabel('단어 ${_deck.length}개'),
                    ..._deck.take(40).map((w) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Expanded(child: Text(w.term, style: AppType.body1.copyWith(fontWeight: FontWeight.w600))),
                            Expanded(child: Text(w.meaning, style: AppType.body2.copyWith(color: c.labelAlt))),
                          ]),
                        )),
                  ],
                  const SizedBox(height: AppSpace.s24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s24, 0, AppSpace.s24, AppSpace.s12),
              child: OclButton(
                _deck.isEmpty ? '단어를 추가해주세요' : '플래시카드 시작 (${_deck.length}개)',
                onPressed: _deck.isEmpty ? null : () => context.pushReplacement('/vocab/cards', extra: List<VocabWord>.from(_deck)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(AppColors c, IconData icon, String label, VoidCallback? onTap) {
    final on = onTap != null;
    return Material(
      color: c.bgElevated,
      borderRadius: AppRadius.b14,
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
          decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
          child: Column(children: [
            Icon(icon, color: on ? c.accent : c.labelAssistive),
            const SizedBox(height: 6),
            Text(label, style: AppType.label2.copyWith(color: on ? c.labelNeutral : c.labelAssistive)),
          ]),
        ),
      ),
    );
  }
}
