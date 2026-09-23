import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/database/app_database.dart' as db;
import 'package:pf_tracker/src/core/database/database_backup_service.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';
import 'package:pf_tracker/src/core/security/security_repository.dart';

void main() {
  test(
    'backup and restore exclude and preserve authentication secrets',
    () async {
      final database = db.AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final secureStore = _MemorySecureStore();
      final securityRepository = SecurityRepository(secureStore);
      final pinService = PinSecurityService(
        iterations: 10,
        secureRandom: Random(42),
      );
      final originalCredential = pinService.createCredential('2580');
      await securityRepository.saveCredential(originalCredential);
      await securityRepository.savePreferences(
        const SecurityPreferences(
          biometricEnabled: true,
          autoLockDuration: AutoLockDuration.fiveMinutes,
        ),
      );
      final now = DateTime.utc(2026, 9, 23);
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

      final backupService = DatabaseBackupService(database);
      final backup = await backupService.exportAll(
        appVersion: '0.1.0',
        exportedAt: now,
      );
      final serializedBackup = jsonEncode(backup);

      expect(serializedBackup, isNot(contains(originalCredential.encode())));
      expect(serializedBackup, isNot(contains('pf_ledger.pin_credential')));
      expect(serializedBackup, isNot(contains('biometricEnabled')));
      expect(serializedBackup, isNot(contains('2580')));

      final replacementCredential = PinSecurityService(
        iterations: 10,
        secureRandom: Random(84),
      ).createCredential('3690');
      await securityRepository.saveCredential(replacementCredential);
      await backupService.restoreAll(backup);

      final preservedCredential = await securityRepository.readCredential();
      expect(preservedCredential?.encode(), replacementCredential.encode());
      expect(pinService.verify('3690', preservedCredential!), isTrue);
      expect(
        (await securityRepository.readPreferences()).biometricEnabled,
        isTrue,
      );
      expect(await database.select(database.userProfiles).get(), hasLength(1));
    },
  );
}

class _MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
