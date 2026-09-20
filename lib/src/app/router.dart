import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/app/app_shell.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';
import 'package:pf_tracker/src/features/calculator/presentation/pf_calculator_screen.dart';
import 'package:pf_tracker/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/monthly_records_screen.dart';
import 'package:pf_tracker/src/features/maturity/presentation/pf_maturity_screen.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/manual_pf_record_screen.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/monthly_record_adjustment_screen.dart';
import 'package:pf_tracker/src/features/monthly_records/presentation/monthly_record_detail_screen.dart';
import 'package:pf_tracker/src/features/onboarding/presentation/historical_reconstruction_screen.dart';
import 'package:pf_tracker/src/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pf_tracker/src/features/profit_history/presentation/profit_form_screen.dart';
import 'package:pf_tracker/src/features/profit_history/presentation/profit_history_screen.dart';
import 'package:pf_tracker/src/features/reports/presentation/actual_statement_form_screen.dart';
import 'package:pf_tracker/src/features/reports/presentation/exit_estimate_screen.dart';
import 'package:pf_tracker/src/features/reports/presentation/pf_reports_screen.dart';
import 'package:pf_tracker/src/features/reports/presentation/statement_year_screen.dart';
import 'package:pf_tracker/src/features/rule_history/presentation/pf_rule_form_screen.dart';
import 'package:pf_tracker/src/features/rule_history/presentation/pf_rule_history_screen.dart';
import 'package:pf_tracker/src/features/salary_history/presentation/salary_form_screen.dart';
import 'package:pf_tracker/src/features/salary_history/presentation/salary_history_screen.dart';
import 'package:pf_tracker/src/features/settings/presentation/backup_restore_screen.dart';
import 'package:pf_tracker/src/features/settings/presentation/about_screen.dart';
import 'package:pf_tracker/src/features/settings/presentation/settings_screen.dart';
import 'package:pf_tracker/src/features/startup/presentation/startup_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/startup',
  routes: <RouteBase>[
    GoRoute(
      path: '/startup',
      builder: (context, state) => const StartupScreen(),
    ),
    GoRoute(
      path: '/backup-restore',
      builder: (context, state) => const BackupRestoreScreen(),
    ),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
    GoRoute(
      path: '/maturity',
      builder: (context, state) => const PFMaturityScreen(),
    ),
    GoRoute(
      path: '/setup',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/setup/edit',
      builder: (context, state) => const OnboardingScreen(editExisting: true),
    ),
    GoRoute(
      path: '/historical-reconstruction',
      builder: (context, state) => const HistoricalReconstructionScreen(),
    ),
    GoRoute(
      path: '/salary-history',
      builder: (context, state) => const SalaryHistoryScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'add',
          builder: (context, state) => SalaryFormScreen(
            currencyCode: state.uri.queryParameters['currency'] ?? 'BDT',
          ),
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
      path: '/profit-history',
      builder: (context, state) => const ProfitHistoryScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'add',
          builder: (context, state) => ProfitFormScreen(
            currencyCode: state.uri.queryParameters['currency'] ?? 'BDT',
          ),
        ),
        GoRoute(
          path: ':profitId/edit',
          builder: (context, state) {
            return ProfitFormScreen(profitId: state.pathParameters['profitId']);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const PFReportsScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'exit-estimate',
          builder: (context, state) => const ExitEstimateScreen(),
        ),
        GoRoute(
          path: 'statement-year',
          builder: (context, state) => const StatementYearScreen(),
        ),
        GoRoute(
          path: ':startYear/actual',
          builder: (context, state) => ActualStatementFormScreen(
            startYear: int.parse(state.pathParameters['startYear']!),
            currencyCode: state.uri.queryParameters['currency'] ?? 'BDT',
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/pf-rule-history',
      builder: (context, state) => const PFRuleHistoryScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'add',
          builder: (context, state) => PFRuleFormScreen(
            sourceRuleId: state.uri.queryParameters['source'],
          ),
        ),
        GoRoute(
          path: ':ruleId/edit',
          builder: (context, state) {
            return PFRuleFormScreen(ruleId: state.pathParameters['ruleId']);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/records/add',
      builder: (context, state) {
        final value = state.uri.queryParameters['month'];
        final parsed = value == null ? null : DateTime.tryParse('$value-01');
        return ManualPFRecordScreen(
          initialMonth: parsed == null ? null : YearMonth.fromDate(parsed),
        );
      },
    ),
    GoRoute(
      path: '/records/:recordId',
      builder: (context, state) {
        return MonthlyRecordDetailScreen(
          recordId: state.pathParameters['recordId']!,
        );
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'adjust',
          builder: (context, state) {
            return MonthlyRecordAdjustmentScreen(
              recordId: state.pathParameters['recordId']!,
            );
          },
        ),
      ],
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
