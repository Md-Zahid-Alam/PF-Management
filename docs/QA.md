# Phase 8 QA matrix

Automated CI is the authoritative Flutter environment for this repository. Every push regenerates Drift sources, verifies formatting, runs fatal static analysis, runs the full test suite with coverage, and builds a debug Android APK.

## Automated coverage

- Financial calculations: basic salary, independent employee/employer rates, totals, half-up rounding, decimal precision, and incompatible-money rejection
- Eligibility and dates: PF start, exit overlap, maturity boundary, leap day, month boundaries, and scheduled generation clamping
- Effective history: salary selection, salary changes, PF rule selection, and historical reconstruction
- Automation: enabled and disabled behavior, missed-period catch-up, duplicate prevention, missing salary, manual calculation, and protected manual overrides
- Persistence: initial setup transactions, persistent automation settings, effective histories, monthly records, actual statements, and statement-year definitions
- Data safety: protected historical PF rules, original-value audit snapshots, backup/restore round trips, invalid-backup rollback, and foreign keys
- Statements: work-month assignment, actual-versus-calculated differences, missing profit, and explicit zero profit
- UI: onboarding smoke flow, calculator examples and validation, form validation, and responsive navigation breakpoint
- Integration and scale: complete reporting-data backup restoration, foreign-key rollback during restore, empty-statement rejection, and forty years of monthly report aggregation
- Backup UI: native platform save/open picker, destructive-restore confirmation, user-visible failures, and provider refresh after restoration
- Destructive safety: typed `DELETE` confirmation and atomic dependency-ordered deletion of all local data

## Device checks still required

- Install the generated APK on a physical Android device
- Verify notification permission and delivery on the target Android version
- Exercise phone and tablet layouts with large text and dark mode
- Confirm date pickers, keyboard behavior, scrolling, and system back navigation
- Create a realistic data set and visually reconcile it against an official PF statement

Release signing and release-artifact verification belong to Phase 9.
