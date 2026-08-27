import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class AppSettingsRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get autoCalculate => boolean().withDefault(const Constant(true))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  IntColumn get decimalPlaces => integer().withDefault(const Constant(0))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(tables: <Type>[AppSettingsRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pf_tracker');
  }
}
