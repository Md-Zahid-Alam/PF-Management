import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_automation_service.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

class HistoricalPFService {
  HistoricalPFService({
    required this.engine,
    required this.monthlyRepository,
    RecordIdFactory? idFactory,
  }) : idFactory = idFactory ?? _defaultId;

  final PFCalculationEngine engine;
  final MonthlyPFRepository monthlyRepository;
  final RecordIdFactory idFactory;

  HistoricalPFPreview preview({
    required EmploymentDates employment,
    required YearMonth calculationThrough,
    required List<StoredSalary> salaryHistory,
    required List<StoredPFRule> ruleHistory,
    required List<EffectiveSalarySchedule> schedules,
  }) {
    final calculations = _calculateHistory(
      employment: employment,
      calculationThrough: calculationThrough,
      salaryHistory: salaryHistory,
      ruleHistory: ruleHistory,
      schedules: schedules,
    );
    final zero = _zeroFor(salaryHistory);
    var employee = zero;
    var employer = zero;
    for (final item in calculations) {
      employee += item.calculation.employeeContribution;
      employer += item.calculation.employerContribution;
    }
    return HistoricalPFPreview(
      pfStart: YearMonth.fromDate(employment.pfStartDate),
      calculationThrough: calculationThrough,
      monthCount: calculations.length,
      employeeContribution: employee,
      employerContribution: employer,
      calculatedPF: employee + employer,
      profitKnown: false,
    );
  }

  Future<List<StoredMonthlyPFRecord>> generate({
    required DateTime generatedAt,
    required String employmentId,
    required EmploymentDates employment,
    required YearMonth calculationThrough,
    required List<StoredSalary> salaryHistory,
    required List<StoredPFRule> ruleHistory,
    required List<EffectiveSalarySchedule> schedules,
    Set<YearMonth> replaceManualMonths = const <YearMonth>{},
  }) async {
    final items = _calculateHistory(
      employment: employment,
      calculationThrough: calculationThrough,
      salaryHistory: salaryHistory,
      ruleHistory: ruleHistory,
      schedules: schedules,
    );
    final stored = <StoredMonthlyPFRecord>[];
    for (final item in items) {
      final existing = await monthlyRepository.findByMonth(
        employmentId,
        item.calculation.month,
      );
      final isManual = existing?.status == 'manuallyAdjusted';
      if (isManual && !replaceManualMonths.contains(item.calculation.month)) {
        stored.add(existing!);
        continue;
      }
      final record = _toStoredRecord(
        item: item,
        employmentId: employmentId,
        generatedAt: generatedAt,
        createdAt: existing?.createdAt ?? generatedAt,
      );
      if (existing == null) {
        await monthlyRepository.create(record);
      } else {
        await monthlyRepository.replaceCalculated(
          record,
          allowManualReplacement: isManual,
        );
      }
      stored.add(record);
    }
    return stored;
  }

  List<_HistoricalCalculation> _calculateHistory({
    required EmploymentDates employment,
    required YearMonth calculationThrough,
    required List<StoredSalary> salaryHistory,
    required List<StoredPFRule> ruleHistory,
    required List<EffectiveSalarySchedule> schedules,
  }) {
    final start = YearMonth.fromDate(employment.pfStartDate);
    final results = <_HistoricalCalculation>[];
    for (final month in start.through(calculationThrough)) {
      if (!engine.isEligibleForMonth(employment, month)) {
        continue;
      }
      final salary = _salaryFor(month, salaryHistory);
      if (salary == null) {
        throw MissingCalculationInput(
          'Salary information is required for historical month $month.',
        );
      }
      final rule = _ruleFor(month, ruleHistory);
      if (rule == null) {
        throw MissingCalculationInput(
          'PF rule information is required for historical month $month.',
        );
      }
      final schedule = DuePeriodDetector(engine).scheduleFor(month, schedules);
      final calculation = engine.calculateMonth(
        month: month,
        employment: employment,
        salaryHistory: <SalaryHistoryEntry>[
          SalaryHistoryEntry(
            effectiveFrom: salary.effectiveFrom,
            grossSalary: salary.grossSalary,
          ),
        ],
        ruleHistory: <PFRuleVersion>[rule.rule],
        salarySchedule: schedule.schedule,
      );
      results.add(
        _HistoricalCalculation(
          calculation: calculation,
          salary: salary,
          rule: rule,
        ),
      );
    }
    return results;
  }

  StoredMonthlyPFRecord _toStoredRecord({
    required _HistoricalCalculation item,
    required String employmentId,
    required DateTime generatedAt,
    required DateTime createdAt,
  }) {
    final calculation = item.calculation;
    return StoredMonthlyPFRecord(
      id: idFactory(employmentId, calculation.month),
      employmentId: employmentId,
      month: calculation.month,
      grossSalary: calculation.grossSalary,
      basicSalary: calculation.basicSalary,
      employeeContribution: calculation.employeeContribution,
      employerContribution: calculation.employerContribution,
      adjustment: Money.zero(
        decimalPlaces: calculation.grossSalary.decimalPlaces,
        currencyCode: calculation.grossSalary.currencyCode,
      ),
      basicRate: item.rule.rule.basicSalaryRate,
      employeeRate: item.rule.rule.employeePFRate,
      employerRate: item.rule.rule.employerPFRate,
      source: 'historicalAutomatic',
      status: 'automaticallyCalculated',
      createdAt: createdAt,
      updatedAt: generatedAt,
      salaryHistoryId: item.salary.id,
      ruleVersionId: item.rule.rule.id,
      scheduledGenerationDate: calculation.scheduledGenerationDate,
      actualGenerationDate: generatedAt,
    );
  }

  static Money _zeroFor(List<StoredSalary> salaryHistory) {
    if (salaryHistory.isEmpty) {
      return Money.zero();
    }
    final money = salaryHistory.first.grossSalary;
    return Money.zero(
      decimalPlaces: money.decimalPlaces,
      currencyCode: money.currencyCode,
    );
  }

  static StoredSalary? _salaryFor(YearMonth month, List<StoredSalary> history) {
    StoredSalary? selected;
    for (final salary in history) {
      if (!salary.effectiveFrom.isAfter(month.lastDay) &&
          (selected == null ||
              salary.effectiveFrom.isAfter(selected.effectiveFrom))) {
        selected = salary;
      }
    }
    return selected;
  }

  static StoredPFRule? _ruleFor(YearMonth month, List<StoredPFRule> history) {
    StoredPFRule? selected;
    for (final rule in history) {
      if (!rule.rule.effectiveFrom.isAfter(month.lastDay) &&
          (selected == null ||
              rule.rule.effectiveFrom.isAfter(selected.rule.effectiveFrom))) {
        selected = rule;
      }
    }
    return selected;
  }

  static String _defaultId(String employmentId, YearMonth month) {
    return 'monthly:$employmentId:$month';
  }
}

typedef RecordIdFactory = String Function(String employmentId, YearMonth month);

class _HistoricalCalculation {
  const _HistoricalCalculation({
    required this.calculation,
    required this.salary,
    required this.rule,
  });

  final MonthlyPFCalculation calculation;
  final StoredSalary salary;
  final StoredPFRule rule;
}
