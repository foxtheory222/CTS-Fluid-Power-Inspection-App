import 'dart:math' as math;

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
            final extendedRail = constraints.maxWidth >= 1420;
            final railWidth = extendedRail ? 236.0 : 96.0;
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
                          child: LayoutBuilder(
                            builder: (context, areaConstraints) {
                              final width = areaConstraints.maxWidth > 1720
                                  ? 1720.0
                                  : areaConstraints.maxWidth;
                              return Center(
                                child: SizedBox(
                                  width: width,
                                  height: areaConstraints.maxHeight,
                                  child: child,
                                ),
                              );
                            },
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
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Colors.white,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1240;
            final brandBlock = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: CtsPalette.surfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: _CtsMark(size: 32),
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Combined Technical Services',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: CtsPalette.steel,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CTS Fluid Power Inspection App',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 18 : 20,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final statusPills = Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                _TopStatusPill(
                  icon: Icons.sync_disabled_outlined,
                  label: 'Local storage',
                  color: CtsPalette.steel,
                ),
                _TopStatusPill(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF ready',
                  color: CtsPalette.success,
                ),
                _TopStatusPill(
                  icon: Icons.description_outlined,
                  label: '$totalRecords records',
                  color: CtsPalette.secondaryBlue,
                ),
                _TopStatusPill(
                  icon: Icons.warning_amber_rounded,
                  label: '$criticalRecords critical',
                  color: CtsPalette.danger,
                ),
              ],
            );

            final summaryBlock = Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalRecords record${totalRecords == 1 ? '' : 's'} on device',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                statusPills,
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  brandBlock,
                  const SizedBox(height: 14),
                  summaryBlock,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: brandBlock),
                const SizedBox(width: 20),
                SizedBox(width: 380, child: summaryBlock),
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
            borderRadius: BorderRadius.circular(34),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: _CtsMark(size: 30),
                      ),
                    ),
                    if (extended) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Combined',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              'Fluid Power Reports',
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
                  minExtendedWidth: 204,
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

class _CtsMark extends StatelessWidget {
  const _CtsMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CtsMarkPainter()),
    );
  }
}

class _CtsMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.035
      ..color = CtsPalette.steel.withValues(alpha: 0.14);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(size.shortestSide * 0.04),
        Radius.circular(size.shortestSide * 0.26),
      ),
      ringPaint,
    );

    _drawArm(canvas, size, rotationDegrees: 0, color: CtsPalette.navy);
    _drawArm(canvas, size, rotationDegrees: 120, color: CtsPalette.steel);
    _drawArm(
      canvas,
      size,
      rotationDegrees: 240,
      color: CtsPalette.secondaryBlue,
    );

    final Paint centerPaint = Paint()..color = Colors.white;
    final Path centerCut = Path()
      ..moveTo(size.width * 0.5, size.height * 0.34)
      ..lineTo(size.width * 0.60, size.height * 0.50)
      ..lineTo(size.width * 0.5, size.height * 0.66)
      ..lineTo(size.width * 0.40, size.height * 0.50)
      ..close();
    canvas.drawPath(centerCut, centerPaint);
  }

  void _drawArm(
    Canvas canvas,
    Size size, {
    required double rotationDegrees,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotationDegrees * math.pi / 180);
    canvas.translate(-size.width / 2, -size.height / 2);

    final Path arm = Path()
      ..moveTo(size.width * 0.50, size.height * 0.06)
      ..lineTo(size.width * 0.74, size.height * 0.20)
      ..lineTo(size.width * 0.74, size.height * 0.55)
      ..lineTo(size.width * 0.60, size.height * 0.47)
      ..lineTo(size.width * 0.60, size.height * 0.33)
      ..lineTo(size.width * 0.50, size.height * 0.39)
      ..lineTo(size.width * 0.40, size.height * 0.33)
      ..lineTo(size.width * 0.40, size.height * 0.47)
      ..lineTo(size.width * 0.26, size.height * 0.55)
      ..lineTo(size.width * 0.26, size.height * 0.20)
      ..close();

    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[color, Color.lerp(color, Colors.white, 0.08)!],
      ).createShader(Offset.zero & size);

    canvas.drawPath(arm, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RailHint extends StatelessWidget {
  const _RailHint({
    required this.icon,
    required this.title,
    required this.value,
    this.tint = CtsPalette.secondaryBlue,
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
