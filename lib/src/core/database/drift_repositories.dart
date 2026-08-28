import 'package:drift/drift.dart';
import 'package:pf_tracker/src/core/database/app_database.dart' as db;
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/repositories.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

class DriftSalaryRepository implements SalaryRepository {
  DriftSalaryRepository(this.database);

  final db.AppDatabase database;

  @override
  Future<List<StoredSalary>> getForEmployment(String employmentId) async {
    final query = database.select(database.salaryHistoryRows)
      ..where((row) => row.employmentId.equals(employmentId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.effectiveFrom),
      ]);
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
      ..orderBy([
        (row) => OrderingTerm.desc(row.effectiveFrom),
      ])
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
      ..orderBy([
        (row) => OrderingTerm.asc(row.effectiveFrom),
      ]);
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
      ..orderBy([
        (row) => OrderingTerm.desc(row.effectiveFrom),
      ])
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
      ..orderBy([
        (row) => OrderingTerm.asc(row.pfMonth),
      ]);
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
      confirmedAt: row.confirmedAt,
      notes: row.notes,
    );
  }
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
