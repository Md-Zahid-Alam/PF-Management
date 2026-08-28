import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:pf_tracker/src/core/database/tables.dart';

part 'app_database.g.dart';

class AppSettingsRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get autoCalculate => boolean().withDefault(const Constant(true))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  IntColumn get decimalPlaces => integer().withDefault(const Constant(0))();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get locale => text().withDefault(const Constant('en'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(
  tables: <Type>[
    UserProfiles,
    Organizations,
    Employments,
    PfRuleVersions,
    SalarySchedules,
    SalaryHistoryRows,
    MonthlyPfRecords,
    ProfitRecords,
    StatementYearDefinitions,
    ActualPfStatements,
    AppSettingsRows,
    BackupMetadataRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(userProfiles);
        await migrator.createTable(organizations);
        await migrator.createTable(employments);
        await migrator.createTable(pfRuleVersions);
        await migrator.createTable(salarySchedules);
        await migrator.createTable(salaryHistoryRows);
        await migrator.createTable(monthlyPfRecords);
        await migrator.createTable(profitRecords);
        await migrator.createTable(statementYearDefinitions);
        await migrator.createTable(actualPfStatements);
        await migrator.createTable(backupMetadataRows);
        await migrator.addColumn(appSettingsRows, appSettingsRows.locale);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pf_tracker');
  }
}
