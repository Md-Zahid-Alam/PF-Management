import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/database/app_database.dart' as db;
import 'package:pf_tracker/src/core/database/database_backup_service.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/app_preferences.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

void main() {
  late db.AppDatabase database;
  late DateTime now;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 8, 28);
    await _seedEmployment(database, now);
  });

  tearDown(() => database.close());

  test('schema version and foreign keys are enabled', () async {
    expect(database.schemaVersion, 3);
    final result = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(result.read<int>('foreign_keys'), 1);
  });

  test('salary repository selects the latest applicable history', () async {
    final repository = DriftSalaryRepository(database);
    await repository.save(
      StoredSalary(
        id: 'salary-1',
        employmentId: 'employment-1',
        effectiveFrom: DateTime(2026),
        grossSalary: Money.parse('30000'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.save(
      StoredSalary(
        id: 'salary-2',
        employmentId: 'employment-1',
        effectiveFrom: DateTime(2026, 7),
        grossSalary: Money.parse('35000'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(
      (await repository.findApplicable(
        'employment-1',
        DateTime(2026, 6, 30),
      ))!.grossSalary,
      Money.parse('30000'),
    );
    expect(
      (await repository.findApplicable(
        'employment-1',
        DateTime(2026, 7, 31),
      ))!.grossSalary,
      Money.parse('35000'),
    );
  });

  test('database prevents duplicate employment and PF month records', () async {
    final repository = DriftMonthlyPFRepository(database);
    final record = _monthlyRecord(now: now);

    await repository.create(record);

    await expectLater(
      repository.create(_monthlyRecord(now: now, id: 'duplicate')),
      throwsA(anything),
    );
    expect(await repository.getForEmployment('employment-1'), hasLength(1));
  });

  test(
    'automation settings persist Auto Calculate and notifications',
    () async {
      final repository = DriftAutomationSettingsRepository(database);
      expect((await repository.get()).autoCalculate, isTrue);

      await repository.save(
        const AutomationSettings(
          autoCalculate: false,
          notificationsEnabled: false,
        ),
      );

      final stored = await repository.get();
      expect(stored.autoCalculate, isFalse);
      expect(stored.notificationsEnabled, isFalse);
    },
  );

  test(
    'theme preference persists independently of automation settings',
    () async {
      final themes = DriftThemePreferenceRepository(database);
      final automation = DriftAutomationSettingsRepository(database);

      expect(await themes.get(), AppThemePreference.system);
      await automation.save(
        const AutomationSettings(
          autoCalculate: false,
          notificationsEnabled: false,
        ),
      );
      await themes.save(AppThemePreference.dark);

      expect(await themes.get(), AppThemePreference.dark);
      final storedAutomation = await automation.get();
      expect(storedAutomation.autoCalculate, isFalse);
      expect(storedAutomation.notificationsEnabled, isFalse);
    },
  );

  test('initial setup is saved and loaded atomically', () async {
    final repository = DriftInitialSetupRepository(database);
    final setup = InitialPFSetup(
      employeeName: 'Zahid Alam',
      employeeCode: 'PF-100',
      organizationName: 'Example Company',
      joiningDate: DateTime(2024),
      probationStartDate: DateTime(2024),
      probationMonths: 6,
      permanentDate: DateTime(2024, 7),
      pfStartDate: DateTime(2025),
      exitDate: DateTime(2026),
      employmentStatus: 'left',
      salary: StoredSalary(
        id: 'initial-salary',
        employmentId: DriftInitialSetupRepository.employmentId,
        effectiveFrom: DateTime(2025),
        grossSalary: Money.parse('30000'),
        createdAt: now,
        updatedAt: now,
      ),
      rule: StoredPFRule(
        rule: PFRuleVersion(
          id: 'initial-pf-rule',
          effectiveFrom: DateTime(2025),
          basicSalaryRate: Rate.fromPercent('60'),
          employeePFRate: Rate.fromPercent('10'),
          employerPFRate: Rate.fromPercent('10'),
          maturityMonths: 24,
          maturityBasis: MaturityBasis.joiningDate,
        ),
        organizationId: DriftInitialSetupRepository.organizationId,
        partialMonthPolicy: PartialMonthPolicy.fullContribution,
        effectiveVersionPolicy: EffectiveVersionPolicy.monthEnd,
        createdAt: now,
        updatedAt: now,
      ),
      salarySchedule: EffectiveSalarySchedule(
        id: 'initial-schedule',
        effectiveFrom: DateTime(2025),
        schedule: const SalarySchedule(
          paymentMonthOffset: 1,
          paymentWindowStartMonthOffset: 0,
          paymentWindowStartDay: 28,
          paymentWindowEndDay: 5,
        ),
      ),
    );

    expect(await repository.hasCompletedSetup(), isFalse);
    await repository.save(setup);

    expect(await repository.hasCompletedSetup(), isTrue);
    final loaded = await repository.load();
    expect(loaded!.employeeName, 'Zahid Alam');
    expect(loaded.organizationName, 'Example Company');
    expect(loaded.probationMonths, 6);
    expect(loaded.employmentStatus, 'left');
    expect(loaded.exitDate, DateTime(2026));
    expect(loaded.salary.grossSalary, Money.parse('30000'));
    expect(loaded.rule.rule.maturityMonths, 24);
    expect(loaded.salarySchedule.schedule.paymentWindowStartMonthOffset, 0);
    expect(loaded.salarySchedule.schedule.paymentWindowStartDay, 28);
    expect(loaded.salarySchedule.schedule.paymentWindowEndDay, 5);
  });

  test(
    'manual adjustment preserves the original calculated snapshot',
    () async {
      final repository = DriftMonthlyPFRepository(database);
      final original = _monthlyRecord(now: now);
      await repository.create(original);

      await repository.saveManualAdjustment(
        StoredMonthlyPFRecord(
          id: original.id,
          employmentId: original.employmentId,
          month: original.month,
          grossSalary: Money.parse('31000'),
          basicSalary: Money.parse('18600'),
          employeeContribution: Money.parse('1860'),
          employerContribution: Money.parse('1860'),
          adjustment: Money.zero(),
          basicRate: Rate.fromPercent('60'),
          employeeRate: Rate.fromPercent('10'),
          employerRate: Rate.fromPercent('10'),
          source: 'manual',
          status: 'manuallyAdjusted',
          createdAt: original.createdAt,
          updatedAt: now.add(const Duration(minutes: 1)),
          ruleVersionId: original.ruleVersionId,
        ),
      );

      final stored = await repository.findByMonth(
        'employment-1',
        const YearMonth(2026, 4),
      );
      expect(stored!.grossSalary, Money.parse('31000'));
      expect(stored.originalGrossSalary, Money.parse('30000'));
      expect(stored.originalEmployeeContribution, Money.parse('1800'));
      expect(stored.status, 'manuallyAdjusted');
    },
  );

  test('monthly record confirmation persists its reviewed status', () async {
    final repository = DriftMonthlyPFRepository(database);
    await repository.create(_monthlyRecord(now: now));
    final confirmedAt = now.add(const Duration(minutes: 5));

    await repository.confirm('monthly-1', confirmedAt);

    final stored = await repository.findByMonth(
      'employment-1',
      const YearMonth(2026, 4),
    );
    expect(stored!.status, 'confirmed');
    expect(stored.confirmedAt, confirmedAt);
  });

  test(
    'profit repository persists, edits, and deletes profit history',
    () async {
      final repository = DriftProfitRepository(database);
      final original = StoredProfitRecord(
        id: 'profit-1',
        employmentId: 'employment-1',
        periodStart: DateTime(2025, 7),
        periodEnd: DateTime(2026, 6, 30),
        creditedDate: DateTime(2026, 8, 15),
        amount: Money.parse('12500'),
        optionalRate: Rate.fromPercent('7.5'),
        calculationMethod: 'Annual statement',
        sourceReference: 'PF-2026',
        createdAt: now,
        updatedAt: now,
      );

      await repository.save(original);
      var stored = (await repository.getForEmployment('employment-1')).single;
      expect(stored.amount, Money.parse('12500'));
      expect(stored.optionalRate, Rate.fromPercent('7.5'));
      expect(stored.sourceReference, 'PF-2026');

      await repository.save(
        StoredProfitRecord(
          id: original.id,
          employmentId: original.employmentId,
          periodStart: original.periodStart,
          periodEnd: original.periodEnd,
          creditedDate: original.creditedDate,
          amount: Money.parse('13000'),
          notes: 'Corrected statement',
          createdAt: original.createdAt,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      stored = (await repository.getForEmployment('employment-1')).single;
      expect(stored.amount, Money.parse('13000'));
      expect(stored.notes, 'Corrected statement');

      await repository.delete(original.id);
      expect(await repository.getForEmployment('employment-1'), isEmpty);
    },
  );

  test('profit repository rejects a reversed statement period', () async {
    final repository = DriftProfitRepository(database);
    await expectLater(
      repository.save(
        StoredProfitRecord(
          id: 'profit-invalid',
          employmentId: 'employment-1',
          periodStart: DateTime(2026, 7),
          periodEnd: DateTime(2026, 6),
          creditedDate: DateTime(2026, 8),
          amount: Money.parse('1000'),
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('used PF rules are protected from deletion', () async {
    final rules = DriftPFRuleRepository(database);
    final storedRule = _storedRule(now);
    await rules.save(storedRule);
    await DriftMonthlyPFRepository(database).create(_monthlyRecord(now: now));

    await expectLater(rules.deleteUnused(storedRule.rule.id), throwsStateError);
    expect(await rules.getForOrganization('organization-1'), hasLength(1));
  });

  test('used PF rules are protected from destructive editing', () async {
    final rules = DriftPFRuleRepository(database);
    final storedRule = _storedRule(now);
    await rules.save(storedRule);
    await DriftMonthlyPFRepository(database).create(_monthlyRecord(now: now));

    await expectLater(
      rules.save(
        StoredPFRule(
          rule: PFRuleVersion(
            id: storedRule.rule.id,
            effectiveFrom: storedRule.rule.effectiveFrom,
            basicSalaryRate: storedRule.rule.basicSalaryRate,
            employeePFRate: Rate.fromPercent('12'),
            employerPFRate: storedRule.rule.employerPFRate,
            maturityMonths: storedRule.rule.maturityMonths,
            maturityBasis: storedRule.rule.maturityBasis,
          ),
          organizationId: storedRule.organizationId,
          partialMonthPolicy: storedRule.partialMonthPolicy,
          effectiveVersionPolicy: storedRule.effectiveVersionPolicy,
          createdAt: storedRule.createdAt,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      ),
      throwsStateError,
    );
    final unchanged = (await rules.getForOrganization('organization-1')).single;
    expect(unchanged.rule.employeePFRate, Rate.fromPercent('10'));
  });

  test('backup round-trip restores all persisted data atomically', () async {
    final salaries = DriftSalaryRepository(database);
    await salaries.save(
      StoredSalary(
        id: 'salary-1',
        employmentId: 'employment-1',
        effectiveFrom: DateTime(2026),
        grossSalary: Money.parse('30000'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await DriftPFRuleRepository(database).save(_storedRule(now));
    await DriftMonthlyPFRepository(database).create(_monthlyRecord(now: now));
    await DriftProfitRepository(database).save(
      StoredProfitRecord(
        id: 'profit-backup',
        employmentId: 'employment-1',
        creditedDate: DateTime(2026, 6, 30),
        amount: Money.zero(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await DriftActualPFStatementRepository(database).save(
      StoredActualPFStatement(
        id: 'actual-backup',
        employmentId: 'employment-1',
        statementStartYear: 2025,
        snapshot: StatementSnapshot(closingBalance: Money.parse('7200')),
        decimalPlaces: 0,
        currencyCode: 'BDT',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await DriftStatementYearDefinitionRepository(database).save(
      StoredStatementYearDefinition(
        id: 'statement-year-backup',
        organizationId: 'organization-1',
        effectiveFrom: DateTime(2025, 7),
        configuration: const StatementYearConfiguration(
          startMonth: DateTime.july,
          startDay: 1,
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await DriftAutomationSettingsRepository(database)
        .save(const AutomationSettings(autoCalculate: false));
    await DriftThemePreferenceRepository(database)
        .save(AppThemePreference.dark);
    final service = DatabaseBackupService(database);
    final backup = await service.exportAll(
      appVersion: '0.1.0',
      exportedAt: now,
    );

    await DriftMonthlyPFRepository(database).delete('monthly-1');
    await DriftProfitRepository(database).delete('profit-backup');
    await DriftActualPFStatementRepository(database).delete('actual-backup');
    await database.delete(database.statementYearDefinitions).go();
    await database.delete(database.appSettingsRows).go();
    expect(
      await DriftMonthlyPFRepository(database).getForEmployment('employment-1'),
      isEmpty,
    );

    await service.restoreAll(backup);

    expect(
      await DriftMonthlyPFRepository(database).getForEmployment('employment-1'),
      hasLength(1),
    );
    expect(await salaries.getForEmployment('employment-1'), hasLength(1));
    expect(
      await DriftProfitRepository(database).getForEmployment('employment-1'),
      hasLength(1),
    );
    expect(
      await DriftActualPFStatementRepository(database)
          .getForEmployment('employment-1'),
      hasLength(1),
    );
    expect(
      await DriftStatementYearDefinitionRepository(database)
          .getForOrganization('organization-1'),
      hasLength(1),
    );
    expect(
      (await DriftAutomationSettingsRepository(database).get()).autoCalculate,
      isFalse,
    );
    expect(
      await DriftThemePreferenceRepository(database).get(),
      AppThemePreference.dark,
    );
  });

  test('actual PF statements persist nullable official values', () async {
    final repository = DriftActualPFStatementRepository(database);
    await repository.save(
      StoredActualPFStatement(
        id: 'actual-2025',
        employmentId: 'employment-1',
        statementStartYear: 2025,
        statementDate: DateTime(2026, 6, 30),
        snapshot: StatementSnapshot(
          openingBalance: Money.parse('100000'),
          employeeContribution: Money.parse('12000'),
          employerContribution: Money.parse('12000'),
          closingBalance: Money.parse('128500'),
        ),
        decimalPlaces: 0,
        currencyCode: 'BDT',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final statement = (await repository.getForEmployment('employment-1'))
        .single;
    expect(statement.statementStartYear, 2025);
    expect(statement.snapshot.closingBalance, Money.parse('128500'));
    expect(statement.snapshot.profit, isNull);
  });

  test(
    'statement year definitions persist as effective-dated history',
    () async {
      final repository = DriftStatementYearDefinitionRepository(database);
      await repository.save(
        StoredStatementYearDefinition(
          id: 'statement-year-1',
          organizationId: 'organization-1',
          effectiveFrom: DateTime(2025, 7),
          configuration: const StatementYearConfiguration(
            startMonth: DateTime.july,
            startDay: 1,
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final definition = (await repository.getForOrganization('organization-1'))
          .single;
      expect(definition.effectiveFrom, DateTime(2025, 7));
      expect(definition.configuration.startMonth, DateTime.july);
      expect(definition.configuration.startDay, 1);
    },
  );

  test('invalid backup is rejected without deleting current data', () async {
    final service = DatabaseBackupService(database);

    await expectLater(
      service.restoreAll(<String, Object?>{'formatVersion': 999}),
      throwsA(isA<InvalidBackup>()),
    );

    expect(await database.select(database.employments).get(), hasLength(1));
  });

  test('version 1 backup migrates before atomic restore', () async {
    final service = DatabaseBackupService(database);
    final backup = await service.exportAll(
      appVersion: '0.1.0',
      exportedAt: now,
    );
    backup['formatVersion'] = 1;

    await service.restoreAll(backup);

    final restoredProfile = await database
        .select(database.userProfiles)
        .getSingle();
    expect(restoredProfile.id, 'profile-1');
    expect(restoredProfile.employeeName, 'Test Employee');
    expect(await database.select(database.employments).get(), hasLength(1));
  });

  test('version 2 backup restores a same-month payment window', () async {
    await database
        .into(database.salarySchedules)
        .insert(
          db.SalarySchedulesCompanion.insert(
            id: 'legacy-schedule',
            organizationId: 'organization-1',
            effectiveFrom: DateTime(2026),
            paymentMonthOffset: 1,
            paymentWindowStartMonthOffset: const Value(1),
            paymentWindowStartDay: 1,
            paymentWindowEndDay: 5,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final service = DatabaseBackupService(database);
    final backup = await service.exportAll(
      appVersion: '0.1.0',
      exportedAt: now,
    );
    backup['formatVersion'] = 2;
    final data = backup['data']! as Map<String, Object?>;
    final schedules = data['salarySchedules']! as List<Object?>;
    final schedule = schedules.single! as Map<String, Object?>;
    schedule.remove('paymentWindowStartMonthOffset');

    await service.restoreAll(backup);

    final restored = await database
        .select(database.salarySchedules)
        .getSingle();
    expect(restored.paymentMonthOffset, 1);
    expect(restored.paymentWindowStartMonthOffset, 1);
  });

  test('foreign-key failure rolls back an in-progress restore', () async {
    final service = DatabaseBackupService(database);
    final backup = await service.exportAll(
      appVersion: '0.1.0',
      exportedAt: now,
    );
    final data = backup['data']! as Map<String, Object?>;
    final employments = data['employments']! as List<Object?>;
    final employment = employments.single! as Map<String, Object?>;
    employment['organizationId'] = 'missing-organization';

    await expectLater(service.restoreAll(backup), throwsA(anything));

    final preserved = await database.select(database.employments).getSingle();
    expect(preserved.organizationId, 'organization-1');
    expect(await database.select(database.organizations).get(), hasLength(1));
  });

  test('delete all removes parent and dependent data atomically', () async {
    await DriftPFRuleRepository(database).save(_storedRule(now));
    await DriftMonthlyPFRepository(database).create(_monthlyRecord(now: now));

    await DatabaseBackupService(database).deleteAll();

    expect(await database.select(database.monthlyPfRecords).get(), isEmpty);
    expect(await database.select(database.pfRuleVersions).get(), isEmpty);
    expect(await database.select(database.employments).get(), isEmpty);
    expect(await database.select(database.organizations).get(), isEmpty);
    expect(await database.select(database.userProfiles).get(), isEmpty);
  });
}

Future<void> _seedEmployment(db.AppDatabase database, DateTime now) async {
  await database
      .into(database.userProfiles)
      .insert(
        db.UserProfilesCompanion.insert(
          id: 'profile-1',
          employeeName: 'Test Employee',
          preferredCurrency: 'BDT',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.organizations)
      .insert(
        db.OrganizationsCompanion.insert(
          id: 'organization-1',
          name: 'Test Organization',
          currencyCode: 'BDT',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.employments)
      .insert(
        db.EmploymentsCompanion.insert(
          id: 'employment-1',
          profileId: 'profile-1',
          organizationId: 'organization-1',
          joiningDate: DateTime(2026),
          pfStartDate: DateTime(2026, 4),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await DriftPFRuleRepository(database).save(_storedRule(now));
}

StoredPFRule _storedRule(DateTime now) {
  return StoredPFRule(
    rule: PFRuleVersion(
      id: 'rule-1',
      effectiveFrom: DateTime(2026),
      basicSalaryRate: Rate.fromPercent('60'),
      employeePFRate: Rate.fromPercent('10'),
      employerPFRate: Rate.fromPercent('10'),
      maturityMonths: 24,
      maturityBasis: MaturityBasis.joiningDate,
    ),
    organizationId: 'organization-1',
    partialMonthPolicy: PartialMonthPolicy.fullContribution,
    effectiveVersionPolicy: EffectiveVersionPolicy.monthEnd,
    createdAt: now,
    updatedAt: now,
  );
}

StoredMonthlyPFRecord _monthlyRecord({
  required DateTime now,
  String id = 'monthly-1',
}) {
  return StoredMonthlyPFRecord(
    id: id,
    employmentId: 'employment-1',
    month: const YearMonth(2026, 4),
    grossSalary: Money.parse('30000'),
    basicSalary: Money.parse('18000'),
    employeeContribution: Money.parse('1800'),
    employerContribution: Money.parse('1800'),
    adjustment: Money.zero(),
    basicRate: Rate.fromPercent('60'),
    employeeRate: Rate.fromPercent('10'),
    employerRate: Rate.fromPercent('10'),
    source: 'automatic',
    status: 'automaticallyCalculated',
    createdAt: now,
    updatedAt: now,
    ruleVersionId: 'rule-1',
  );
}
