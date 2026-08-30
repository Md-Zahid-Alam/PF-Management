import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

typedef RecordIdFactory = String Function(String employmentId, YearMonth month);

class DuePeriodDetector {
  const DuePeriodDetector(this.engine);

  final PFCalculationEngine engine;

  List<YearMonth> findDuePeriods({
    required DateTime today,
    required EmploymentDates employment,
    required List<EffectiveSalarySchedule> schedules,
  }) {
    final currentMonth = YearMonth.fromDate(today);
    final firstMonth = YearMonth.fromDate(employment.pfStartDate);
    return <YearMonth>[
      for (final month in firstMonth.through(currentMonth))
        if (engine.isEligibleForMonth(employment, month) &&
            !engine
                .scheduledGenerationDate(
                  month,
                  _scheduleFor(month, schedules).schedule,
                )
                .isAfter(_dateOnly(today)))
          month,
    ];
  }

  EffectiveSalarySchedule scheduleFor(
    YearMonth month,
    List<EffectiveSalarySchedule> schedules,
  ) {
    return _scheduleFor(month, schedules);
  }

  EffectiveSalarySchedule _scheduleFor(
    YearMonth month,
    List<EffectiveSalarySchedule> schedules,
  ) {
    EffectiveSalarySchedule? selected;
    for (final schedule in schedules) {
      if (!schedule.effectiveFrom.isAfter(month.lastDay) &&
          (selected == null ||
              schedule.effectiveFrom.isAfter(selected.effectiveFrom))) {
        selected = schedule;
      }
    }
    return selected ??
        (throw MissingCalculationInput(
          'Salary schedule is required for $month.',
        ));
  }
}

class PFAutomationService {
  PFAutomationService({
    required this.engine,
    required this.monthlyRepository,
    required this.settingsRepository,
    required this.notificationGateway,
    RecordIdFactory? idFactory,
  }) : idFactory = idFactory ?? _defaultId;

  final PFCalculationEngine engine;
  final MonthlyPFRepository monthlyRepository;
  final AutomationSettingsRepository settingsRepository;
  final AutomationNotificationGateway notificationGateway;
  final RecordIdFactory idFactory;

  Future<List<AutomationPeriodResult>> processDuePeriods({
    required DateTime today,
    required String employmentId,
    required EmploymentDates employment,
    required List<StoredSalary> salaryHistory,
    required List<StoredPFRule> ruleHistory,
    required List<EffectiveSalarySchedule> schedules,
  }) async {
    final settings = await settingsRepository.get();
    final detector = DuePeriodDetector(engine);
    final dueMonths = detector.findDuePeriods(
      today: today,
      employment: employment,
      schedules: schedules,
    );
    final results = <AutomationPeriodResult>[];
    for (final month in dueMonths) {
      final schedule = detector.scheduleFor(month, schedules).schedule;
      final scheduledDate = engine.scheduledGenerationDate(month, schedule);
      final existing = await monthlyRepository.findByMonth(employmentId, month);
      if (existing != null) {
        results.add(
          AutomationPeriodResult(
            month: month,
            scheduledGenerationDate: scheduledDate,
            status: AutomationPeriodStatus.alreadyExists,
            recordId: existing.id,
          ),
        );
        continue;
      }
      final salary = _salaryFor(month, salaryHistory);
      if (salary == null) {
        final result = AutomationPeriodResult(
          month: month,
          scheduledGenerationDate: scheduledDate,
          status: AutomationPeriodStatus.pendingSalaryInformation,
        );
        results.add(result);
        await _notifyIfEnabled(
          settings,
          AutomationNotification(
            type: AutomationNotificationType.missingSalaryInformation,
            title: 'Salary information required',
            body: '$month PF is waiting for salary information.',
            month: month,
          ),
        );
        continue;
      }
      final rule = _ruleFor(month, ruleHistory);
      if (rule == null) {
        results.add(
          AutomationPeriodResult(
            month: month,
            scheduledGenerationDate: scheduledDate,
            status: AutomationPeriodStatus.pendingRuleInformation,
          ),
        );
        continue;
      }
      if (!settings.autoCalculate) {
        final result = AutomationPeriodResult(
          month: month,
          scheduledGenerationDate: scheduledDate,
          status: AutomationPeriodStatus.readyForManualCalculation,
        );
        results.add(result);
        await _notifyIfEnabled(
          settings,
          AutomationNotification(
            type: AutomationNotificationType.calculationDue,
            title: 'PF calculation ready',
            body: '$month PF is ready for calculation.',
            month: month,
          ),
        );
        continue;
      }
      final record = _calculateRecord(
        today: today,
        employmentId: employmentId,
        employment: employment,
        month: month,
        salary: salary,
        rule: rule,
        schedule: schedule,
        source: 'automatic',
        status: 'automaticallyCalculated',
      );
      await _createDuplicateSafe(record);
      results.add(
        AutomationPeriodResult(
          month: month,
          scheduledGenerationDate: scheduledDate,
          status: AutomationPeriodStatus.automaticallyCalculated,
          recordId: record.id,
        ),
      );
      await _notifyIfEnabled(
        settings,
        AutomationNotification(
          type: AutomationNotificationType.automaticallyCalculated,
          title: 'PF calculated',
          body: '$month PF was calculated automatically.',
          month: month,
        ),
      );
    }
    return results;
  }

