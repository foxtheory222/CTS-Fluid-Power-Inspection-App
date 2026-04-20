import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/inspection_enums.dart';

class ConditionSelector extends StatelessWidget {
  const ConditionSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final ConditionRating? value;
  final ValueChanged<ConditionRating> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ConditionRating>(
      segments: const [
        ButtonSegment(
          value: ConditionRating.satisfactory,
          label: Text('Satisfactory'),
          icon: Icon(Icons.check_circle_outline),
        ),
        ButtonSegment(
          value: ConditionRating.monitorAtRisk,
          label: Text('At Risk'),
          icon: Icon(Icons.visibility_outlined),
        ),
        ButtonSegment(
          value: ConditionRating.unsatisfactory,
          label: Text('Unsatisfactory'),
          icon: Icon(Icons.error_outline),
        ),
        ButtonSegment(
          value: ConditionRating.criticalOutOfService,
          label: Text('Critical'),
          icon: Icon(Icons.warning_amber_rounded),
        ),
      ],
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(compact ? 120 : 0, compact ? 48 : 54),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CtsPalette.orange.withValues(alpha: 0.18);
          }
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CtsPalette.orange;
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? CtsPalette.orange
              : Theme.of(context).colorScheme.outlineVariant;
          return BorderSide(color: color);
        }),
      ),
      selected: value == null ? <ConditionRating>{} : {value!},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
