import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pf_tracker/src/features/onboarding/presentation/onboarding_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/setup',
  routes: <RouteBase>[
    GoRoute(
      path: '/setup',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
  ],
);
