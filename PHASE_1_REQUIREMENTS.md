# Offline PF Tracker — Phase 1 Requirements Baseline

Status: **Approved on 2026-08-28. Phase 2 authorized.**

## 1. Product scope

An Android-first, fully offline personal Provident Fund tracker that reconstructs historical PF records, maintains future monthly records, supports effective-dated salaries and PF policies, compares calculated values with official statements, estimates maturity/exit entitlement, and safely backs up/restores local data.

### Included in version 1

- First-time setup for profile, employment, organization, PF start, salary, rules, schedule, and historical reconstruction.
- Effective-dated salary history and PF rule history.
- Deterministic monthly PF calculation with configurable basic, employee, and employer rates.
- Historical preview, confirmed generation, explicit recalculation, and audit snapshots.
- Persistent Auto Calculate PF preference; local due-period checks and missed-period catch-up.
- Monthly record CRUD, statuses, overrides, adjustments, and duplicate protection.
- Manual profit records; missing profit remains unknown rather than zero.
- Configurable maturity and employer-contribution entitlement.
- Dashboard, calculator, maturity and exit estimates, reports, statement-year summaries, and calculated-versus-actual comparison.
- Versioned local backup/restore with validation and destructive-action confirmation.
- Light, dark, and system themes; accessible and responsive UI.

### Excluded from version 1

- Accounts, cloud sync/backup, server components, multi-device sync, desktop/iOS releases, multi-employer UI, withdrawals/loans, automatic profit formulas, PDF/CSV exports, and PIN/biometric lock.
- Local notifications remain a decision item because the source specification lists them both as optional now and as a future feature.

## 2. Principal user flows

1. **First run:** profile/employment → organization → initial PF rule → salary schedule → salary history → historical preview → confirm generation → choose Auto Calculate → dashboard.
2. **Historical reconstruction:** determine eligible PF months through the latest due period → resolve each month’s rule and salary → preview totals/issues → atomically create unique records.
3. **App startup automation:** inspect local date → find eligible due months without records → auto-generate when enabled and complete, otherwise expose pending action → never duplicate.
4. **Salary/rule change:** add a new effective-dated version → preserve prior records → apply only to later applicable months; explicit recalculation is required to change existing calculated records.
5. **Monthly maintenance:** browse/filter → inspect calculation snapshot → calculate early/late, confirm, edit, or delete with confirmation → preserve original calculated values after override.
6. **Profit:** add known manual profit for a defined period/date → show known totals separately from unknown profit.
7. **Official statement:** enter nullable statement fields → aggregate calculated values by PF month/statement year → compare only comparable known fields → preserve actual values as authoritative and separate.
8. **Exit estimate:** select exit date → evaluate maturity and employer entitlement → include contributions through the selected cutoff plus known applicable profit/adjustments → label unknowns and show an estimate disclaimer.
9. **Backup/restore:** export versioned backup through the platform picker → validate before import → preview/confirm replacement → restore atomically or leave current data untouched.

## 3. Screen structure

- Startup/splash and first-time setup wizard
- Dashboard
- PF calculator
- Monthly PF records; monthly record detail/add/edit
- Salary history; salary add/edit
- PF rule history; rule detail/add/new version
- Profit history; profit add/edit
- PF maturity
- Exit estimate
- Reports and statement-year detail/comparison
- Actual company statement add/edit
- Profile and employment
- Organization and PF rules
- Salary schedule
- Backup and restore
- Settings
- About

Primary navigation: Dashboard, Records, Reports, and More. Contextual actions open editors and settings without overcrowding primary navigation.

## 4. Proposed data model

All entities use stable IDs, created/updated timestamps, and schema-version-compatible serialization. Money is stored as integer minor units; rates are fixed-point integers.

- `UserProfile`: id, name, optional employee code, preferred currency.
- `Organization`: id, name, currency, active flag.
- `Employment`: id, profileId, organizationId, joiningDate, probationStartDate, probation duration, permanentDate, pfStartDate, optional exitDate, status.
- `PFRuleVersion`: id, organizationId, effectiveFrom, derived effectiveTo, basicRate, employeeRate, employerRate, maturityDuration, maturityBasis, maturityRuleSelection policy, pre/post-maturity employer entitlement, partial-month policy, notes.
- `SalarySchedule`: id, organizationId, effectiveFrom, paymentMonthOffset, window start/end day, invalid-day handling policy.
- `SalaryHistory`: id, employmentId, effectiveFrom, grossMoney, notes. PF rates normally come from `PFRuleVersion`, avoiding competing sources.
- `MonthlyPFRecord`: id, employmentId, pfMonth, creditedDate, gross/basic amounts, rates, employee/employer contributions, adjustment, known monthly profit if used, opening/closing calculated balances, schedule/actual generation dates, status, source, ruleVersionId, salaryHistoryId, original calculation snapshot, override fields, notes, confirmedAt.
- `ProfitRecord`: id, employmentId, periodStart/end, creditedDate, amount, optional rate/method/source, notes.
- `StatementYearDefinition`: id, organizationId, effectiveFrom, startMonth/startDay.
- `ActualPFStatement`: id, employmentId, statement-year key, statementDate and nullable opening/employee/employer/profit/adjustment/closing values, notes.
- `AppSettings`: theme, persistent autoCalculate, notification preferences if included, locale.
- `BackupMetadata`: formatVersion, appVersion, exportedAt, checksum.

