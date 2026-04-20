import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/workspace_models.dart';
import 'features/action_items/action_items_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/inspection_detail/inspection_detail_screen.dart';
import 'features/inspection_form/inspection_form_screen.dart';
import 'features/inspection_list/inspection_list_screen.dart';
import 'features/settings/settings_screen.dart';
import 'widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            selectedIndex: _selectedIndexForLocation(state.matchedLocation),
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/');
                  break;
                case 1:
                  context.go('/inspections');
                  break;
                case 2:
                  context.go('/inspection/new');
                  break;
                case 3:
                  context.go('/actions');
                  break;
                case 4:
                  context.go('/settings');
                  break;
              }
            },
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/inspections',
            name: 'inspection-list',
            builder: (context, state) => const InspectionListScreen(),
          ),
          GoRoute(
            path: '/inspection/new',
            name: 'inspection-new',
            builder: (context, state) {
              final summary = state.extra is InspectionSummary
                  ? state.extra as InspectionSummary
                  : null;
              return InspectionFormScreen(seed: summary);
            },
          ),
          GoRoute(
            path: '/inspection/:id/edit',
            name: 'inspection-edit',
            builder: (context, state) {
              final summary = state.extra is InspectionSummary
                  ? state.extra as InspectionSummary
                  : null;
              return InspectionFormScreen(seed: summary);
            },
          ),
          GoRoute(
            path: '/inspection/:id',
            name: 'inspection-detail',
            builder: (context, state) => InspectionDetailScreen(
              inspectionId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/actions',
            name: 'actions',
            builder: (context, state) => const ActionItemsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

int _selectedIndexForLocation(String location) {
  if (location == '/inspection/new' || location.endsWith('/edit')) {
    return 2;
  }
  if (location.startsWith('/inspections') ||
      location.startsWith('/inspection/')) {
    return 1;
  }
  if (location.startsWith('/actions')) {
    return 3;
  }
  if (location.startsWith('/settings')) {
    return 4;
  }
  return 0;
}

class CtsFluidPowerInspectionApp extends ConsumerWidget {
  const CtsFluidPowerInspectionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'CTS Fluid Power Inspection App',
      debugShowCheckedModeBanner: false,
      theme: buildCtsTheme(Brightness.light),
      darkTheme: buildCtsTheme(Brightness.dark),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
