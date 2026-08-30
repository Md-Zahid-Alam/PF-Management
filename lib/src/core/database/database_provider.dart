import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pf_tracker/src/core/database/app_database.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return DriftSalaryRepository(ref.watch(appDatabaseProvider));
});

final pfRuleRepositoryProvider = Provider<PFRuleRepository>((ref) {
  return DriftPFRuleRepository(ref.watch(appDatabaseProvider));
});

final monthlyPFRepositoryProvider = Provider<MonthlyPFRepository>((ref) {
  return DriftMonthlyPFRepository(ref.watch(appDatabaseProvider));
});

final automationSettingsRepositoryProvider =
    Provider<AutomationSettingsRepository>((ref) {
      return DriftAutomationSettingsRepository(ref.watch(appDatabaseProvider));
    });
