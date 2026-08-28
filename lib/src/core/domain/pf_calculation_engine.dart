import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

class MissingCalculationInput implements Exception {
  const MissingCalculationInput(this.message);

  final String message;

  @override
  String toString() => 'MissingCalculationInput: $message';
}

class PFCalculationEngine {
  const PFCalculationEngine({this.policy = const CalculationPolicy()});

  final CalculationPolicy policy;

  Money calculateBasicSalary(Money grossSalary, Rate basicSalaryRate) {
    return grossSalary.multiply(basicSalaryRate);
  }

  Money calculateEmployeeContribution(Money basicSalary, Rate employeeRate) {
    return basicSalary.multiply(employeeRate);
  }

  Money calculateEmployerContribution(Money basicSalary, Rate employerRate) {
    return basicSalary.multiply(employerRate);
  }

  bool isEligibleForMonth(EmploymentDates employment, YearMonth month) {
    final overlapsPFStart = !employment.pfStartDate.isAfter(month.lastDay);
    final overlapsExit = employment.exitDate == null || !employment.exitDate!.isBefore(month.firstDay);
    return overlapsPFStart && overlapsExit;
  }

  T? selectEffectiveVersion<T>(
    YearMonth month,
    Iterable<T> versions,
    DateTime Function(T version) effectiveFrom,
  ) {
    final selectionDate = switch (policy.effectiveVersionPolicy) {
      EffectiveVersionPolicy.monthEnd => month.lastDay,
      EffectiveVersionPolicy.monthStart => month.firstDay,
      EffectiveVersionPolicy.prorated => throw UnsupportedError(
        'Prorated effective-version selection requires an organization-specific policy.',
      ),
    };
    T? selected;
    DateTime? selectedDate;
    for (final version in versions) {
      final date = _dateOnly(effectiveFrom(version));
      if (!date.isAfter(selectionDate) && (selectedDate == null || date.isAfter(selectedDate))) {
        selected = version;
        selectedDate = date;
      }
    }
    return selected;
  }

  DateTime calculateMaturityDate(EmploymentDates employment, PFRuleVersion rule) {
    final basis = switch (rule.maturityBasis) {
      MaturityBasis.joiningDate => employment.joiningDate,
      MaturityBasis.pfStartDate => employment.pfStartDate,
      MaturityBasis.permanentDate => employment.permanentDate ??
          (throw const MissingCalculationInput('Permanent date is required by the maturity rule.')),
    };
    return _addMonthsClamped(basis, rule.maturityMonths);
  }

  PFRuleVersion selectMaturityRule({
    required EmploymentDates employment,
    required MaturityBasis basis,
    required Iterable<PFRuleVersion> ruleHistory,
  }) {
    final basisDate = switch (basis) {
      MaturityBasis.joiningDate => employment.joiningDate,
      MaturityBasis.pfStartDate => employment.pfStartDate,
      MaturityBasis.permanentDate => employment.permanentDate ??
          (throw const MissingCalculationInput('Permanent date is required by the maturity rule.')),
    };
    PFRuleVersion? selected;
    for (final rule in ruleHistory) {
      if (!rule.effectiveFrom.isAfter(basisDate) &&
          (selected == null || rule.effectiveFrom.isAfter(selected.effectiveFrom))) {
        selected = rule;
      }
    }
    return selected ??
        (throw const MissingCalculationInput(
          'No PF rule applies on the configured maturity-basis date.',
        ));
  }

  MaturityStatus maturityStatus(DateTime exitDate, DateTime maturityDate) {
    return _dateOnly(exitDate).isBefore(_dateOnly(maturityDate))
        ? MaturityStatus.beforeMaturity
        : MaturityStatus.mature;
  }

  DateTime scheduledGenerationDate(YearMonth pfMonth, SalarySchedule schedule) {
    final paymentMonth = pfMonth.addMonths(schedule.paymentMonthOffset);
    return _clampedDate(paymentMonth.year, paymentMonth.month, schedule.paymentWindowEndDay);
  }

  PFStatementYear statementYearFor(
    YearMonth pfMonth,
    StatementYearConfiguration configuration,
  ) {
    final boundaryThisYear = _clampedDate(
      pfMonth.year,
      configuration.startMonth,
      configuration.startDay,
    );
    final startYear = pfMonth.lastDay.isBefore(boundaryThisYear) ? pfMonth.year - 1 : pfMonth.year;
    return PFStatementYear(startYear: startYear, endYear: startYear + 1);
  }

  MonthlyPFCalculation calculateMonth({
    required YearMonth month,
    required EmploymentDates employment,
    required List<SalaryHistoryEntry> salaryHistory,
    required List<PFRuleVersion> ruleHistory,
    required SalarySchedule salarySchedule,
  }) {
    if (!isEligibleForMonth(employment, month)) {
      throw MissingCalculationInput('Employee is not PF-eligible for $month.');
    }
    final salary = selectEffectiveVersion(
      month,
      salaryHistory,
      (entry) => entry.effectiveFrom,
    );
    if (salary == null) {
      throw MissingCalculationInput('Salary information is required for $month.');
    }
    final rule = selectEffectiveVersion(
      month,
      ruleHistory,
      (version) => version.effectiveFrom,
    );
    if (rule == null) {
      throw MissingCalculationInput('PF rule information is required for $month.');
    }
    final basic = calculateBasicSalary(salary.grossSalary, rule.basicSalaryRate);
    final employee = calculateEmployeeContribution(basic, rule.employeePFRate);
    final employer = calculateEmployerContribution(basic, rule.employerPFRate);
    return MonthlyPFCalculation(
      month: month,
      grossSalary: salary.grossSalary,
      basicSalary: basic,
      employeeContribution: employee,
      employerContribution: employer,
      totalContribution: employee + employer,
      ruleVersionId: rule.id,
      scheduledGenerationDate: scheduledGenerationDate(month, salarySchedule),
    );
  }

