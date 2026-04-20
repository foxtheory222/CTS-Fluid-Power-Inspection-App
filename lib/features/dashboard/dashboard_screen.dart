import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/workspace_models.dart';
import '../../core/workspace_providers.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(workspaceProvider);
    final metrics = controller.dashboardMetrics;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroBanner(
            onNewInspection: () => context.go('/inspection/new'),
            onOpenInspections: () => context.go('/inspections'),
            onOpenActions: () => context.go('/actions'),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 1180;
              return twoColumn
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _MetricsSection(metrics: metrics)),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 360,
                          child: _CriticalReportsPanel(
                            inspections: controller.recentInspections,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _MetricsSection(metrics: metrics),
                        const SizedBox(height: 18),
                        _CriticalReportsPanel(
                          inspections: controller.recentInspections,
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180;
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _RecentInspectionsPanel(
                            inspections: controller.recentInspections,
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Expanded(child: _QuickActionsPanel()),
                      ],
                    )
                  : Column(
                      children: [
                        _RecentInspectionsPanel(
                          inspections: controller.recentInspections,
                        ),
                        const SizedBox(height: 18),
                        const _QuickActionsPanel(),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.onNewInspection,
    required this.onOpenInspections,
    required this.onOpenActions,
  });

  final VoidCallback onNewInspection;
  final VoidCallback onOpenInspections;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CtsPalette.navyAlt, CtsPalette.navy, Color(0xFF132944)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Fast access to draft, in-progress, complete, and emailed inspections from a clean tablet layout built for field work.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: onNewInspection,
                      icon: const Icon(Icons.add),
                      label: const Text('New Inspection'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenInspections,
                      icon: const Icon(Icons.search),
                      label: const Text('Browse Inspections'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenActions,
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      label: const Text('Action Items'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 280,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current focus',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const StatusBadge(
                  label: 'Critical reports require LOTO acknowledgement',
                  color: CtsPalette.danger,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 12),
                Text(
                  'All records stay on-device. PDF export, share, and email handoff are available without an online workflow.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsSection extends StatelessWidget {
  const _MetricsSection({required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 144,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: metric.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(metric.icon, color: metric.color),
                    ),
                    const Spacer(),
                    Text(
                      metric.value,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  metric.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CriticalReportsPanel extends StatelessWidget {
  const _CriticalReportsPanel({required this.inspections});

  final List<InspectionSummary> inspections;

  @override
  Widget build(BuildContext context) {
    final critical = inspections
        .where((item) => item.criticalCount > 0)
        .toList(growable: false);
    return SectionCard(
      title: 'Critical Reports',
      subtitle:
          'Flagged reports that need LOTO attention and customer follow-up.',
      trailing: StatusBadge(
        label: '${critical.length} critical',
        color: CtsPalette.danger,
        icon: Icons.warning_amber_rounded,
        tight: true,
      ),
      child: Column(
        children: [
          if (critical.isEmpty)
            _EmptyPanel(
              title: 'No critical inspections',
              body:
                  'The current dashboard set has no Critical / Out of Service reports.',
              icon: Icons.verified_outlined,
            )
          else
            ...critical.map(
              (inspection) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InspectionMiniCard(inspection: inspection),
              ),
            ),
        ],
      ),
    );
  }
}

class _InspectionMiniCard extends StatelessWidget {
  const _InspectionMiniCard({required this.inspection});

  final InspectionSummary inspection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    inspection.customer,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge.forInspection(inspection.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              inspection.assetName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 320;
                final updatedText = Text(
                  DateFormat('MMM d, h:mm a').format(inspection.lastUpdatedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: CtsPalette.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${inspection.criticalCount} critical item${inspection.criticalCount == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: CtsPalette.danger,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      updatedText,
                    ],
                  );
                }

                return Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: CtsPalette.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${inspection.criticalCount} critical item${inspection.criticalCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: CtsPalette.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    updatedText,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentInspectionsPanel extends StatelessWidget {
  const _RecentInspectionsPanel({required this.inspections});

  final List<InspectionSummary> inspections;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recent Inspections',
      subtitle: 'Most recently updated records.',
      child: Column(
        children: [
          for (final inspection in inspections) ...[
            _RecentInspectionRow(
              inspection: inspection,
              onOpen: () => context.go('/inspection/${inspection.id}'),
            ),
            if (inspection != inspections.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _RecentInspectionRow extends StatelessWidget {
  const _RecentInspectionRow({required this.inspection, required this.onOpen});

  final InspectionSummary inspection;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inspection.customer,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${inspection.documentNumber} · ${inspection.workOrderNumber}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge.forInspection(inspection.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                inspection.assetName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStat(
                    icon: Icons.photo_library_outlined,
                    value: inspection.photoCount.toString(),
                    label: 'Photos',
                  ),
                  _MiniStat(
                    icon: Icons.assignment_turned_in_outlined,
                    value: inspection.actionItems.length.toString(),
                    label: 'Actions',
                  ),
                  _MiniStat(
                    icon: Icons.warning_amber_rounded,
                    value: inspection.flaggedCount.toString(),
                    label: 'Flags',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CtsPalette.orange),
          const SizedBox(width: 8),
          Text(
            '$value $label',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick Actions',
      subtitle: 'Common tablet shortcuts for field work.',
      child: Column(
        children: [
          _ActionButton(
            icon: Icons.add_circle_outline,
            title: 'Start new inspection',
            subtitle: 'Open the full inspection editor.',
            onTap: () => context.go('/inspection/new'),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.search_outlined,
            title: 'Search inspections',
            subtitle: 'Find by customer, work order, or document number.',
            onTap: () => context.go('/inspections'),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Review action items',
            subtitle: 'See auto-generated and manual follow-up items.',
            onTap: () => context.go('/actions'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CtsPalette.orange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: CtsPalette.orange),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CtsPalette.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: CtsPalette.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
