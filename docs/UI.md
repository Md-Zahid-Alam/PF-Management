# Phase 6 UI implementation

Phase 6 is delivered in CI-verified slices. Widgets depend on domain contracts and providers; financial calculations remain in the calculation engine and persistence remains in Drift repositories.

## Implemented slices

- Responsive phone bottom navigation and large-screen navigation rail
- Dashboard empty state with clearly separated employee and company values
- PF calculator with whole-BDT half-up results and input validation
- Guided initial setup for profile and employment dates
- Organization PF rates, maturity period/basis, and employer entitlement policy
- Initial salary and following-month salary payment window
- Atomic persistence of the full initial setup
- Restart detection that bypasses onboarding after a complete setup exists
- Reopening the setup editor from Profile, Organization & PF Rules, or Salary Schedule in Settings
- Effective-dated salary history with add, edit, and protected deletion
- Monthly PF record search plus year and status filtering
- Manual month calculation through the deterministic calculation engine
- Duplicate-safe monthly creation and confirmed record deletion
- Live dashboard totals, current receivable estimate, maturity date, and Auto Calculate status
- Complete monthly record detail view with scheduled and actual dates
- Audited manual adjustment that retains the original calculated snapshot
- Reviewed/confirmed monthly record status

## Validation and safety

The setup flow prevents missing required names and salary, invalid percentages, invalid schedule days, a PF/permanent date before joining, a reversed payment window, and permanent-date maturity without a permanent date. A failed database transaction leaves no partial setup.

Remaining Phase 6 screens will reuse the same navigation, theme, repository boundaries, validation patterns, and confirmation rules.
