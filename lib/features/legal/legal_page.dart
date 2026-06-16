import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'legal_content.dart';

/// 법적 문서 뷰어 — Markdown 기반(번들 템플릿) + URL 기반(원격) 둘 다 지원.
///
/// `LEGAL_BASE_URL` 이 설정되면 `$base/<remoteFile>` 에서 Markdown 을 받아 표시하고,
/// 실패하거나 미설정이면 앱에 번들된 템플릿 초안을 표시한다.
///   flutter build apk --dart-define=LEGAL_BASE_URL=https://example.com/legal
class LegalPage extends StatefulWidget {
  final String docKey; // 'privacy' | 'terms'
  const LegalPage({super.key, required this.docKey});

  static const String baseUrl = String.fromEnvironment('LEGAL_BASE_URL');

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  String? _text;

  @override
  void initState() {
    super.initState();
    _load();
  }

  LegalDoc get _doc => kLegalDocs[widget.docKey] ?? const LegalDoc('문서', '', '');

  Future<void> _load() async {
    final base = LegalPage.baseUrl;
    if (base.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse('$base/${_doc.remoteFile}'))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          setState(() => _text = utf8.decode(res.bodyBytes));
          return;
        }
      } catch (_) {/* 원격 실패 → 번들 폴백 */}
    }
    setState(() => _text = _doc.markdown);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(_doc.title, style: AppType.headline2),
      ),
      body: SafeArea(
        child: _text == null
            ? Center(child: CircularProgressIndicator(color: c.accent))
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s24),
                children: _MarkdownLite.render(context, _text!),
              ),
      ),
    );
  }
}

/// 의존성 없이 Markdown 핵심만 렌더(헤딩·불릿·문단). 법적 문서 표시에 충분.
class _MarkdownLite {
  static List<Widget> render(BuildContext context, String md) {
    final c = context.c;
    final out = <Widget>[];
    for (final raw in md.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        out.add(const SizedBox(height: AppSpace.s10));
      } else if (line.startsWith('# ')) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s8),
          child: Text(line.substring(2), style: AppType.title3.copyWith(fontWeight: FontWeight.w800)),
        ));
      } else if (line.startsWith('## ')) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: AppSpace.s8, bottom: 4),
          child: Text(line.substring(3), style: AppType.headline2),
        ));
      } else if (line.startsWith('- ')) {
        out.add(Padding(
          padding: const EdgeInsets.only(left: AppSpace.s8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('· ', style: AppType.body1.copyWith(color: c.labelAlt)),
              Expanded(child: Text(line.substring(2), style: AppType.body1.copyWith(color: c.labelNeutral))),
            ],
          ),
        ));
      } else {
        out.add(Text(line, style: AppType.body1.copyWith(color: c.labelNeutral)));
      }
    }
    return out;
  }
}
