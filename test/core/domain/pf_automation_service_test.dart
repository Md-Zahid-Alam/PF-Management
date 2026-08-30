import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/historical_pf_service.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_automation_service.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

void main() {
  const engine = PFCalculationEngine();
  late _MemoryMonthlyRepository records;
  late _MemorySettingsRepository settings;
  late _RecordingNotificationGateway notifications;
  late PFAutomationService service;

  setUp(() {
    records = _MemoryMonthlyRepository();
    settings = _MemorySettingsRepository(const AutomationSettings());
    notifications = _RecordingNotificationGateway();
    service = PFAutomationService(
      engine: engine,
      monthlyRepository: records,
      settingsRepository: settings,
      notificationGateway: notifications,
    );
  });

  test('automatic catch-up creates every due month once', () async {
    final first = await service.processDuePeriods(
      today: DateTime(2026, 3, 12),
      employmentId: 'employment-1',
      employment: _employment,
      salaryHistory: <StoredSalary>[_salary()],
      ruleHistory: <StoredPFRule>[_rule()],
      schedules: <EffectiveSalarySchedule>[_schedule],
    );

    expect(first.map((result) => result.month), <YearMonth>[
      const YearMonth(2026, 1),
      const YearMonth(2026, 2),
    ]);
    expect(
      first.map((result) => result.status),
      everyElement(AutomationPeriodStatus.automaticallyCalculated),
    );
    expect(records.items, hasLength(2));
    expect(records.items.last.actualGenerationDate, DateTime(2026, 3, 12));
    expect(records.items.last.scheduledGenerationDate, DateTime(2026, 3, 10));

    final second = await service.processDuePeriods(
      today: DateTime(2026, 3, 12),
      employmentId: 'employment-1',
      employment: _employment,
      salaryHistory: <StoredSalary>[_salary()],
      ruleHistory: <StoredPFRule>[_rule()],
      schedules: <EffectiveSalarySchedule>[_schedule],
    );
    expect(
      second.map((result) => result.status),
      everyElement(AutomationPeriodStatus.alreadyExists),
    );
    expect(records.items, hasLength(2));
  });

  test(
    'Auto Calculate off leaves due periods ready for manual action',
    () async {
      await settings.save(const AutomationSettings(autoCalculate: false));

      final results = await service.processDuePeriods(
        today: DateTime(2026, 2, 12),
        employmentId: 'employment-1',
        employment: _employment,
        salaryHistory: <StoredSalary>[_salary()],
        ruleHistory: <StoredPFRule>[_rule()],
        schedules: <EffectiveSalarySchedule>[_schedule],
      );

      expect(records.items, isEmpty);
      expect(
        results.single.status,
        AutomationPeriodStatus.readyForManualCalculation,
      );
      expect(
        notifications.items.single.type,
        AutomationNotificationType.calculationDue,
      );
    },
  );

  test('missing salary never creates a zero-valued PF record', () async {
    final results = await service.processDuePeriods(
      today: DateTime(2026, 2, 12),
      employmentId: 'employment-1',
      employment: _employment,
      salaryHistory: const <StoredSalary>[],
      ruleHistory: <StoredPFRule>[_rule()],
      schedules: <EffectiveSalarySchedule>[_schedule],
    );

    expect(records.items, isEmpty);
    expect(
      results.single.status,
      AutomationPeriodStatus.pendingSalaryInformation,
    );
  });

  test('manual calculation uses the same deterministic engine', () async {
    final record = await service.calculateManually(
      now: DateTime(2026, 2, 12),
      employmentId: 'employment-1',
      employment: _employment,
      month: const YearMonth(2026, 1),
      salaryHistory: <StoredSalary>[_salary()],
      ruleHistory: <StoredPFRule>[_rule()],
      schedules: <EffectiveSalarySchedule>[_schedule],
    );

    expect(record.status, 'manuallyCalculated');
    expect(record.employeeContribution, Money.parse('1800'));
    expect(record.employerContribution, Money.parse('1800'));
  });

  test('historical recalculation preserves manual months by default', () async {
    final historical = HistoricalPFService(
      engine: engine,
      monthlyRepository: records,
    );
    await historical.generate(
      generatedAt: DateTime(2026, 3, 12),
      employmentId: 'employment-1',
      employment: _employment,
      calculationThrough: const YearMonth(2026, 2),
      salaryHistory: <StoredSalary>[_salary()],
      ruleHistory: <StoredPFRule>[_rule()],
      schedules: <EffectiveSalarySchedule>[_schedule],
    );
    records.items[0] = _recordWithStatus(records.items[0], 'manuallyAdjusted');

    final recalculated = await historical.generate(
      generatedAt: DateTime(2026, 3, 13),
      employmentId: 'employment-1',
      employment: _employment,
      calculationThrough: const YearMonth(2026, 2),
      salaryHistory: <StoredSalary>[_salary(gross: '40000')],
      ruleHistory: <StoredPFRule>[_rule()],
      schedules: <EffectiveSalarySchedule>[_schedule],
    );

    expect(recalculated.first.status, 'manuallyAdjusted');
    expect(recalculated.first.grossSalary, Money.parse('30000'));
    expect(recalculated.last.grossSalary, Money.parse('40000'));

    await historical.generate(
      generatedAt: DateTime(2026, 3, 14),
      employmentId: 'employment-1',
      employment: _employment,
      calculationThrough: const YearMonth(2026, 2),
      salaryHistory: <StoredSalary>[_salary(gross: '40000')],
      ruleHistory: <StoredPFRule>[_rule()],
      schedules: <EffectiveSalarySchedule>[_schedule],
      replaceManualMonths: const <YearMonth>{YearMonth(2026, 1)},
    );
    expect(records.items.first.grossSalary, Money.parse('40000'));
    expect(records.items.first.status, 'automaticallyCalculated');
  });

  test('historical preview starts at PF start and excludes unknown profit', () {
    final preview =
        HistoricalPFService(engine: engine, monthlyRepository: records).preview(
          employment: _employment,
          calculationThrough: const YearMonth(2026, 2),
          salaryHistory: <StoredSalary>[_salary()],
          ruleHistory: <StoredPFRule>[_rule()],
          schedules: <EffectiveSalarySchedule>[_schedule],
        );

    expect(preview.monthCount, 2);
    expect(preview.calculatedPF, Money.parse('7200'));
    expect(preview.profitKnown, isFalse);
  });
}

