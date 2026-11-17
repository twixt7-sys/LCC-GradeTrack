import 'package:lcc_gradetrack/ui.dart';

import '../../core/services/grade_calculator.dart';
import '../../core/theme/format.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/primitives.dart';

/// Compact subject row: code tile, title, scale bar, equivalent and percent.
class SubjectRow extends StatelessWidget {
  const SubjectRow({
    super.key,
    required this.result,
    required this.passing,
    this.onTap,
  });
  final SubjectResult result;
  final double passing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final s = result.subject;
    final color = c.standing(result.standing);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CodeTile(subject: s, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: s.code, style: context.tt.titleSmall),
                        TextSpan(
                          text: '  ${s.title}',
                          style: context.tt.bodySmall,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  ScaleBar(
                    percent: result.percent,
                    passing: passing,
                    color: result.percent == null
                        ? c.faint
                        : (result.percent! < passing
                              ? c.red
                              : subjectColor(s.colorIdx)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Num(
                    result.mark?.code ?? fmtGrade(result.equivalent),
                    size: 16,
                    weight: FontWeight.w700,
                    color: result.mark != null ? c.muted : color,
                  ),
                  const SizedBox(height: 2),
                  Num(
                    result.isFinal ? 'final' : fmtPct(result.percent, dp: 1),
                    size: 11,
                    color: c.muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
