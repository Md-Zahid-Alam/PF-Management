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

Schema version 2 expands the Phase 2 settings-only database. Fresh databases create the full schema atomically; upgrades retain settings, add locale, and create the normalized financial tables.

## Backup and restore

`DatabaseBackupService` exports every table with a format version and timestamp. Restore validates the complete table envelope before mutation, deletes/inserts in dependency order inside one transaction, and rolls back on malformed values, constraint failures, or foreign-key failures. Platform file selection and user confirmation belong to the later UI phase.

## Boundary

Repository contracts and stored domain records live under `core/domain`. Drift implementations live under `core/database`. UI and calculation code do not import generated database rows.
