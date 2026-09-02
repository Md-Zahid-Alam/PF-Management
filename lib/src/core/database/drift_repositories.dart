import 'package:drift/drift.dart';
import 'package:pf_tracker/src/core/database/app_database.dart' as db;
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

class DriftSalaryRepository implements SalaryRepository {
  DriftSalaryRepository(this.database);

  final db.AppDatabase database;

  @override
  Future<List<StoredSalary>> getForEmployment(String employmentId) async {
    final query = database.select(database.salaryHistoryRows)
      ..where((row) => row.employmentId.equals(employmentId))
      ..orderBy([(row) => OrderingTerm.asc(row.effectiveFrom)]);
    return (await query.get()).map(_salaryFromRow).toList(growable: false);
  }

  @override
  Future<StoredSalary?> findApplicable(
    String employmentId,
    DateTime onDate,
  ) async {
    final query = database.select(database.salaryHistoryRows)
      ..where(
        (row) =>
            row.employmentId.equals(employmentId) &
            row.effectiveFrom.isSmallerOrEqualValue(_dateOnly(onDate)),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.effectiveFrom)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _salaryFromRow(row);
  }

  @override
  Future<void> save(StoredSalary salary) async {
    await database
        .into(database.salaryHistoryRows)
        .insertOnConflictUpdate(
          db.SalaryHistoryRowsCompanion.insert(
            id: salary.id,
            employmentId: salary.employmentId,
            effectiveFrom: _dateOnly(salary.effectiveFrom),
            grossMinorUnits: salary.grossSalary.minorUnits,
            decimalPlaces: salary.grossSalary.decimalPlaces,
            currencyCode: salary.grossSalary.currencyCode,
            createdAt: salary.createdAt,
            updatedAt: salary.updatedAt,
            notes: Value(salary.notes),
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.salaryHistoryRows,
    )..where((row) => row.id.equals(id))).go();
  }

  static StoredSalary _salaryFromRow(db.SalaryHistoryRow row) {
    return StoredSalary(
      id: row.id,
      employmentId: row.employmentId,
      effectiveFrom: row.effectiveFrom,
      grossSalary: Money.fromMinorUnits(
        row.grossMinorUnits,
        decimalPlaces: row.decimalPlaces,
        currencyCode: row.currencyCode,
      ),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      notes: row.notes,
    );
  }
}

class DriftPFRuleRepository implements PFRuleRepository {
  DriftPFRuleRepository(this.database);

  final db.AppDatabase database;

  @override
  Future<List<StoredPFRule>> getForOrganization(String organizationId) async {
    final query = database.select(database.pfRuleVersions)
      ..where((row) => row.organizationId.equals(organizationId))
      ..orderBy([(row) => OrderingTerm.asc(row.effectiveFrom)]);
    return (await query.get()).map(_ruleFromRow).toList(growable: false);
  }

