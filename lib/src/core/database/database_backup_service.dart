import 'package:drift/drift.dart';
import 'package:pf_tracker/src/core/database/app_database.dart' as db;

class InvalidBackup implements Exception {
  const InvalidBackup(this.message);

  final String message;

  @override
  String toString() => 'InvalidBackup: $message';
}

class DatabaseBackupService {
  DatabaseBackupService(this.database);

  static const int currentFormatVersion = 1;

  final db.AppDatabase database;

  Future<Map<String, Object?>> exportAll({
    required String appVersion,
    required DateTime exportedAt,
  }) async {
    return <String, Object?>{
      'formatVersion': currentFormatVersion,
      'appVersion': appVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'data': <String, Object?>{
        'userProfiles': await _jsonRows(database.select(database.userProfiles)),
        'organizations': await _jsonRows(
          database.select(database.organizations),
        ),
        'employments': await _jsonRows(database.select(database.employments)),
        'pfRuleVersions': await _jsonRows(
          database.select(database.pfRuleVersions),
        ),
        'salarySchedules': await _jsonRows(
          database.select(database.salarySchedules),
        ),
        'salaryHistory': await _jsonRows(
          database.select(database.salaryHistoryRows),
        ),
        'monthlyPfRecords': await _jsonRows(
          database.select(database.monthlyPfRecords),
        ),
        'profitRecords': await _jsonRows(
          database.select(database.profitRecords),
        ),
        'statementYearDefinitions': await _jsonRows(
          database.select(database.statementYearDefinitions),
        ),
        'actualPfStatements': await _jsonRows(
          database.select(database.actualPfStatements),
        ),
        'appSettings': await _jsonRows(
          database.select(database.appSettingsRows),
        ),
        'backupMetadata': await _jsonRows(
          database.select(database.backupMetadataRows),
        ),
      },
    };
  }

  Future<void> restoreAll(Map<String, Object?> backup) async {
    final data = _validatedData(backup);
    await database.transaction(() async {
      await _deleteAllInDependencyOrder();
      await database.batch((batch) {
        batch.insertAll(
          database.userProfiles,
          _rows(data, 'userProfiles').map(db.UserProfile.fromJson),
        );
        batch.insertAll(
          database.organizations,
          _rows(data, 'organizations').map(db.Organization.fromJson),
        );
        batch.insertAll(
          database.employments,
          _rows(data, 'employments').map(db.Employment.fromJson),
        );
        batch.insertAll(
          database.pfRuleVersions,
          _rows(data, 'pfRuleVersions').map(db.PfRuleVersion.fromJson),
        );
        batch.insertAll(
          database.salarySchedules,
          _rows(data, 'salarySchedules').map(db.SalarySchedule.fromJson),
        );
        batch.insertAll(
          database.salaryHistoryRows,
          _rows(data, 'salaryHistory').map(db.SalaryHistoryRow.fromJson),
        );
        batch.insertAll(
          database.monthlyPfRecords,
          _rows(data, 'monthlyPfRecords').map(db.MonthlyPfRecord.fromJson),
        );
        batch.insertAll(
          database.profitRecords,
          _rows(data, 'profitRecords').map(db.ProfitRecord.fromJson),
        );
        batch.insertAll(
          database.statementYearDefinitions,
          _rows(
            data,
            'statementYearDefinitions',
          ).map(db.StatementYearDefinition.fromJson),
        );
        batch.insertAll(
          database.actualPfStatements,
          _rows(data, 'actualPfStatements').map(db.ActualPfStatement.fromJson),
        );
        batch.insertAll(
          database.appSettingsRows,
          _rows(data, 'appSettings').map(db.AppSettingsRow.fromJson),
        );
        batch.insertAll(
          database.backupMetadataRows,
          _rows(data, 'backupMetadata').map(db.BackupMetadataRow.fromJson),
        );
      });
    });
  }

  Map<String, Object?> _validatedData(Map<String, Object?> backup) {
    if (backup['formatVersion'] != currentFormatVersion) {
      throw const InvalidBackup('Unsupported backup format version.');
    }
    final data = backup['data'];
    if (data is! Map<String, Object?>) {
      throw const InvalidBackup('Backup data is missing or malformed.');
    }
    for (final key in <String>[
      'userProfiles',
      'organizations',
      'employments',
      'pfRuleVersions',
      'salarySchedules',
      'salaryHistory',
      'monthlyPfRecords',
      'profitRecords',
      'statementYearDefinitions',
      'actualPfStatements',
      'appSettings',
      'backupMetadata',
    ]) {
      if (data[key] is! List<Object?>) {
        throw InvalidBackup('Backup table "$key" is missing or malformed.');
      }
    }
    return data;
  }

  Future<void> _deleteAllInDependencyOrder() async {
    await database.delete(database.monthlyPfRecords).go();
    await database.delete(database.profitRecords).go();
    await database.delete(database.actualPfStatements).go();
    await database.delete(database.salaryHistoryRows).go();
    await database.delete(database.pfRuleVersions).go();
    await database.delete(database.salarySchedules).go();
    await database.delete(database.statementYearDefinitions).go();
    await database.delete(database.employments).go();
    await database.delete(database.organizations).go();
    await database.delete(database.userProfiles).go();
    await database.delete(database.appSettingsRows).go();
    await database.delete(database.backupMetadataRows).go();
  }

  static List<Map<String, Object?>> _rows(
    Map<String, Object?> data,
    String key,
  ) {
    return (data[key]! as List<Object?>)
        .map((row) => Map<String, Object?>.from(row! as Map<Object?, Object?>))
        .toList(growable: false);
  }

  static Future<List<Map<String, Object?>>> _jsonRows<T extends DataClass>(
    Selectable<T> query,
  ) async {
    return (await query.get())
        .map((row) => row.toJson())
        .toList(growable: false);
  }
}

