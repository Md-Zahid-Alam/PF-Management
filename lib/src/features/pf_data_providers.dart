import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';

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
