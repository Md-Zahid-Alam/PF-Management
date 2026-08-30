import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/app/app_shell.dart';
import 'package:pf_tracker/src/features/calculator/presentation/pf_calculator_screen.dart';
import 'package:pf_tracker/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/monthly_records_screen.dart';
import 'package:pf_tracker/src/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pf_tracker/src/features/settings/presentation/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/setup',
  routes: <RouteBase>[
    GoRoute(
      path: '/setup',
      builder: (context, state) => const OnboardingScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/calculator',
              builder: (context, state) => const PFCalculatorScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/records',
              builder: (context, state) => const MonthlyRecordsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
