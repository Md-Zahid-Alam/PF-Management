import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: context.l10n.dashboard,
      ),
      NavigationDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: context.l10n.records,
      ),
      NavigationDestination(
        icon: const Icon(Icons.assessment_outlined),
        selectedIcon: const Icon(Icons.assessment),
        label: context.l10n.reports,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: context.l10n.settings,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = useNavigationRailForWidth(constraints.maxWidth);
        if (useRail) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: _selectDestination,
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircleAvatar(child: Icon(Icons.savings_outlined)),
                    ),
                    destinations: <NavigationRailDestination>[
                      for (final destination in destinations)
                        NavigationRailDestination(
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          label: Text(destination.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _selectDestination,
            destinations: destinations,
          ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

bool useNavigationRailForWidth(double width) => width >= 760;
