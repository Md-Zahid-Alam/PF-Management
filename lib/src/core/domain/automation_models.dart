import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

class EffectiveSalarySchedule {
  const EffectiveSalarySchedule({
    required this.id,
    required this.effectiveFrom,
    required this.schedule,
  });

  final String id;
  final DateTime effectiveFrom;
  final SalarySchedule schedule;
}

enum AutomationPeriodStatus {
  alreadyExists,
  pendingSalaryInformation,
  pendingRuleInformation,
  readyForManualCalculation,
  automaticallyCalculated,
  manuallyCalculated,
}

class AutomationPeriodResult {
  const AutomationPeriodResult({
    required this.month,
    required this.scheduledGenerationDate,
    required this.status,
    this.recordId,
  });

  final YearMonth month;
  final DateTime scheduledGenerationDate;
  final AutomationPeriodStatus status;
  final String? recordId;
}

class AutomationSettings {
  const AutomationSettings({
    this.autoCalculate = true,
    this.notificationsEnabled = true,
  });

  final bool autoCalculate;
  final bool notificationsEnabled;

  AutomationSettings copyWith({
    bool? autoCalculate,
    bool? notificationsEnabled,
  }) {
    return AutomationSettings(
      autoCalculate: autoCalculate ?? this.autoCalculate,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class HistoricalPFPreview {
  const HistoricalPFPreview({
    required this.pfStart,
    required this.calculationThrough,
    required this.monthCount,
    required this.employeeContribution,
    required this.employerContribution,
    required this.calculatedPF,
    required this.profitKnown,
    required this.periods,
  });

  final YearMonth pfStart;
  final YearMonth calculationThrough;
  final int monthCount;
  final Money employeeContribution;
  final Money employerContribution;
  final Money calculatedPF;
  final bool profitKnown;
  final List<HistoricalPFPreviewPeriod> periods;
}

class HistoricalPFPreviewPeriod {
  const HistoricalPFPreviewPeriod({
    required this.month,
    required this.salaryHistoryId,
    required this.salaryEffectiveFrom,
    required this.ruleVersionId,
    required this.ruleEffectiveFrom,
    required this.employeeContribution,
    required this.employerContribution,
  });

  final YearMonth month;
  final String salaryHistoryId;
  final DateTime salaryEffectiveFrom;
  final String ruleVersionId;
  final DateTime ruleEffectiveFrom;
  final Money employeeContribution;
  final Money employerContribution;
}

enum AutomationNotificationType {
  calculationDue,
  automaticallyCalculated,
  missingSalaryInformation,
  maturityApproaching,
}

class AutomationNotification {
  const AutomationNotification({required this.type, this.month});

  final AutomationNotificationType type;
  final YearMonth? month;
}
