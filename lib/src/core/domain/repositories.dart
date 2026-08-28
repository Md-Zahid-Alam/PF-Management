import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

abstract interface class SalaryRepository {
  Future<List<StoredSalary>> getForEmployment(String employmentId);
  Future<StoredSalary?> findApplicable(String employmentId, DateTime onDate);
  Future<void> save(StoredSalary salary);
  Future<void> delete(String id);
}

abstract interface class PFRuleRepository {
  Future<List<StoredPFRule>> getForOrganization(String organizationId);
  Future<StoredPFRule?> findApplicable(String organizationId, DateTime onDate);
  Future<void> save(StoredPFRule rule);
  Future<void> deleteUnused(String id);
}

abstract interface class MonthlyPFRepository {
  Future<List<StoredMonthlyPFRecord>> getForEmployment(String employmentId);
  Future<StoredMonthlyPFRecord?> findByMonth(
    String employmentId,
    YearMonth month,
  );
  Future<void> create(StoredMonthlyPFRecord record);
  Future<void> saveManualAdjustment(StoredMonthlyPFRecord adjustedRecord);
  Future<void> confirm(String id, DateTime confirmedAt);
  Future<void> delete(String id);
}