  List<MonthlyPFCalculation> reconstructHistory({
    required EmploymentDates employment,
    required YearMonth calculationThrough,
    required List<SalaryHistoryEntry> salaryHistory,
    required List<PFRuleVersion> ruleHistory,
    required SalarySchedule salarySchedule,
  }) {
    final firstMonth = YearMonth.fromDate(employment.pfStartDate);
    return <MonthlyPFCalculation>[
      for (final month in firstMonth.through(calculationThrough))
        if (isEligibleForMonth(employment, month))
          calculateMonth(
            month: month,
            employment: employment,
            salaryHistory: salaryHistory,
            ruleHistory: ruleHistory,
            salarySchedule: salarySchedule,
          ),
    ];
  }

  Money calculateBalance({
    required Iterable<MonthlyPFCalculation> records,
    required Iterable<DatedMoney> knownProfit,
    required Iterable<DatedMoney> adjustments,
    required DateTime throughDate,
  }) {
    final prototype = _prototypeMoney(records, knownProfit, adjustments);
    var balance = Money.zero(
      decimalPlaces: prototype.decimalPlaces,
      currencyCode: prototype.currencyCode,
    );
    for (final record in records) {
      if (!record.month.firstDay.isAfter(throughDate)) {
        balance += record.totalContribution;
      }
    }
    for (final item in knownProfit) {
      if (!_dateOnly(item.date).isAfter(_dateOnly(throughDate))) balance += item.amount;
    }
    for (final item in adjustments) {
      if (!_dateOnly(item.date).isAfter(_dateOnly(throughDate))) balance += item.amount;
    }
    return balance;
  }

  ExitEstimate estimateExit({
    required DateTime exitDate,
    required EmploymentDates employment,
    required PFRuleVersion maturityRule,
    required Iterable<MonthlyPFCalculation> records,
    required Iterable<DatedMoney> knownProfit,
    required Iterable<DatedMoney> adjustments,
    required bool profitComplete,
  }) {
    final includedRecords = records.where((record) => !record.month.firstDay.isAfter(exitDate)).toList();
    final prototype = _prototypeMoney(includedRecords, knownProfit, adjustments);
    var employee = Money.zero(
      decimalPlaces: prototype.decimalPlaces,
      currencyCode: prototype.currencyCode,
    );
    var employer = employee;
    var profit = employee;
    var adjustmentTotal = employee;
    for (final record in includedRecords) {
      employee += record.employeeContribution;
      employer += record.employerContribution;
    }
    for (final item in knownProfit) {
      if (!_dateOnly(item.date).isAfter(_dateOnly(exitDate))) profit += item.amount;
    }
    for (final item in adjustments) {
      if (!_dateOnly(item.date).isAfter(_dateOnly(exitDate))) adjustmentTotal += item.amount;
    }
    final status = maturityStatus(exitDate, calculateMaturityDate(employment, maturityRule));
    final employerEntitled = status == MaturityStatus.mature
        ? maturityRule.employerEntitledAfterMaturity
        : maturityRule.employerEntitledBeforeMaturity;
    final receivedEmployer = employerEntitled ? employer : Money.zero(
      decimalPlaces: prototype.decimalPlaces,
      currencyCode: prototype.currencyCode,
    );
    return ExitEstimate(
      status: status,
      employeeContribution: employee,
      employerContribution: receivedEmployer,
      knownProfit: profit,
      adjustments: adjustmentTotal,
      forfeitedEmployerContribution: employerEntitled ? -Money.zero(
        decimalPlaces: prototype.decimalPlaces,
        currencyCode: prototype.currencyCode,
      ) : employer,
      estimatedReceivable: employee + receivedEmployer + profit + adjustmentTotal,
      profitComplete: profitComplete,
    );
  }

  StatementComparison reconcileStatement({
    required StatementSnapshot calculated,
    required StatementSnapshot actual,
  }) {
    return StatementComparison(
      calculated: calculated,
      actual: actual,
      openingDifference: _difference(actual.openingBalance, calculated.openingBalance),
      employeeDifference: _difference(
        actual.employeeContribution,
        calculated.employeeContribution,
      ),
      employerDifference: _difference(
        actual.employerContribution,
        calculated.employerContribution,
      ),
      profitDifference: _difference(actual.profit, calculated.profit),
      adjustmentDifference: _difference(actual.adjustments, calculated.adjustments),
      closingDifference: _difference(actual.closingBalance, calculated.closingBalance),
    );
  }

  static Money? _difference(Money? actual, Money? calculated) {
    if (actual == null || calculated == null) return null;
    return actual - calculated;
  }

  static Money _prototypeMoney(
    Iterable<MonthlyPFCalculation> records,
    Iterable<DatedMoney> knownProfit,
    Iterable<DatedMoney> adjustments,
  ) {
    for (final record in records) {
      return record.grossSalary;
    }
    for (final item in knownProfit) {
      return item.amount;
    }
    for (final item in adjustments) {
      return item.amount;
    }
    throw const MissingCalculationInput(
      'At least one monetary value is required to determine currency and precision.',
    );
  }

  static DateTime _addMonthsClamped(DateTime date, int months) {
    final targetMonth = DateTime(date.year, date.month + months);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    return DateTime(targetMonth.year, targetMonth.month, date.day > lastDay ? lastDay : date.day);
  }

  static DateTime _clampedDate(int year, int month, int requestedDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, requestedDay > lastDay ? lastDay : requestedDay);
  }

  static DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
}
