import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/institution/institution_search_service.dart';
import '../../domain/institution/institution.dart';

/// 학교/학원 검색 입력(P9 #1) — TextField + 300ms 디바운스 + 오버레이 결과 목록.
///
/// 선택하면 [onSelected] 로 결과를 알리고, 자유 입력도 그대로 [controller] 에 남는다
/// (검색 결과에 없는 소속도 직접 적을 수 있다).
class InstitutionSearchField extends StatefulWidget {
  final TextEditingController controller;
  final InstitutionKind kind;
  final ValueChanged<Institution> onSelected;
  final String hintText;

  /// 테스트/프록시 주입용 — 미지정 시 기본 NEIS 서비스.
  final InstitutionSearchService? service;

  const InstitutionSearchField({
    super.key,
    required this.controller,
    required this.kind,
    required this.onSelected,
    this.hintText = '이름으로 검색',
    this.service,
  });

  @override
  State<InstitutionSearchField> createState() => _InstitutionSearchFieldState();
}

class _InstitutionSearchFieldState extends State<InstitutionSearchField> {
  final LayerLink _link = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final FocusNode _focus = FocusNode();
  late final InstitutionSearchService _service;

  Timer? _debounce;
  OverlayEntry? _entry;
  List<Institution> _results = const [];
  bool _loading = false;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? InstitutionSearchService();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      // 결과 탭이 먼저 처리되도록 약간 늦춰 닫는다.
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted && !_focus.hasFocus) _removeOverlay();
      });
    }
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.isEmpty) {
      _results = const [];
      _removeOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_reqId;
    setState(() => _loading = true);
    _showOverlay();
    final res = widget.kind == InstitutionKind.school
        ? await _service.searchSchools(q)
        : await _service.searchAcademies(q);
    if (id != _reqId || !mounted) return;
    setState(() {
      _results = res;
      _loading = false;
    });
    _entry?.markNeedsBuild();
  }

  void _select(Institution inst) {
    widget.controller.text = inst.name;
    widget.controller.selection = TextSelection.collapsed(offset: inst.name.length);
    widget.onSelected(inst);
    _removeOverlay();
    _focus.unfocus();
  }

  void _showOverlay() {
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final c = this.context.c;
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 280;
    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: Material(
          elevation: 4,
          borderRadius: AppRadius.b14,
          color: c.bgElevated,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: _overlayBody(c),
          ),
        ),
      ),
    );
  }

  Widget _overlayBody(AppColors c) {
    if (_loading && _results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
          const SizedBox(width: AppSpace.s12),
          Text('검색 중…', style: AppType.body2.copyWith(color: c.labelAlt)),
        ]),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Text('검색 결과가 없어요. 직접 입력해도 돼요.', style: AppType.body2.copyWith(color: c.labelAlt)),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: c.lineAlt),
      itemBuilder: (_, i) {
        final inst = _results[i];
        return InkWell(
          onTap: () => _select(inst),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inst.name, style: AppType.body1.copyWith(color: c.labelNormal)),
              if (inst.detail.isNotEmpty)
                Text(inst.detail, style: AppType.caption1.copyWith(color: c.labelAlt)),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CompositedTransformTarget(
      link: _link,
      child: TextField(
        key: _fieldKey,
        controller: widget.controller,
        focusNode: _focus,
        onChanged: _onChanged,
        autocorrect: false,
        enableSuggestions: false,
        style: AppType.body1.copyWith(color: c.labelNormal),
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(Icons.search, size: 20, color: c.labelAlt),
          suffixIcon: _loading
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                )
              : null,
          filled: true,
          fillColor: c.bgElevated,
          enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
          focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s16),
        ),
      ),
    );
  }
}
