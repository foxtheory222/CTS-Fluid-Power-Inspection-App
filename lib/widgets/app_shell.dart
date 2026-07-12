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
      resizeToAvoidBottomInset: true,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final mobile = constraints.maxWidth < 720;
              final wide = constraints.maxWidth >= 1240 && textScale <= 1.25;
              final medium = constraints.maxWidth >= 960;
              if (mobile) {
                return Column(
                  children: [
                    _MobileTopStrip(
                      metricValue: controller.inspections.length.toString(),
                    ),
                    if (controller.lastError != null)
                      _LoadErrorBanner(
                        onRetry: controller.loadPersistedInspections,
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: child,
                      ),
                    ),
                    _MobileNavigation(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                    ),
                  ],
                );
              }
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
                        if (controller.lastError != null)
                          _LoadErrorBanner(
                            onRetry: controller.loadPersistedInspections,
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

class _MobileTopStrip extends StatelessWidget {
  const _MobileTopStrip({required this.metricValue});

  final String metricValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'CTS Fluid Power Inspection App',
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'assets/logo/cts_logo.png',
                  width: 108,
                  height: 44,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _TopStatusPill(
            icon: Icons.storage_outlined,
            label: '$metricValue records',
            color: CtsPalette.info,
          ),
        ],
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFF0D2139),
        indicatorColor: CtsPalette.orange.withValues(alpha: 0.3),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white70,
          );
        }),
        labelTextStyle: WidgetStateProperty.all(
          Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            tooltip: 'Dashboard',
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            tooltip: 'Inspections',
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Inspections',
          ),
          NavigationDestination(
            tooltip: 'New Inspection',
            icon: Icon(Icons.edit_document),
            label: 'New',
          ),
          NavigationDestination(
            tooltip: 'Action Items',
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in),
            label: 'Actions',
          ),
          NavigationDestination(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CtsPalette.dangerOnDark.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: CtsPalette.dangerOnDark.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage_outlined, color: CtsPalette.dangerOnDark),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Local inspections could not be loaded. Your device data has not been changed.',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Retry'),
          ),
        ],
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
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CTS Fluid Power Inspection App',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Offline tablet workflow for fluid power inspection reports',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                        ),
                      ],
                    ),
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

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 12), statusPills],
            );
          }
          return Row(
            children: [
              Expanded(flex: wide ? 3 : 2, child: titleBlock),
              const SizedBox(width: 16),
              Flexible(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: statusPills,
                ),
              ),
            ],
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
    final compact = !extended;
    return Container(
      margin: compact
          ? const EdgeInsets.fromLTRB(8, 0, 8, 8)
          : const EdgeInsets.fromLTRB(18, 0, 12, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: compact
                ? const EdgeInsets.symmetric(vertical: 16)
                : const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: extended
                ? Row(
                    children: [
                      const _SuiteMark(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Inspection Suite',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  )
                : const Tooltip(
                    message: 'CTS Inspection Suite',
                    child: _SuiteMark(),
                  ),
          ),
          Expanded(
            child: NavigationRail(
              extended: extended,
              minWidth: compact ? 54 : 72,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: extended ? null : NavigationRailLabelType.none,
              leading: const SizedBox(height: 2),
              trailing: extended
                  ? Padding(
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
                    )
                  : null,
              destinations: const [
                NavigationRailDestination(
                  icon: Tooltip(
                    message: 'Dashboard',
                    child: Icon(Icons.space_dashboard_outlined),
                  ),
                  selectedIcon: Tooltip(
                    message: 'Dashboard',
                    child: Icon(Icons.space_dashboard_rounded),
                  ),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Tooltip(
                    message: 'Inspections',
                    child: Icon(Icons.search_outlined),
                  ),
                  selectedIcon: Tooltip(
                    message: 'Inspections',
                    child: Icon(Icons.search_rounded),
                  ),
                  label: Text('Inspections'),
                ),
                NavigationRailDestination(
                  icon: Tooltip(
                    message: 'New Inspection',
                    child: Icon(Icons.edit_document),
                  ),
                  selectedIcon: Tooltip(
                    message: 'New Inspection',
                    child: Icon(Icons.edit_document),
                  ),
                  label: Text('New Inspection'),
                ),
                NavigationRailDestination(
                  icon: Tooltip(
                    message: 'Action Items',
                    child: Icon(Icons.assignment_turned_in_outlined),
                  ),
                  selectedIcon: Tooltip(
                    message: 'Action Items',
                    child: Icon(Icons.assignment_turned_in),
                  ),
                  label: Text('Action Items'),
                ),
                NavigationRailDestination(
                  icon: Tooltip(
                    message: 'Settings',
                    child: Icon(Icons.settings_outlined),
                  ),
                  selectedIcon: Tooltip(
                    message: 'Settings',
                    child: Icon(Icons.settings),
                  ),
                  label: Text('Settings'),
                ),
              ],
            ),
          ),
          if (extended)
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

class _SuiteMark extends StatelessWidget {
  const _SuiteMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: CtsPalette.orange,
        shape: BoxShape.circle,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.07),
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
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
