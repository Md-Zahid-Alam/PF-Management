import 'dart:convert';

import 'package:crypto/crypto.dart';
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

  static const int currentFormatVersion = 4;
  static const int oldestSupportedFormatVersion = 1;

  final db.AppDatabase database;

  Future<Map<String, Object?>> exportAll({
    required String appVersion,
    required DateTime exportedAt,
  }) async {
    final backup = <String, Object?>{
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
    return _withChecksum(backup);
  }

  Future<void> restoreAll(Map<String, Object?> backup) async {
    final migrated = _migrateToCurrentFormat(backup);
    _verifyChecksum(migrated);
    final data = _validatedData(migrated);
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

  Future<void> deleteAll() async {
    await database.transaction(_deleteAllInDependencyOrder);
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

  Map<String, Object?> _migrateToCurrentFormat(Map<String, Object?> backup) {
    final version = backup['formatVersion'];
    if (version is! int ||
        version < oldestSupportedFormatVersion ||
        version > currentFormatVersion) {
      throw const InvalidBackup('Unsupported backup format version.');
    }
    var migrated = Map<String, Object?>.from(backup);
    var migratedVersion = version;
    while (migratedVersion < currentFormatVersion) {
      migrated = switch (migratedVersion) {
        1 => _migrateVersion1To2(migrated),
        2 => _migrateVersion2To3(migrated),
        3 => _migrateVersion3To4(migrated),
        _ => throw const InvalidBackup('Unsupported backup migration path.'),
      };
      migratedVersion++;
    }
    return migrated;
  }

  Map<String, Object?> _migrateVersion1To2(Map<String, Object?> backup) {
    return <String, Object?>{...backup, 'formatVersion': 2};
  }

  Map<String, Object?> _migrateVersion2To3(Map<String, Object?> backup) {
    final migrated = Map<String, Object?>.from(backup);
    final sourceData = backup['data'];
    if (sourceData is! Map<Object?, Object?>) {
      throw const InvalidBackup('Backup data is missing or malformed.');
    }
    final data = Map<String, Object?>.from(sourceData);
    final sourceSchedules = data['salarySchedules'];
    if (sourceSchedules is! List<Object?>) {
      throw const InvalidBackup('Salary schedules are missing or malformed.');
    }
    data['salarySchedules'] = <Object?>[
      for (final sourceRow in sourceSchedules)
        if (sourceRow is Map<Object?, Object?>)
          <String, Object?>{
            ...Map<String, Object?>.from(sourceRow),
            'paymentWindowStartMonthOffset':
                sourceRow['paymentWindowStartMonthOffset'] ??
                sourceRow['paymentMonthOffset'],
          }
        else
          throw const InvalidBackup('Salary schedule row is malformed.'),
    ];
    migrated['formatVersion'] = 3;
    migrated['data'] = data;
    return migrated;
  }

  Map<String, Object?> _migrateVersion3To4(Map<String, Object?> backup) {
    return _withChecksum(<String, Object?>{...backup, 'formatVersion': 4});
  }

  void _verifyChecksum(Map<String, Object?> backup) {
    if (backup['checksumAlgorithm'] != 'sha256') {
      throw const InvalidBackup('Backup checksum algorithm is unsupported.');
    }
    final supplied = backup['checksum'];
    if (supplied is! String || supplied.isEmpty) {
      throw const InvalidBackup('Backup checksum is missing.');
    }
    final payload = Map<String, Object?>.from(backup)..remove('checksum');
    final expected = _checksumFor(payload);
    if (supplied != expected) {
      throw const InvalidBackup('Backup checksum does not match its data.');
    }
  }

  static Map<String, Object?> _withChecksum(Map<String, Object?> backup) {
    final payload = <String, Object?>{...backup, 'checksumAlgorithm': 'sha256'}
      ..remove('checksum');
    return <String, Object?>{...payload, 'checksum': _checksumFor(payload)};
  }

  static String _checksumFor(Map<String, Object?> payload) {
    return sha256.convert(utf8.encode(_canonicalJson(payload))).toString();
  }

  static String _canonicalJson(Object? value) {
    return jsonEncode(_canonicalize(value));
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map<Object?, Object?>) {
      final mapped = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw const InvalidBackup('Backup object key is malformed.');
        }
        mapped[key] = entry.value;
      }
      final keys = mapped.keys.toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalize(mapped[key]),
      };
    }
    if (value is List<Object?>) {
      return <Object?>[for (final item in value) _canonicalize(item)];
    }
    return value;
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
