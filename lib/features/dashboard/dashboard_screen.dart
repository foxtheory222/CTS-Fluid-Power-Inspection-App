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
    if (controller.isLoading && controller.inspections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final metrics = controller.dashboardMetrics;
    final inspections = controller.recentInspections;
    final critical = inspections
        .where((item) => item.criticalCount > 0)
        .toList(growable: false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewHero(
            criticalCount: critical.length,
            onSearchSubmitted: (String value) {
              controller.setSearchQuery(value);
              context.go('/inspections');
            },
            onNewInspection: () => context.go('/inspection/new'),
            onOpenInspections: () => context.go('/inspections'),
            onOpenActions: () => context.go('/actions'),
          ),
          const SizedBox(height: 18),
          _MetricsSection(metrics: metrics),
          const SizedBox(height: 18),
          if (inspections.isEmpty) ...[
            const _EmptyPanel(
              title: 'No inspections yet',
              body: 'Tap New Inspection to start.',
              icon: Icons.note_add_outlined,
            ),
            const SizedBox(height: 18),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 1100;
              final recentPanel = _RecentInspectionsPanel(
                inspections: inspections,
              );
              final alertPanel = _CriticalReportsPanel(inspections: critical);
              if (twoColumn) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: recentPanel),
                    const SizedBox(width: 18),
                    Expanded(flex: 3, child: alertPanel),
                  ],
                );
              }
              return Column(
                children: [recentPanel, const SizedBox(height: 18), alertPanel],
              );
            },
          ),
          const SizedBox(height: 18),
          const _QuickActionsPanel(),
        ],
      ),
    );
  }
}

class _OverviewHero extends StatelessWidget {
  const _OverviewHero({
    required this.criticalCount,
    required this.onSearchSubmitted,
    required this.onNewInspection,
    required this.onOpenInspections,
    required this.onOpenActions,
  });

  final int criticalCount;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onNewInspection;
  final VoidCallback onOpenInspections;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Colors.white,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1060;
            final summaryCard = _HeroAlertCard(criticalCount: criticalCount);
            final mainContent = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: CtsPalette.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Inspection Operations',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: CtsPalette.steel,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Fluid Power Inspection Reports',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: stacked ? 24 : 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start new inspections, search existing records, and keep PDF reporting moving without leaving the device.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('dashboard_search_field'),
                  onSubmitted: onSearchSubmitted,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search by customer or work order',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      key: const Key('new_inspection_button'),
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
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  mainContent,
                  const SizedBox(height: 18),
                  summaryCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: mainContent),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: summaryCard),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroAlertCard extends StatelessWidget {
  const _HeroAlertCard({required this.criticalCount});

  final int criticalCount;

  @override
  Widget build(BuildContext context) {
    final hasCritical = criticalCount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: CtsPalette.navy,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Critical reports',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasCritical ? criticalCount.toString().padLeft(2, '0') : '00',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontSize: 52,
            ),
          ),
          const SizedBox(height: 8),
          StatusBadge(
            label: hasCritical
                ? '$criticalCount critical report${criticalCount == 1 ? '' : 's'}'
                : 'No critical reports',
            color: hasCritical ? CtsPalette.danger : CtsPalette.secondaryBlue,
            icon: hasCritical
                ? Icons.warning_amber_rounded
                : Icons.verified_outlined,
          ),
          const SizedBox(height: 12),
          Text(
            hasCritical
                ? 'Critical items remain visible from the dashboard so technicians can resolve LOTO-sensitive work first.'
                : 'All records remain ready for PDF generation, technician signoff, and share handoff.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFB7C4D5)),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        return GridView.builder(
          itemCount: metrics.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 192,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: metric.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(metric.icon, color: metric.color),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              metric.label.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              metric.value,
                              style: Theme.of(
                                context,
                              ).textTheme.displaySmall?.copyWith(fontSize: 34),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      metric.subtitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      metric.label,
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
      },
    );
  }
}

class _CriticalReportsPanel extends StatelessWidget {
  const _CriticalReportsPanel({required this.inspections});

  final List<InspectionSummary> inspections;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Critical Alerts',
      subtitle: 'Urgent reports that need immediate attention.',
      child: inspections.isEmpty
          ? const _EmptyPanel(
              title: 'No critical inspections',
              body:
                  'The current inspection set has no Critical / Out of Service reports.',
              icon: Icons.verified_outlined,
            )
          : Column(
              children: [
                for (final inspection in inspections) ...[
                  _InspectionMiniCard(inspection: inspection),
                  if (inspection != inspections.last)
                    const SizedBox(height: 12),
                ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CtsPalette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
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
          const SizedBox(height: 12),
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
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: CtsPalette.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM d, h:mm a').format(inspection.lastUpdatedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
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
      child: inspections.isEmpty
          ? const _EmptyPanel(
              title: 'No inspections yet',
              body: 'Tap New Inspection to start.',
              icon: Icons.note_add_outlined,
            )
          : Column(
              children: [
                for (final inspection in inspections) ...[
                  _RecentInspectionRow(
                    inspection: inspection,
                    onOpen: () => context.go('/inspection/${inspection.id}'),
                  ),
                  if (inspection != inspections.last)
                    const SizedBox(height: 12),
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
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CtsPalette.surfaceAlt,
          borderRadius: BorderRadius.circular(22),
        ),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: CtsPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CtsPalette.secondaryBlue),
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
      subtitle: 'Common field shortcuts for technicians.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1200
              ? 3
              : constraints.maxWidth >= 720
              ? 2
              : 1;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: columns == 1 ? 3.6 : 2.6,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            children: [
              _ActionButton(
                icon: Icons.add_circle_outline,
                title: 'Start new inspection',
                subtitle: 'Open the full inspection editor.',
                onTap: () => context.go('/inspection/new'),
              ),
              _ActionButton(
                icon: Icons.search_outlined,
                title: 'Search inspections',
                subtitle: 'Find by customer, work order, or document number.',
                onTap: () => context.go('/inspections'),
              ),
              _ActionButton(
                icon: Icons.assignment_turned_in_outlined,
                title: 'Review action items',
                subtitle: 'See auto-generated and manual follow-up items.',
                onTap: () => context.go('/actions'),
              ),
            ],
          );
        },
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CtsPalette.secondaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: CtsPalette.secondaryBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
        color: CtsPalette.surfaceAlt,
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