  Future<StoredMonthlyPFRecord> calculateManually({
    required DateTime now,
    required String employmentId,
    required EmploymentDates employment,
    required YearMonth month,
    required List<StoredSalary> salaryHistory,
    required List<StoredPFRule> ruleHistory,
    required List<EffectiveSalarySchedule> schedules,
  }) async {
    final existing = await monthlyRepository.findByMonth(employmentId, month);
    if (existing != null) {
      return existing;
    }
    final salary =
        _salaryFor(month, salaryHistory) ??
        (throw MissingCalculationInput(
          'Salary information is required for $month.',
        ));
    final rule =
        _ruleFor(month, ruleHistory) ??
        (throw MissingCalculationInput(
          'PF rule information is required for $month.',
        ));
    final schedule = DuePeriodDetector(engine)
        .scheduleFor(month, schedules)
        .schedule;
    final record = _calculateRecord(
      today: now,
      employmentId: employmentId,
      employment: employment,
      month: month,
      salary: salary,
      rule: rule,
      schedule: schedule,
      source: 'manual',
      status: 'manuallyCalculated',
    );
    await _createDuplicateSafe(record);
    return (await monthlyRepository.findByMonth(employmentId, month)) ?? record;
  }

  StoredMonthlyPFRecord _calculateRecord({
    required DateTime today,
    required String employmentId,
    required EmploymentDates employment,
    required YearMonth month,
    required StoredSalary salary,
    required StoredPFRule rule,
    required SalarySchedule schedule,
    required String source,
    required String status,
  }) {
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
      salarySchedule: schedule,
    );
    return StoredMonthlyPFRecord(
      id: idFactory(employmentId, month),
      employmentId: employmentId,
      month: month,
      grossSalary: calculation.grossSalary,
      basicSalary: calculation.basicSalary,
      employeeContribution: calculation.employeeContribution,
      employerContribution: calculation.employerContribution,
      adjustment: Money.zero(
        decimalPlaces: calculation.grossSalary.decimalPlaces,
        currencyCode: calculation.grossSalary.currencyCode,
      ),
      basicRate: rule.rule.basicSalaryRate,
      employeeRate: rule.rule.employeePFRate,
      employerRate: rule.rule.employerPFRate,
      source: source,
      status: status,
      createdAt: today,
      updatedAt: today,
      salaryHistoryId: salary.id,
      ruleVersionId: rule.rule.id,
      scheduledGenerationDate: calculation.scheduledGenerationDate,
      actualGenerationDate: today,
    );
  }

  Future<void> _createDuplicateSafe(StoredMonthlyPFRecord record) async {
    try {
      await monthlyRepository.create(record);
    } on Object {
      final existing = await monthlyRepository.findByMonth(
        record.employmentId,
        record.month,
      );
      if (existing == null) {
        rethrow;
      }
    }
  }

  Future<void> _notifyIfEnabled(
    AutomationSettings settings,
    AutomationNotification notification,
  ) async {
    if (settings.notificationsEnabled) {
      await notificationGateway.show(notification);
    }
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

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
