import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Full-width primary CTA — the single main action per screen.
class OclButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool ghost;
  const OclButton(this.label, {super.key, this.onPressed, this.ghost = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: ghost ? c.fill : c.accent,
        borderRadius: AppRadius.b16,
        child: InkWell(
          borderRadius: AppRadius.b16,
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: AppType.headline2.copyWith(color: ghost ? c.labelNeutral : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft elevated surface with a hairline border.
class OclCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const OclCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.bgElevated,
        borderRadius: AppRadius.b16,
        border: Border.all(color: c.lineAlt),
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8, top: AppSpace.s4),
        child: Text(text, style: AppType.label2.copyWith(color: context.c.labelAlt)),
      );
}
