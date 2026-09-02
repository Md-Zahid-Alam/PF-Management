import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

class StoredSalary {
  const StoredSalary({
    required this.id,
    required this.employmentId,
    required this.effectiveFrom,
    required this.grossSalary,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  final String id;
  final String employmentId;
  final DateTime effectiveFrom;
  final Money grossSalary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
}

class StoredPFRule {
  const StoredPFRule({
    required this.rule,
    required this.organizationId,
    required this.partialMonthPolicy,
    required this.effectiveVersionPolicy,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  final PFRuleVersion rule;
  final String organizationId;
  final PartialMonthPolicy partialMonthPolicy;
  final EffectiveVersionPolicy effectiveVersionPolicy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
}

class StoredMonthlyPFRecord {
  const StoredMonthlyPFRecord({
    required this.id,
    required this.employmentId,
    required this.month,
    required this.grossSalary,
    required this.basicSalary,
    required this.employeeContribution,
    required this.employerContribution,
    required this.adjustment,
    required this.basicRate,
    required this.employeeRate,
    required this.employerRate,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.salaryHistoryId,
    this.ruleVersionId,
    this.salaryCreditedDate,
    this.scheduledGenerationDate,
    this.actualGenerationDate,
    this.originalGrossSalary,
    this.originalBasicSalary,
    this.originalEmployeeContribution,
    this.originalEmployerContribution,
    this.manuallyAdjustedAt,
    this.confirmedAt,
    this.notes,
  });

  final String id;
  final String employmentId;
  final YearMonth month;
  final Money grossSalary;
  final Money basicSalary;
  final Money employeeContribution;
  final Money employerContribution;
  final Money adjustment;
  final Rate basicRate;
  final Rate employeeRate;
  final Rate employerRate;
  final String source;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? salaryHistoryId;
  final String? ruleVersionId;
  final DateTime? salaryCreditedDate;
  final DateTime? scheduledGenerationDate;
  final DateTime? actualGenerationDate;
  final Money? originalGrossSalary;
  final Money? originalBasicSalary;
  final Money? originalEmployeeContribution;
  final Money? originalEmployerContribution;
  final DateTime? manuallyAdjustedAt;
  final DateTime? confirmedAt;
  final String? notes;
}

class StoredProfitRecord {
  const StoredProfitRecord({
    required this.id,
    required this.employmentId,
    required this.creditedDate,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    this.periodStart,
    this.periodEnd,
    this.optionalRate,
    this.calculationMethod,
    this.sourceReference,
    this.notes,
  });

  final String id;
  final String employmentId;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime creditedDate;
  final Money amount;
  final Rate? optionalRate;
  final String? calculationMethod;
  final String? sourceReference;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
