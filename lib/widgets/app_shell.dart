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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CtsPalette.navy, Color(0xFF07142A), Color(0xFF0A1322)],
            stops: [0.0, 0.38, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1240;
              final medium = constraints.maxWidth >= 960;
              final railWidth = wide
                  ? 252.0
                  : medium
                  ? 90.0
                  : 80.0;
              return Row(
                children: [
                  SizedBox(
                    width: railWidth,
                    child: _SidebarRail(
                      extended: wide,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                      totalRecords: controller.inspections.length,
                      criticalRecords: controller.inspections
                          .where((inspection) => inspection.criticalCount > 0)
                          .length,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _TopStrip(
                          wide: wide,
                          metricValue: controller.inspections.length.toString(),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopStrip extends StatelessWidget {
  const _TopStrip({required this.wide, required this.metricValue});

  final bool wide;
  final String metricValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final titleBlock = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/logo/cts_logo.png',
                    width: compact ? 108 : 136,
                    height: compact ? 46 : 58,
                    fit: BoxFit.contain,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CTS Fluid Power Inspection App',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Offline tablet workflow for fluid power inspection reports',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );

          final statusPills = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _TopStatusPill(
                icon: Icons.sync,
                label: 'Local data only',
                color: CtsPalette.orange,
              ),
              _TopStatusPill(
                icon: Icons.lock_outline,
                label: 'Offline ready',
                color: CtsPalette.success,
              ),
              _TopStatusPill(
                icon: Icons.list_alt_rounded,
                label: '$metricValue total records',
                color: CtsPalette.info,
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 12), statusPills],
          );
        },
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
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
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
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 12, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: CtsPalette.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Inspection Suite',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: NavigationRail(
              extended: extended,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: extended ? null : NavigationRailLabelType.all,
              leading: const SizedBox(height: 2),
              trailing: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    _RailHint(
                      icon: Icons.today_outlined,
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
              ),
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
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Landscape tablet layout with large touch targets and high-contrast controls.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.66),
                ),
              ),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
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
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white70),
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
