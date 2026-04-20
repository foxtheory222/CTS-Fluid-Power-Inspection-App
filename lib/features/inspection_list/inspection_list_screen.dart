import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/workspace_models.dart';
import '../../core/workspace_providers.dart';
import '../../data/models/inspection_enums.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';

class InspectionListScreen extends ConsumerStatefulWidget {
  const InspectionListScreen({super.key});

  @override
  ConsumerState<InspectionListScreen> createState() =>
      _InspectionListScreenState();
}

class _InspectionListScreenState extends ConsumerState<InspectionListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(workspaceProvider);
    final inspections = controller.filteredInspections;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: 'Inspection Search',
            subtitle:
                'Search by work order, customer, asset, technician, document number, or status.',
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      controller.setSearchQuery(value);
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search inspections',
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final scope in workspaceSearchScopes)
                      ChoiceChip(
                        label: Text(scope.label),
                        selected: controller.statusFilter == scope.status,
                        onSelected: (selected) {
                          setState(() {
                            controller.setStatusFilter(
                              selected ? scope.status : null,
                            );
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1080;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _InspectionList(results: inspections)),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 360,
                      child: _SummaryPanel(results: inspections),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _InspectionList(results: inspections),
                  const SizedBox(height: 18),
                  _SummaryPanel(results: inspections),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InspectionList extends StatelessWidget {
  const _InspectionList({required this.results});

  final List<InspectionSummary> results;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Inspection Records',
      subtitle: results.isEmpty
          ? 'No inspections match the current search.'
          : '${results.length} inspection(s) found',
      child: Column(
        children: [
          if (results.isEmpty)
            _EmptyState(
              title: 'No matches',
              body: 'Try a different work order, customer, or status filter.',
            )
          else
            for (final inspection in results) ...[
              _InspectionTile(inspection: inspection),
              if (inspection != results.last) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({required this.inspection});

  final InspectionSummary inspection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.go('/inspection/${inspection.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                          inspection.assetName,
                          style: Theme.of(context).textTheme.bodyMedium
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    label: inspection.documentNumber,
                    icon: Icons.confirmation_number_outlined,
                  ),
                  _MetaChip(
                    label: inspection.workOrderNumber,
                    icon: Icons.work_outline,
                  ),
                  _MetaChip(
                    label: inspection.technicianName,
                    icon: Icons.person_outline,
                  ),
                  _MetaChip(
                    label: DateFormat(
                      'MMM d, h:mm a',
                    ).format(inspection.lastUpdatedAt),
                    icon: Icons.schedule,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatDot(
                    color: CtsPalette.orange,
                    label: '${inspection.flaggedCount} flagged',
                  ),
                  const SizedBox(width: 12),
                  _StatDot(
                    color: CtsPalette.success,
                    label: '${inspection.photoCount} photos',
                  ),
                  const SizedBox(width: 12),
                  _StatDot(
                    color: CtsPalette.info,
                    label: '${inspection.actionItems.length} actions',
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

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.results});

  final List<InspectionSummary> results;

  @override
  Widget build(BuildContext context) {
    final draftCount = results
        .where((item) => item.status == InspectionStatus.draft)
        .length;
    final inProgressCount = results
        .where((item) => item.status == InspectionStatus.inProgress)
        .length;
    final completeCount = results
        .where((item) => item.status == InspectionStatus.complete)
        .length;
    final emailedCount = results
        .where((item) => item.status == InspectionStatus.emailed)
        .length;
    return SectionCard(
      title: 'Search Summary',
      subtitle: 'Filtered counts update as you narrow the search.',
      child: Column(
        children: [
          _SummaryLine(
            label: 'Draft',
            value: draftCount.toString(),
            color: CtsPalette.slate,
          ),
          _SummaryLine(
            label: 'In Progress',
            value: inProgressCount.toString(),
            color: CtsPalette.orange,
          ),
          _SummaryLine(
            label: 'Complete',
            value: completeCount.toString(),
            color: CtsPalette.success,
          ),
          _SummaryLine(
            label: 'Emailed',
            value: emailedCount.toString(),
            color: CtsPalette.info,
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.go('/inspection/new'),
            icon: const Icon(Icons.add),
            label: const Text('New Inspection'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Export bundle'),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: CtsPalette.orange),
      label: Text(label),
    );
  }
}

class _StatDot extends StatelessWidget {
  const _StatDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
