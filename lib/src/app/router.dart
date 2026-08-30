import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/app/app_shell.dart';
import 'package:pf_tracker/src/features/calculator/presentation/pf_calculator_screen.dart';
import 'package:pf_tracker/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/monthly_records_screen.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/manual_pf_record_screen.dart';
import 'package:pf_tracker/src/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pf_tracker/src/features/salary_history/presentation/salary_form_screen.dart';
import 'package:pf_tracker/src/features/salary_history/presentation/salary_history_screen.dart';
import 'package:pf_tracker/src/features/settings/presentation/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/setup',
  routes: <RouteBase>[
    GoRoute(
      path: '/setup',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/setup/edit',
      builder: (context, state) => const OnboardingScreen(editExisting: true),
    ),
    GoRoute(
      path: '/salary-history',
      builder: (context, state) => const SalaryHistoryScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'add',
          builder: (context, state) => const SalaryFormScreen(),
        ),
        GoRoute(
          path: ':salaryId/edit',
          builder: (context, state) {
            return SalaryFormScreen(salaryId: state.pathParameters['salaryId']);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/records/add',
      builder: (context, state) => const ManualPFRecordScreen(),
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
