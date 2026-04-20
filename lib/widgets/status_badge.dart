import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/inspection_enums.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.tight = false,
  });

  factory StatusBadge.forInspection(InspectionStatus status) {
    switch (status) {
      case InspectionStatus.draft:
        return const StatusBadge(
          label: 'Draft',
          color: CtsPalette.slate,
          icon: Icons.description_outlined,
        );
      case InspectionStatus.inProgress:
        return const StatusBadge(
          label: 'In Progress',
          color: CtsPalette.orange,
          icon: Icons.play_circle_outline,
        );
      case InspectionStatus.complete:
        return const StatusBadge(
          label: 'Complete',
          color: CtsPalette.success,
          icon: Icons.verified_outlined,
        );
      case InspectionStatus.emailed:
        return const StatusBadge(
          label: 'Emailed',
          color: CtsPalette.info,
          icon: Icons.mark_email_read_outlined,
        );
    }
  }

  factory StatusBadge.forCondition(ConditionRating rating) {
    switch (rating) {
      case ConditionRating.satisfactory:
        return const StatusBadge(
          label: 'Satisfactory',
          color: CtsPalette.success,
          icon: Icons.check_circle_outline,
        );
      case ConditionRating.monitorAtRisk:
        return const StatusBadge(
          label: 'At Risk',
          color: CtsPalette.warning,
          icon: Icons.visibility_outlined,
        );
      case ConditionRating.unsatisfactory:
        return const StatusBadge(
          label: 'Unsatisfactory',
          color: CtsPalette.orange,
          icon: Icons.error_outline,
        );
      case ConditionRating.criticalOutOfService:
        return const StatusBadge(
          label: 'Critical',
          color: CtsPalette.danger,
          icon: Icons.warning_amber_rounded,
        );
    }
  }

  final String label;
  final Color color;
  final IconData? icon;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tight ? 10 : 12,
        vertical: tight ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
