import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_automation_service.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/core/notifications/notification_provider.dart';

final initialPFSetupProvider = FutureProvider<InitialPFSetup?>((ref) {
  return ref.watch(initialSetupRepositoryProvider).load();
});

final salaryHistoryProvider = FutureProvider<List<StoredSalary>>((ref) {
  return ref
      .watch(salaryRepositoryProvider)
      .getForEmployment(DriftInitialSetupRepository.employmentId);
});

final monthlyPFRecordsProvider = FutureProvider<List<StoredMonthlyPFRecord>>((
  ref,
) {
  return ref
      .watch(monthlyPFRepositoryProvider)
      .getForEmployment(DriftInitialSetupRepository.employmentId);
});

final profitHistoryProvider = FutureProvider<List<StoredProfitRecord>>((ref) {
  return ref
      .watch(profitRepositoryProvider)
      .getForEmployment(DriftInitialSetupRepository.employmentId);
});

final automationSettingsProvider = FutureProvider<AutomationSettings>((ref) {
  return ref.watch(automationSettingsRepositoryProvider).get();
});

final pfAutomationRunProvider = FutureProvider<List<AutomationPeriodResult>>((
  ref,
) async {
  final setupRepository = ref.watch(initialSetupRepositoryProvider);
  final salaryRepository = ref.watch(salaryRepositoryProvider);
  final ruleRepository = ref.watch(pfRuleRepositoryProvider);
  final monthlyRepository = ref.watch(monthlyPFRepositoryProvider);
  final settingsRepository = ref.watch(automationSettingsRepositoryProvider);
  final notificationGateway = ref.watch(
    automationNotificationGatewayProvider,
  );

  final setup = await setupRepository.load();
  if (setup == null) {
    return const <AutomationPeriodResult>[];
  }

  await notificationGateway.initialize();

  final salaryHistory = await salaryRepository.getForEmployment(
    DriftInitialSetupRepository.employmentId,
  );
  final ruleHistory = await ruleRepository.getForOrganization(
    DriftInitialSetupRepository.organizationId,
  );
  final service = PFAutomationService(
    engine: const PFCalculationEngine(),
    monthlyRepository: monthlyRepository,
    settingsRepository: settingsRepository,
    notificationGateway: notificationGateway,
  );
  final results = await service.processDuePeriods(
    today: DateTime.now(),
    employmentId: DriftInitialSetupRepository.employmentId,
    employment: setup.employmentDates,
    salaryHistory: salaryHistory,
    ruleHistory: ruleHistory,
    schedules: <EffectiveSalarySchedule>[setup.salarySchedule],
  );
  if (results.any(
    (result) => result.status == AutomationPeriodStatus.automaticallyCalculated,
  )) {
    ref.invalidate(monthlyPFRecordsProvider);
  }
  return results;
});
