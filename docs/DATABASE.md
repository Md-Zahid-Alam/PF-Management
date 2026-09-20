# Database architecture

Phase 4 uses Drift over SQLite behind platform-neutral repository interfaces.

## Schema

- User profiles, organizations, and employments are separate for future multi-employment support.
- PF rules, salary schedules, salary history, and statement-year definitions are effective-dated.
- Monthly PF records retain rule/salary references, calculation snapshots, source/status, generation dates, and original values after manual adjustment.
- Profit records and actual company statements remain separate from calculated monthly records.
- Settings preserve Auto Calculate, theme, precision, notification, and locale preferences.
- Backup metadata versions exported data without storing credentials.

## Integrity

- Primary keys are stable text IDs.
- Foreign keys are enabled for every connection.
- `(employment, PF month)` is unique, preventing duplicate monthly contributions.
- Effective dates are unique within their organization/employment scope.
- Actual statements are unique per employment and statement year.
- A PF rule referenced by a monthly record cannot be deleted through its repository.
- Manual adjustment runs transactionally and preserves the first calculated values.
- All money values in a monthly record must share currency and decimal precision.

## Migrations

Schema version 3 is current. Version 1 upgrades retain settings, add locale, and create the normalized financial tables. Version 2 upgrades add and backfill the salary-payment-window start-month offset, preserving the former same-month window meaning. Automated tests open real on-disk v1 and v2 SQLite files and run the production migrations.

## Backup and restore

`DatabaseBackupService` exports every table in backup format version 4 with a timestamp, a canonical SHA-256 checksum, and its algorithm identifier. Restore verifies current-format checksums before mutation, migrates legacy backup formats 1–3, validates the complete table envelope, and then deletes/inserts in dependency order inside one transaction. Malformed values, checksum mismatches, constraint failures, or foreign-key failures leave current data unchanged. The UI uses the platform file picker, confirms destructive restore, and requires typing `DELETE` before erasing all local data.

## Boundary

Repository contracts and stored domain records live under `core/domain`. Drift implementations live under `core/database`. UI and calculation code do not import generated database rows.