final _employment = EmploymentDates(
  joiningDate: DateTime(2025, 12, 15),
  pfStartDate: DateTime(2026),
);

final _schedule = EffectiveSalarySchedule(
  id: 'schedule-1',
  effectiveFrom: DateTime(2025),
  schedule: const SalarySchedule(
    paymentMonthOffset: 1,
    paymentWindowStartDay: 5,
    paymentWindowEndDay: 10,
  ),
);

StoredSalary _salary({String gross = '30000'}) {
  final now = DateTime(2026);
  return StoredSalary(
    id: 'salary-1',
    employmentId: 'employment-1',
    effectiveFrom: DateTime(2025),
    grossSalary: Money.parse(gross),
    createdAt: now,
    updatedAt: now,
  );
}

StoredPFRule _rule() {
  final now = DateTime(2026);
  return StoredPFRule(
    rule: PFRuleVersion(
      id: 'rule-1',
      effectiveFrom: DateTime(2025),
      basicSalaryRate: Rate.fromPercent('60'),
      employeePFRate: Rate.fromPercent('10'),
      employerPFRate: Rate.fromPercent('10'),
      maturityMonths: 24,
      maturityBasis: MaturityBasis.pfStartDate,
    ),
    organizationId: 'organization-1',
    partialMonthPolicy: PartialMonthPolicy.fullContribution,
    effectiveVersionPolicy: EffectiveVersionPolicy.monthEnd,
    createdAt: now,
    updatedAt: now,
  );
}

StoredMonthlyPFRecord _recordWithStatus(
  StoredMonthlyPFRecord record,
  String status,
) {
  return StoredMonthlyPFRecord(
    id: record.id,
    employmentId: record.employmentId,
    month: record.month,
    grossSalary: record.grossSalary,
    basicSalary: record.basicSalary,
    employeeContribution: record.employeeContribution,
    employerContribution: record.employerContribution,
    adjustment: record.adjustment,
    basicRate: record.basicRate,
    employeeRate: record.employeeRate,
    employerRate: record.employerRate,
    source: record.source,
    status: status,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
    salaryHistoryId: record.salaryHistoryId,
    ruleVersionId: record.ruleVersionId,
    scheduledGenerationDate: record.scheduledGenerationDate,
    actualGenerationDate: record.actualGenerationDate,
  );
}

class _MemoryMonthlyRepository implements MonthlyPFRepository {
  final List<StoredMonthlyPFRecord> items = <StoredMonthlyPFRecord>[];

  @override
  Future<void> create(StoredMonthlyPFRecord record) async {
    if (await findByMonth(record.employmentId, record.month) != null) {
      throw StateError('Duplicate month');
    }
    items.add(record);
  }

  @override
  Future<void> replaceCalculated(
    StoredMonthlyPFRecord record, {
    bool allowManualReplacement = false,
  }) async {
    final index = items.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      items.add(record);
      return;
    }
    if (items[index].status == 'manuallyAdjusted' && !allowManualReplacement) {
      throw StateError('Manual replacement not allowed');
    }
    items[index] = record;
  }

  @override
  Future<StoredMonthlyPFRecord?> findByMonth(
    String employmentId,
    YearMonth month,
  ) async {
    for (final item in items) {
      if (item.employmentId == employmentId && item.month == month) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<StoredMonthlyPFRecord>> getForEmployment(
    String employmentId,
  ) async {
    return items
        .where((item) => item.employmentId == employmentId)
        .toList(growable: false);
  }

  @override
  Future<void> saveManualAdjustment(
    StoredMonthlyPFRecord adjustedRecord,
  ) async {
    final index = items.indexWhere((item) => item.id == adjustedRecord.id);
    items[index] = adjustedRecord;
  }

  @override
  Future<void> confirm(String id, DateTime confirmedAt) async {}

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
  }
}

class _MemorySettingsRepository implements AutomationSettingsRepository {
  _MemorySettingsRepository(this.settings);

  AutomationSettings settings;

  @override
  Future<AutomationSettings> get() async => settings;

  @override
  Future<void> save(AutomationSettings settings) async {
    this.settings = settings;
  }
}

class _RecordingNotificationGateway implements AutomationNotificationGateway {
  final List<AutomationNotification> items = <AutomationNotification>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(AutomationNotification notification) async {
    items.add(notification);
  }
}