  @override
  Future<StoredPFRule?> findApplicable(
    String organizationId,
    DateTime onDate,
  ) async {
    final query = database.select(database.pfRuleVersions)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.effectiveFrom.isSmallerOrEqualValue(_dateOnly(onDate)),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.effectiveFrom)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _ruleFromRow(row);
  }

  @override
  Future<void> save(StoredPFRule stored) async {
    final rule = stored.rule;
    await database
        .into(database.pfRuleVersions)
        .insertOnConflictUpdate(
          db.PfRuleVersionsCompanion.insert(
            id: rule.id,
            organizationId: stored.organizationId,
            effectiveFrom: _dateOnly(rule.effectiveFrom),
            basicRatePpm: rule.basicSalaryRate.partsPerMillion,
            employeeRatePpm: rule.employeePFRate.partsPerMillion,
            employerRatePpm: rule.employerPFRate.partsPerMillion,
            maturityMonths: rule.maturityMonths,
            maturityBasis: rule.maturityBasis.name,
            employerEntitledBeforeMaturity: Value(
              rule.employerEntitledBeforeMaturity,
            ),
            employerEntitledAfterMaturity: Value(
              rule.employerEntitledAfterMaturity,
            ),
            partialMonthPolicy: Value(stored.partialMonthPolicy.name),
            effectiveVersionPolicy: Value(stored.effectiveVersionPolicy.name),
            notes: Value(stored.notes),
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt,
          ),
        );
  }

  @override
  Future<void> deleteUnused(String id) async {
    final referenced =
        await (database.select(database.monthlyPfRecords)
              ..where((row) => row.ruleVersionId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (referenced != null) {
      throw StateError('A PF rule used by monthly records cannot be deleted.');
    }
    await (database.delete(
      database.pfRuleVersions,
    )..where((row) => row.id.equals(id))).go();
  }

  static StoredPFRule _ruleFromRow(db.PfRuleVersion row) {
    return StoredPFRule(
      rule: PFRuleVersion(
        id: row.id,
        effectiveFrom: row.effectiveFrom,
        basicSalaryRate: Rate.fromPartsPerMillion(row.basicRatePpm),
        employeePFRate: Rate.fromPartsPerMillion(row.employeeRatePpm),
        employerPFRate: Rate.fromPartsPerMillion(row.employerRatePpm),
        maturityMonths: row.maturityMonths,
        maturityBasis: MaturityBasis.values.byName(row.maturityBasis),
        employerEntitledBeforeMaturity: row.employerEntitledBeforeMaturity,
        employerEntitledAfterMaturity: row.employerEntitledAfterMaturity,
      ),
      organizationId: row.organizationId,
      partialMonthPolicy: PartialMonthPolicy.values.byName(
        row.partialMonthPolicy,
      ),
      effectiveVersionPolicy: EffectiveVersionPolicy.values.byName(
        row.effectiveVersionPolicy,
      ),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      notes: row.notes,
    );
  }
}

class DriftMonthlyPFRepository implements MonthlyPFRepository {
  DriftMonthlyPFRepository(this.database);

  final db.AppDatabase database;

  @override
  Future<List<StoredMonthlyPFRecord>> getForEmployment(
    String employmentId,
  ) async {
    final query = database.select(database.monthlyPfRecords)
      ..where((row) => row.employmentId.equals(employmentId))
      ..orderBy([(row) => OrderingTerm.asc(row.pfMonth)]);
    return (await query.get()).map(_monthlyFromRow).toList(growable: false);
  }

  @override
  Future<StoredMonthlyPFRecord?> findByMonth(
    String employmentId,
    YearMonth month,
  ) async {
    final row =
        await (database.select(database.monthlyPfRecords)..where(
              (row) =>
                  row.employmentId.equals(employmentId) &
                  row.pfMonth.equals(month.firstDay),
            ))
            .getSingleOrNull();
    return row == null ? null : _monthlyFromRow(row);
  }

  @override
  Future<void> create(StoredMonthlyPFRecord record) async {
    _validateMonthlyMoney(record);
    await database
        .into(database.monthlyPfRecords)
        .insert(_monthlyCompanion(record));
  }

  @override
  Future<void> replaceCalculated(
    StoredMonthlyPFRecord record, {
    bool allowManualReplacement = false,
  }) async {
    _validateMonthlyMoney(record);
    await database.transaction(() async {
      final existing = await (database.select(
        database.monthlyPfRecords,
      )..where((row) => row.id.equals(record.id))).getSingleOrNull();
      if (existing == null) {
        await database
            .into(database.monthlyPfRecords)
            .insert(_monthlyCompanion(record));
        return;
      }
      if (existing.status == 'manuallyAdjusted' && !allowManualReplacement) {
        throw StateError(
          'A manually adjusted month requires explicit replacement.',
        );
      }
      if (existing.employmentId != record.employmentId ||
          YearMonth.fromDate(existing.pfMonth) != record.month) {
        throw StateError('Recalculation cannot change record identity.');
      }
      await database
          .into(database.monthlyPfRecords)
          .insertOnConflictUpdate(
            _monthlyCompanion(
              _copyRecord(record, createdAt: existing.createdAt),
            ),
          );
    });
  }

  @override
  Future<void> saveManualAdjustment(
    StoredMonthlyPFRecord adjustedRecord,
  ) async {
    await database.transaction(() async {
      final existing = await (database.select(
        database.monthlyPfRecords,
      )..where((row) => row.id.equals(adjustedRecord.id))).getSingle();
      if (existing.employmentId != adjustedRecord.employmentId ||
          YearMonth.fromDate(existing.pfMonth) != adjustedRecord.month) {
        throw StateError('A manual adjustment cannot change record identity.');
      }
      _validateMonthlyMoney(adjustedRecord);
      final audited = StoredMonthlyPFRecord(
        id: adjustedRecord.id,
        employmentId: adjustedRecord.employmentId,
        month: adjustedRecord.month,
        grossSalary: adjustedRecord.grossSalary,
        basicSalary: adjustedRecord.basicSalary,
        employeeContribution: adjustedRecord.employeeContribution,
        employerContribution: adjustedRecord.employerContribution,
        adjustment: adjustedRecord.adjustment,
        basicRate: adjustedRecord.basicRate,
        employeeRate: adjustedRecord.employeeRate,
        employerRate: adjustedRecord.employerRate,
        source: adjustedRecord.source,
        status: 'manuallyAdjusted',
        createdAt: existing.createdAt,
        updatedAt: adjustedRecord.updatedAt,
        salaryHistoryId: adjustedRecord.salaryHistoryId,
        ruleVersionId: adjustedRecord.ruleVersionId,
        salaryCreditedDate: adjustedRecord.salaryCreditedDate,
        scheduledGenerationDate: adjustedRecord.scheduledGenerationDate,
        actualGenerationDate: adjustedRecord.actualGenerationDate,
        originalGrossSalary:
            adjustedRecord.originalGrossSalary ??
            _money(
              existing.grossMinorUnits,
              existing.decimalPlaces,
              existing.currencyCode,
            ),
        originalBasicSalary:
            adjustedRecord.originalBasicSalary ??
            _money(
              existing.basicMinorUnits,
              existing.decimalPlaces,
              existing.currencyCode,
            ),
        originalEmployeeContribution:
            adjustedRecord.originalEmployeeContribution ??
            _money(
              existing.employeeMinorUnits,
              existing.decimalPlaces,
              existing.currencyCode,
            ),
        originalEmployerContribution:
            adjustedRecord.originalEmployerContribution ??
            _money(
              existing.employerMinorUnits,
              existing.decimalPlaces,
              existing.currencyCode,
            ),
        manuallyAdjustedAt:
            adjustedRecord.manuallyAdjustedAt ?? adjustedRecord.updatedAt,
        confirmedAt: adjustedRecord.confirmedAt,
        notes: adjustedRecord.notes,
      );
      await database
          .into(database.monthlyPfRecords)
          .insertOnConflictUpdate(_monthlyCompanion(audited));
    });
  }

  @override
  Future<void> confirm(String id, DateTime confirmedAt) async {
    await (database.update(
      database.monthlyPfRecords,
    )..where((row) => row.id.equals(id))).write(
      db.MonthlyPfRecordsCompanion(
        status: const Value('confirmed'),
        confirmedAt: Value(confirmedAt),
        updatedAt: Value(confirmedAt),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.monthlyPfRecords,
    )..where((row) => row.id.equals(id))).go();
  }

  static db.MonthlyPfRecordsCompanion _monthlyCompanion(
    StoredMonthlyPFRecord record,
  ) {
    return db.MonthlyPfRecordsCompanion.insert(
      id: record.id,
      employmentId: record.employmentId,
      pfMonth: record.month.firstDay,
      salaryCreditedDate: Value(record.salaryCreditedDate),
      salaryHistoryId: Value(record.salaryHistoryId),
      ruleVersionId: Value(record.ruleVersionId),
      grossMinorUnits: record.grossSalary.minorUnits,
      basicMinorUnits: record.basicSalary.minorUnits,
      employeeMinorUnits: record.employeeContribution.minorUnits,
      employerMinorUnits: record.employerContribution.minorUnits,
      adjustmentMinorUnits: Value(record.adjustment.minorUnits),
      decimalPlaces: record.grossSalary.decimalPlaces,
      currencyCode: record.grossSalary.currencyCode,
      basicRatePpm: record.basicRate.partsPerMillion,
      employeeRatePpm: record.employeeRate.partsPerMillion,
      employerRatePpm: record.employerRate.partsPerMillion,
      scheduledGenerationDate: Value(record.scheduledGenerationDate),
      actualGenerationDate: Value(record.actualGenerationDate),
      source: record.source,
      status: record.status,
      originalGrossMinorUnits: Value(record.originalGrossSalary?.minorUnits),
      originalBasicMinorUnits: Value(record.originalBasicSalary?.minorUnits),
      originalEmployeeMinorUnits: Value(
        record.originalEmployeeContribution?.minorUnits,
      ),
      originalEmployerMinorUnits: Value(
        record.originalEmployerContribution?.minorUnits,
      ),
      manuallyAdjustedAt: Value(record.manuallyAdjustedAt),
      confirmedAt: Value(record.confirmedAt),
      notes: Value(record.notes),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  static void _validateMonthlyMoney(StoredMonthlyPFRecord record) {
    for (final value in <Money>[
      record.basicSalary,
      record.employeeContribution,
      record.employerContribution,
      record.adjustment,
      if (record.originalGrossSalary != null) record.originalGrossSalary!,
      if (record.originalBasicSalary != null) record.originalBasicSalary!,
      if (record.originalEmployeeContribution != null)
        record.originalEmployeeContribution!,
      if (record.originalEmployerContribution != null)
        record.originalEmployerContribution!,
    ]) {
      record.grossSalary.compareTo(value);
    }
  }

  static StoredMonthlyPFRecord _monthlyFromRow(db.MonthlyPfRecord row) {
    final decimalPlaces = row.decimalPlaces;
    final currencyCode = row.currencyCode;
    return StoredMonthlyPFRecord(
      id: row.id,
      employmentId: row.employmentId,
      month: YearMonth.fromDate(row.pfMonth),
      grossSalary: _money(row.grossMinorUnits, decimalPlaces, currencyCode),
      basicSalary: _money(row.basicMinorUnits, decimalPlaces, currencyCode),
      employeeContribution: _money(
        row.employeeMinorUnits,
        decimalPlaces,
        currencyCode,
      ),
      employerContribution: _money(
        row.employerMinorUnits,
        decimalPlaces,
        currencyCode,
      ),
      adjustment: _money(row.adjustmentMinorUnits, decimalPlaces, currencyCode),
      basicRate: Rate.fromPartsPerMillion(row.basicRatePpm),
      employeeRate: Rate.fromPartsPerMillion(row.employeeRatePpm),
      employerRate: Rate.fromPartsPerMillion(row.employerRatePpm),
      source: row.source,
      status: row.status,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      salaryHistoryId: row.salaryHistoryId,
      ruleVersionId: row.ruleVersionId,
      salaryCreditedDate: row.salaryCreditedDate,
      scheduledGenerationDate: row.scheduledGenerationDate,
      actualGenerationDate: row.actualGenerationDate,
      originalGrossSalary: _nullableMoney(
        row.originalGrossMinorUnits,
        decimalPlaces,
        currencyCode,
      ),
      originalBasicSalary: _nullableMoney(
        row.originalBasicMinorUnits,
        decimalPlaces,
        currencyCode,
      ),
      originalEmployeeContribution: _nullableMoney(
        row.originalEmployeeMinorUnits,
        decimalPlaces,
        currencyCode,
      ),
      originalEmployerContribution: _nullableMoney(
        row.originalEmployerMinorUnits,
        decimalPlaces,
        currencyCode,
      ),
      manuallyAdjustedAt: row.manuallyAdjustedAt,
      confirmedAt: row.confirmedAt?.toUtc(),
      notes: row.notes,
    );
  }
}

class DriftAutomationSettingsRepository
    implements AutomationSettingsRepository {
  DriftAutomationSettingsRepository(this.database);

  final db.AppDatabase database;

  @override
  Future<AutomationSettings> get() async {
    final row = await (database.select(
      database.appSettingsRows,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    if (row != null) {
      return AutomationSettings(
        autoCalculate: row.autoCalculate,
        notificationsEnabled: row.notificationsEnabled,
      );
    }
    const settings = AutomationSettings();
    await save(settings);
    return settings;
  }

  @override
  Future<void> save(AutomationSettings settings) async {
    await database
        .into(database.appSettingsRows)
        .insertOnConflictUpdate(
          db.AppSettingsRowsCompanion.insert(
            id: const Value(1),
            autoCalculate: Value(settings.autoCalculate),
            notificationsEnabled: Value(settings.notificationsEnabled),
          ),
        );
  }
}

class DriftProfitRepository implements ProfitRepository {
  DriftProfitRepository(this.database);

  final db.AppDatabase database;

  @override
  Future<List<StoredProfitRecord>> getForEmployment(
    String employmentId,
  ) async {
    final query = database.select(database.profitRecords)
      ..where((row) => row.employmentId.equals(employmentId))
      ..orderBy([(row) => OrderingTerm.asc(row.creditedDate)]);
    return (await query.get()).map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> save(StoredProfitRecord record) async {
    final periodStart = record.periodStart;
    final periodEnd = record.periodEnd;
    if (periodStart != null &&
        periodEnd != null &&
        periodEnd.isBefore(periodStart)) {
      throw ArgumentError('Profit period end cannot precede its start.');
    }
    await database.into(database.profitRecords).insertOnConflictUpdate(
          db.ProfitRecordsCompanion.insert(
            id: record.id,
            employmentId: record.employmentId,
            periodStart: Value(
              periodStart == null ? null : _dateOnly(periodStart),
            ),
            periodEnd: Value(periodEnd == null ? null : _dateOnly(periodEnd)),
            creditedDate: _dateOnly(record.creditedDate),
            amountMinorUnits: record.amount.minorUnits,
            decimalPlaces: record.amount.decimalPlaces,
            currencyCode: record.amount.currencyCode,
            optionalRatePpm: Value(record.optionalRate?.partsPerMillion),
            calculationMethod: Value(record.calculationMethod),
            sourceReference: Value(record.sourceReference),
            notes: Value(record.notes),
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.profitRecords,
    )..where((row) => row.id.equals(id))).go();
  }

  static StoredProfitRecord _fromRow(db.ProfitRecord row) {
    return StoredProfitRecord(
      id: row.id,
      employmentId: row.employmentId,
      periodStart: row.periodStart,
      periodEnd: row.periodEnd,
      creditedDate: row.creditedDate,
      amount: _money(
        row.amountMinorUnits,
        row.decimalPlaces,
        row.currencyCode,
      ),
      optionalRate: row.optionalRatePpm == null
          ? null
          : Rate.fromPartsPerMillion(row.optionalRatePpm!),
      calculationMethod: row.calculationMethod,
      sourceReference: row.sourceReference,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

class DriftInitialSetupRepository implements InitialSetupRepository {
  DriftInitialSetupRepository(this.database);

  static const profileId = 'primary-profile';
  static const organizationId = 'primary-organization';
  static const employmentId = 'primary-employment';

  final db.AppDatabase database;

  @override
  Future<bool> hasCompletedSetup() async {
    final employment = await (database.select(
      database.employments,
    )..where((row) => row.id.equals(employmentId))).getSingleOrNull();
    return employment != null;
  }

  @override
  Future<InitialPFSetup?> load() async {
    final profile = await (database.select(
      database.userProfiles,
    )..where((row) => row.id.equals(profileId))).getSingleOrNull();
    final organization = await (database.select(
      database.organizations,
    )..where((row) => row.id.equals(organizationId))).getSingleOrNull();
    final employment = await (database.select(
      database.employments,
    )..where((row) => row.id.equals(employmentId))).getSingleOrNull();
    final salary =
        await (database.select(database.salaryHistoryRows)
              ..where((row) => row.employmentId.equals(employmentId))
              ..orderBy([(row) => OrderingTerm.asc(row.effectiveFrom)])
              ..limit(1))
            .getSingleOrNull();
    final rule =
        await (database.select(database.pfRuleVersions)
              ..where((row) => row.organizationId.equals(organizationId))
              ..orderBy([(row) => OrderingTerm.asc(row.effectiveFrom)])
              ..limit(1))
            .getSingleOrNull();
    final schedule =
        await (database.select(database.salarySchedules)
              ..where((row) => row.organizationId.equals(organizationId))
              ..orderBy([(row) => OrderingTerm.asc(row.effectiveFrom)])
              ..limit(1))
            .getSingleOrNull();
    if (profile == null ||
        organization == null ||
        employment == null ||
        salary == null ||
        rule == null ||
        schedule == null) {
      return null;
    }
    return InitialPFSetup(
      employeeName: profile.employeeName,
      employeeCode: profile.employeeCode,
      organizationName: organization.name,
      joiningDate: employment.joiningDate,
      permanentDate: employment.permanentDate,
      pfStartDate: employment.pfStartDate,
      salary: DriftSalaryRepository._salaryFromRow(salary),
      rule: DriftPFRuleRepository._ruleFromRow(rule),
      salarySchedule: EffectiveSalarySchedule(
        id: schedule.id,
        effectiveFrom: schedule.effectiveFrom,
        schedule: SalarySchedule(
          paymentMonthOffset: schedule.paymentMonthOffset,
          paymentWindowStartDay: schedule.paymentWindowStartDay,
          paymentWindowEndDay: schedule.paymentWindowEndDay,
        ),
      ),
    );
  }

  @override
  Future<void> save(InitialPFSetup setup) async {
    final now = setup.salary.updatedAt;
    await database.transaction(() async {
      await database
          .into(database.userProfiles)
          .insertOnConflictUpdate(
            db.UserProfilesCompanion.insert(
              id: profileId,
              employeeName: setup.employeeName.trim(),
              employeeCode: Value(_trimmedOrNull(setup.employeeCode)),
              preferredCurrency: setup.salary.grossSalary.currencyCode,
              createdAt: setup.salary.createdAt,
              updatedAt: now,
            ),
          );
      await database
          .into(database.organizations)
          .insertOnConflictUpdate(
            db.OrganizationsCompanion.insert(
              id: organizationId,
              name: setup.organizationName.trim(),
              currencyCode: setup.salary.grossSalary.currencyCode,
              createdAt: setup.rule.createdAt,
              updatedAt: now,
            ),
          );
      await database
          .into(database.employments)
          .insertOnConflictUpdate(
            db.EmploymentsCompanion.insert(
              id: employmentId,
              profileId: profileId,
              organizationId: organizationId,
              joiningDate: _dateOnly(setup.joiningDate),
              permanentDate: Value(
                setup.permanentDate == null
                    ? null
                    : _dateOnly(setup.permanentDate!),
              ),
              pfStartDate: _dateOnly(setup.pfStartDate),
              createdAt: setup.salary.createdAt,
              updatedAt: now,
            ),
          );
      await DriftSalaryRepository(database).save(setup.salary);
      await DriftPFRuleRepository(database).save(setup.rule);
      final schedule = setup.salarySchedule;
      await database
          .into(database.salarySchedules)
          .insertOnConflictUpdate(
            db.SalarySchedulesCompanion.insert(
              id: schedule.id,
              organizationId: organizationId,
              effectiveFrom: _dateOnly(schedule.effectiveFrom),
              paymentMonthOffset: schedule.schedule.paymentMonthOffset,
              paymentWindowStartDay: schedule.schedule.paymentWindowStartDay,
              paymentWindowEndDay: schedule.schedule.paymentWindowEndDay,
              createdAt: setup.salary.createdAt,
              updatedAt: now,
            ),
          );
    });
  }
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

StoredMonthlyPFRecord _copyRecord(
  StoredMonthlyPFRecord record, {
  required DateTime createdAt,
}) {
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
    status: record.status,
    createdAt: createdAt,
    updatedAt: record.updatedAt,
    salaryHistoryId: record.salaryHistoryId,
    ruleVersionId: record.ruleVersionId,
    salaryCreditedDate: record.salaryCreditedDate,
    scheduledGenerationDate: record.scheduledGenerationDate,
    actualGenerationDate: record.actualGenerationDate,
    originalGrossSalary: record.originalGrossSalary,
    originalBasicSalary: record.originalBasicSalary,
    originalEmployeeContribution: record.originalEmployeeContribution,
    originalEmployerContribution: record.originalEmployerContribution,
    manuallyAdjustedAt: record.manuallyAdjustedAt,
    confirmedAt: record.confirmedAt,
    notes: record.notes,
  );
}

Money _money(int units, int decimalPlaces, String currencyCode) {
  return Money.fromMinorUnits(
    units,
    decimalPlaces: decimalPlaces,
    currencyCode: currencyCode,
  );
}

Money? _nullableMoney(int? units, int decimalPlaces, String currencyCode) {
  return units == null ? null : _money(units, decimalPlaces, currencyCode);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