Key constraints:

- Unique `(employmentId, pfMonth)` monthly record.
- Non-overlapping/ordered effective-dated versions, with deterministic latest-applicable selection.
- Nonnegative salary/rates/contributions unless an explicitly signed adjustment field permits negatives.
- Monthly records retain calculation snapshots and foreign-key references for auditability.
- Actual statements are never overwritten by recalculation.

## 5. Calculation rules

For each eligible PF month `M`:

1. Confirm `M` is at/after the PF-start boundary and not after an applicable exit boundary.
2. Select the latest PF rule whose effective date applies to `M`.
3. Select the latest salary record whose effective date applies to `M`.
4. `basic = round(gross × basicRate)`.
5. `employeePF = round(basic × employeeRate)`.
6. `employerPF = round(basic × employerRate)`.
7. `totalContribution = employeePF + employerPF`.
8. `closingCalculatedBalance = prior calculated balance + totalContribution + known allocated profit + signed adjustments`.

Missing salary or rule blocks calculation; it never becomes zero. Profit missing is represented as unknown, while an explicitly entered zero remains known zero.

Maturity date is the configured duration added to the configured basis date. Exit on or after that date is mature. Accrued PF and presently receivable/vested PF are shown separately so pre-maturity employer contributions are visible without being presented as receivable.

Statement-year assignment uses PF month, not credited date. For a July 1 start, June 2026 belongs to 2025–26 even if paid in July.

## 6. Automation workflow

- Scheduled generation date derives from the salary schedule’s last payment-window date, with an explicit policy for invalid calendar days.
- On startup/resume, enumerate eligible PF months through the latest schedule date that has passed.
- For each month, rely on the database uniqueness constraint and an atomic transaction.
- Auto Calculate ON + complete inputs: create `Automatically Calculated` record and store scheduled and actual generation dates.
- Auto Calculate ON + missing inputs: expose `Pending Salary Information`; no financial record with invented values is created.
- Auto Calculate OFF: expose a due action without creating a contribution record; user action creates `Manually Calculated`.
- Historical reconstruction is a separate explicit preview/confirm transaction and is unaffected by Auto Calculate.
- Recalculation previews impacted periods, replaces only calculated values after confirmation, preserves audit snapshots/manual-adjustment policy, and never changes actual statements.

## 7. Architecture proposal

Use **Flutter/Dart** for Android-first delivery with future Windows/iOS reuse, a feature-oriented clean architecture, and immutable domain values. Use **SQLite via Drift** for typed local persistence and migrations. Keep calculation/domain code free of Flutter and database dependencies.

Layers:

`Presentation` → `Application/use cases` → `Domain calculation engine` → `Repository interfaces` → `Drift/SQLite adapters`

- State management and dependency injection should be lightweight and selected during Phase 2 from current stable, well-supported packages.
- Navigation uses a typed/declarative router.
- Backup uses a versioned JSON archive with checksum and platform document picker; secrets are not required.
- Local time is used only to determine due dates; persisted PF months are year-month values and business dates are date-only values.
- Unit tests cover all financial/date policies; repository/database integration tests cover uniqueness, transactions, migrations, and restore; widget tests cover critical workflows.

## 8. Contradictions and resolutions

1. **Salary history contains PF/basic rates while effective-dated PF rules also own them.** Proposed resolution: salary history owns gross salary; PF rule versions own rates. A monthly record may still override actual values and stores the applied snapshot.
2. **Notifications are described as optional in version 1 and also listed as future-only.** User decision required.
3. **“Current calculated balance” includes employer contributions, although those may be forfeited before maturity.** Resolve in UI by showing total accrued balance and estimated currently receivable/vested amount separately.
4. **Pending is described as a record status while Auto Calculate OFF says not to create records.** Proposed resolution: derive due/pending items without inserting financial records; `Pending Salary Information` may be a non-financial workflow item until calculation succeeds.
5. **Rule versions include maturity policy, but the rule version governing an employee’s maturity is unspecified.** User decision required.
6. **Salary/rule changes and PF start can occur mid-month, but proration/selection is unspecified.** User decision required.

## 9. Approved policy decisions

1. Partial months use a full contribution by default; the policy remains configurable.
2. Mid-month salary/rule changes use the version effective at month end by default; the policy remains configurable.
3. Currency decimal places are configurable. At zero places, round to whole BDT using half-up rounding.
4. Maturity duration and maturity-basis date are configurable.
5. Invalid payment-window days clamp to the last calendar day.
6. Known profit and adjustments credited on/before an exit date are included in its estimate.
7. Configurable local notifications are included in version 1.
8. Historical recalculation preserves manually adjusted records unless the user explicitly selects them for replacement.

## 10. Phase 2 acceptance gate

After the eight decisions above are recorded, approval of this baseline authorizes Phase 2 project setup only. Framework/package versions will be pinned to then-current stable releases and verified against official documentation at that time.
