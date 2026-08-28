import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

class EmploymentDates {
  const EmploymentDates({
    required this.joiningDate,
    required this.pfStartDate,
    this.permanentDate,
    this.exitDate,
  });

  final DateTime joiningDate;
  final DateTime pfStartDate;
  final DateTime? permanentDate;
  final DateTime? exitDate;
}

class PFRuleVersion {
  const PFRuleVersion({
    required this.id,
    required this.effectiveFrom,
    required this.basicSalaryRate,
    required this.employeePFRate,
    required this.employerPFRate,
    required this.maturityMonths,
    required this.maturityBasis,
    this.employerEntitledBeforeMaturity = false,
    this.employerEntitledAfterMaturity = true,
  }) : assert(maturityMonths >= 0);

  final String id;
  final DateTime effectiveFrom;
  final Rate basicSalaryRate;
  final Rate employeePFRate;
  final Rate employerPFRate;
  final int maturityMonths;
  final MaturityBasis maturityBasis;
  final bool employerEntitledBeforeMaturity;
  final bool employerEntitledAfterMaturity;
}

class SalaryHistoryEntry {
  const SalaryHistoryEntry({
    required this.effectiveFrom,
    required this.grossSalary,
  });

  final DateTime effectiveFrom;
  final Money grossSalary;
}

class SalarySchedule {
  const SalarySchedule({
    required this.paymentMonthOffset,
    required this.paymentWindowStartDay,
    required this.paymentWindowEndDay,
  }) : assert(paymentMonthOffset >= 0),
       assert(paymentWindowStartDay >= 1 && paymentWindowStartDay <= 31),
       assert(
         paymentWindowEndDay >= paymentWindowStartDay &&
             paymentWindowEndDay <= 31,
       );

  final int paymentMonthOffset;
  final int paymentWindowStartDay;
  final int paymentWindowEndDay;
}

class StatementYearConfiguration {
  const StatementYearConfiguration({
    required this.startMonth,
    required this.startDay,
  }) : assert(startMonth >= 1 && startMonth <= 12),
       assert(startDay >= 1 && startDay <= 31);

  final int startMonth;
  final int startDay;
}

class PFStatementYear {
  const PFStatementYear({required this.startYear, required this.endYear});

  final int startYear;
  final int endYear;

  @override
  bool operator ==(Object other) =>
      other is PFStatementYear &&
      other.startYear == startYear &&
      other.endYear == endYear;

  @override
  int get hashCode => Object.hash(startYear, endYear);
}

class MonthlyPFCalculation {
  const MonthlyPFCalculation({
    required this.month,
    required this.grossSalary,
    required this.basicSalary,
    required this.employeeContribution,
    required this.employerContribution,
    required this.totalContribution,
    required this.ruleVersionId,
    required this.scheduledGenerationDate,
  });

  final YearMonth month;
  final Money grossSalary;
  final Money basicSalary;
  final Money employeeContribution;
  final Money employerContribution;
  final Money totalContribution;
  final String ruleVersionId;
  final DateTime scheduledGenerationDate;
}

class DatedMoney {
  const DatedMoney({required this.date, required this.amount});

  final DateTime date;
  final Money amount;
}

enum MaturityStatus { beforeMaturity, mature }

class ExitEstimate {
  const ExitEstimate({
    required this.status,
    required this.employeeContribution,
    required this.employerContribution,
    required this.knownProfit,
    required this.adjustments,
    required this.forfeitedEmployerContribution,
    required this.estimatedReceivable,
    required this.profitComplete,
  });

  final MaturityStatus status;
  final Money employeeContribution;
  final Money employerContribution;
  final Money knownProfit;
  final Money adjustments;
  final Money forfeitedEmployerContribution;
  final Money estimatedReceivable;
  final bool profitComplete;
}

class StatementSnapshot {
  const StatementSnapshot({
    this.openingBalance,
    this.employeeContribution,
    this.employerContribution,
    this.profit,
    this.adjustments,
    this.closingBalance,
  });

  final Money? openingBalance;
  final Money? employeeContribution;
  final Money? employerContribution;
  final Money? profit;
  final Money? adjustments;
  final Money? closingBalance;
}

class StatementComparison {
  const StatementComparison({
    required this.calculated,
    required this.actual,
    this.openingDifference,
    this.employeeDifference,
    this.employerDifference,
    this.profitDifference,
    this.adjustmentDifference,
    this.closingDifference,
  });

  final StatementSnapshot calculated;
  final StatementSnapshot actual;
  final Money? openingDifference;
  final Money? employeeDifference;
  final Money? employerDifference;
  final Money? profitDifference;
  final Money? adjustmentDifference;
  final Money? closingDifference;
}
