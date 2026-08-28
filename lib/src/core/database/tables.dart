import 'package:drift/drift.dart';

abstract class AuditedTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class UserProfiles extends AuditedTable {
  TextColumn get employeeName => text().withLength(min: 1, max: 200)();
  TextColumn get employeeCode => text().nullable()();
  TextColumn get preferredCurrency => text().withLength(min: 3, max: 3)();
}

class Organizations extends AuditedTable {
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Employments extends AuditedTable {
  TextColumn get profileId => text().references(UserProfiles, #id)();
  TextColumn get organizationId => text().references(Organizations, #id)();
  DateTimeColumn get joiningDate => dateTime()();
  DateTimeColumn get probationStartDate => dateTime().nullable()();
  IntColumn get probationMonths => integer().nullable()();
  DateTimeColumn get permanentDate => dateTime().nullable()();
  DateTimeColumn get pfStartDate => dateTime()();
  DateTimeColumn get exitDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}

class PfRuleVersions extends AuditedTable {
  TextColumn get organizationId => text().references(Organizations, #id)();
  DateTimeColumn get effectiveFrom => dateTime()();
  IntColumn get basicRatePpm => integer()();
  IntColumn get employeeRatePpm => integer()();
  IntColumn get employerRatePpm => integer()();
  IntColumn get maturityMonths => integer()();
  TextColumn get maturityBasis => text()();
  BoolColumn get employerEntitledBeforeMaturity =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get employerEntitledAfterMaturity =>
      boolean().withDefault(const Constant(true))();
  TextColumn get partialMonthPolicy =>
      text().withDefault(const Constant('fullContribution'))();
  TextColumn get effectiveVersionPolicy =>
      text().withDefault(const Constant('monthEnd'))();
  TextColumn get notes => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{organizationId, effectiveFrom},
  ];
}

class SalarySchedules extends AuditedTable {
  TextColumn get organizationId => text().references(Organizations, #id)();
  DateTimeColumn get effectiveFrom => dateTime()();
  IntColumn get paymentMonthOffset => integer()();
  IntColumn get paymentWindowStartDay => integer()();
  IntColumn get paymentWindowEndDay => integer()();
  TextColumn get invalidDayPolicy =>
      text().withDefault(const Constant('lastCalendarDay'))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{organizationId, effectiveFrom},
  ];
}

class SalaryHistoryRows extends AuditedTable {
  TextColumn get employmentId => text().references(Employments, #id)();
  DateTimeColumn get effectiveFrom => dateTime()();
  IntColumn get grossMinorUnits => integer()();
  IntColumn get decimalPlaces => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  TextColumn get notes => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{employmentId, effectiveFrom},
  ];
}

class MonthlyPfRecords extends AuditedTable {
  TextColumn get employmentId => text().references(Employments, #id)();
  DateTimeColumn get pfMonth => dateTime()();
  DateTimeColumn get salaryCreditedDate => dateTime().nullable()();
  TextColumn get salaryHistoryId =>
      text().nullable().references(SalaryHistoryRows, #id)();
  TextColumn get ruleVersionId =>
      text().nullable().references(PfRuleVersions, #id)();
  IntColumn get grossMinorUnits => integer()();
  IntColumn get basicMinorUnits => integer()();
  IntColumn get employeeMinorUnits => integer()();
  IntColumn get employerMinorUnits => integer()();
  IntColumn get adjustmentMinorUnits =>
      integer().withDefault(const Constant(0))();
  IntColumn get decimalPlaces => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  IntColumn get basicRatePpm => integer()();
  IntColumn get employeeRatePpm => integer()();
  IntColumn get employerRatePpm => integer()();
  DateTimeColumn get scheduledGenerationDate => dateTime().nullable()();
  DateTimeColumn get actualGenerationDate => dateTime().nullable()();
  TextColumn get source => text()();
  TextColumn get status => text()();
  IntColumn get originalGrossMinorUnits => integer().nullable()();
  IntColumn get originalBasicMinorUnits => integer().nullable()();
  IntColumn get originalEmployeeMinorUnits => integer().nullable()();
  IntColumn get originalEmployerMinorUnits => integer().nullable()();
  DateTimeColumn get manuallyAdjustedAt => dateTime().nullable()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{employmentId, pfMonth},
  ];
}

class ProfitRecords extends AuditedTable {
  TextColumn get employmentId => text().references(Employments, #id)();
  DateTimeColumn get periodStart => dateTime().nullable()();
  DateTimeColumn get periodEnd => dateTime().nullable()();
  DateTimeColumn get creditedDate => dateTime()();
  IntColumn get amountMinorUnits => integer()();
  IntColumn get decimalPlaces => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  IntColumn get optionalRatePpm => integer().nullable()();
  TextColumn get calculationMethod => text().nullable()();
  TextColumn get sourceReference => text().nullable()();
  TextColumn get notes => text().nullable()();
}

class StatementYearDefinitions extends AuditedTable {
  TextColumn get organizationId => text().references(Organizations, #id)();
  DateTimeColumn get effectiveFrom => dateTime()();
  IntColumn get startMonth => integer()();
  IntColumn get startDay => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{organizationId, effectiveFrom},
  ];
}

class ActualPfStatements extends AuditedTable {
  TextColumn get employmentId => text().references(Employments, #id)();
  IntColumn get statementStartYear => integer()();
  DateTimeColumn get statementDate => dateTime().nullable()();
  IntColumn get openingMinorUnits => integer().nullable()();
  IntColumn get employeeMinorUnits => integer().nullable()();
  IntColumn get employerMinorUnits => integer().nullable()();
  IntColumn get profitMinorUnits => integer().nullable()();
  IntColumn get adjustmentMinorUnits => integer().nullable()();
  IntColumn get closingMinorUnits => integer().nullable()();
  IntColumn get decimalPlaces => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  TextColumn get notes => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{employmentId, statementStartYear},
  ];
}

class BackupMetadataRows extends AuditedTable {
  IntColumn get formatVersion => integer()();
  TextColumn get appVersion => text()();
  DateTimeColumn get exportedAt => dateTime()();
  TextColumn get checksum => text()();
}

