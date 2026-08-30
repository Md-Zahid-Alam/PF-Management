import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/database/app_database.dart' as db;
import 'package:pf_tracker/src/core/database/database_backup_service.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
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
    expect(database.schemaVersion, 2);
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

  test('used PF rules are protected from deletion', () async {
    final rules = DriftPFRuleRepository(database);
    final storedRule = _storedRule(now);
    await rules.save(storedRule);
    await DriftMonthlyPFRepository(database).create(_monthlyRecord(now: now));

    await expectLater(rules.deleteUnused(storedRule.rule.id), throwsStateError);
    expect(await rules.getForOrganization('organization-1'), hasLength(1));
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
    final service = DatabaseBackupService(database);
    final backup = await service.exportAll(
      appVersion: '0.1.0',
      exportedAt: now,
    );

    await DriftMonthlyPFRepository(database).delete('monthly-1');
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
  });

  test('invalid backup is rejected without deleting current data', () async {
    final service = DatabaseBackupService(database);

    await expectLater(
      service.restoreAll(<String, Object?>{'formatVersion': 999}),
      throwsA(isA<InvalidBackup>()),
    );

    expect(await database.select(database.employments).get(), hasLength(1));
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
