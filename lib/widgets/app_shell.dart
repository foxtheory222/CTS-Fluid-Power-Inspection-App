import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/workspace_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(workspaceProvider);
    return Scaffold(
      backgroundColor: CtsPalette.cloud,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final extendedRail = constraints.maxWidth >= 1500;
            final railWidth = extendedRail ? 224.0 : 92.0;
            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
                  child: SizedBox(
                    width: railWidth,
                    child: _SidebarRail(
                      extended: extendedRail,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                      totalRecords: controller.inspections.length,
                      criticalRecords: controller.inspections
                          .where((inspection) => inspection.criticalCount > 0)
                          .length,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      children: [
                        _TopStrip(
                          totalRecords: controller.inspections.length,
                          criticalRecords: controller.inspections
                              .where(
                                (inspection) => inspection.criticalCount > 0,
                              )
                              .length,
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1680),
                              child: child,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopStrip extends StatelessWidget {
  const _TopStrip({required this.totalRecords, required this.criticalRecords});

  final int totalRecords;
  final int criticalRecords;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1040;
            final brandBlock = Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/logo/cts_logo.png',
                    width: compact ? 220 : 300,
                    height: compact ? 52 : 66,
                    fit: BoxFit.contain,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CTS Fluid Power Inspection App',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Offline field inspections, PDF reports, and tablet share/email handoff.',
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
                ],
              ],
            );

            final statusPills = Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                _TopStatusPill(
                  icon: Icons.sync_disabled_outlined,
                  label: 'Local data only',
                  color: CtsPalette.orange,
                ),
                _TopStatusPill(
                  icon: Icons.wifi_off_rounded,
                  label: 'Offline ready',
                  color: CtsPalette.success,
                ),
                _TopStatusPill(
                  icon: Icons.description_outlined,
                  label: '$totalRecords records',
                  color: CtsPalette.info,
                ),
                _TopStatusPill(
                  icon: Icons.warning_amber_rounded,
                  label: '$criticalRecords critical',
                  color: CtsPalette.danger,
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [brandBlock, const SizedBox(height: 16), statusPills],
              );
            }

            return Row(
              children: [
                Expanded(child: brandBlock),
                const SizedBox(width: 20),
                Flexible(child: statusPills),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopStatusPill extends StatelessWidget {
  const _TopStatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarRail extends StatelessWidget {
  const _SidebarRail({
    required this.extended,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.totalRecords,
    required this.criticalRecords,
  });

  final bool extended;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int totalRecords;
  final int criticalRecords;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTrailHints = extended && constraints.maxHeight >= 720;
        return Container(
          decoration: BoxDecoration(
            color: CtsPalette.navy,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          'assets/logo/cts_launcher_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (extended) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CTS',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              'Inspection App',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF90A5BD)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: NavigationRail(
                  extended: extended,
                  minWidth: 72,
                  minExtendedWidth: 192,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: extended ? null : NavigationRailLabelType.none,
                  leading: const SizedBox(height: 4),
                  trailing: showTrailHints
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                          child: Column(
                            children: [
                              _RailHint(
                                icon: Icons.description_outlined,
                                title: 'Active',
                                value: totalRecords.toString(),
                              ),
                              const SizedBox(height: 8),
                              _RailHint(
                                icon: Icons.warning_amber_rounded,
                                title: 'Critical',
                                value: criticalRecords.toString(),
                                tint: CtsPalette.danger,
                              ),
                            ],
                          ),
                        )
                      : null,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search_rounded),
                      label: Text('Inspections'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.edit_document),
                      selectedIcon: Icon(Icons.edit_document),
                      label: Text('New Inspection'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_turned_in_outlined),
                      selectedIcon: Icon(Icons.assignment_turned_in),
                      label: Text('Action Items'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RailHint extends StatelessWidget {
  const _RailHint({
    required this.icon,
    required this.title,
    required this.value,
    this.tint = CtsPalette.orange,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF90A5BD),
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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
