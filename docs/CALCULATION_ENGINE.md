# PF calculation engine

The Phase 3 engine is platform-independent Dart under `lib/src/core/domain`. It imports neither Flutter widgets nor Drift and is deterministic for identical inputs.

## Numeric model

- `Money` stores signed integer minor units, configured decimal places, and an ISO-style currency code.
- `Rate` stores parts per million and parses percentages without binary floating-point arithmetic.
- Multiplication uses integer arithmetic and half-up rounding.
- Money with different currencies or decimal precision cannot be combined.

## Approved defaults

- Partial eligible months receive a full contribution.
- Salary and PF rule versions are selected at PF-month end.
- Currency decimal places are configurable; BDT defaults to zero.
- Zero-decimal calculations use half-up rounding.
- Invalid salary payment days clamp to the calendar month's last day.
- Maturity duration and basis are configurable.
- Exit estimates include known profit and adjustments dated on/before exit.
- Exit exactly on the maturity date is mature.
- Missing values remain missing; explicit zero remains a known zero.

## Boundaries

- Presentation collects inputs, invokes application use cases, and displays domain results.
- Repositories persist domain inputs and calculation snapshots.
- The engine never reads the device clock, database, network, or UI state.
- Automation decides *when* to invoke the engine; the engine decides *what* a period calculates to.
- Company statements remain separate snapshots. Reconciliation returns differences without mutation.

## Tests

`test/core/domain/pf_calculation_engine_test.dart` covers money precision, rounding, contribution rates, eligibility, effective dating, salary/rule changes, historical reconstruction, missing salary, salary schedule clamping, maturity boundaries, leap dates, statement years, cutoff balances, employer forfeiture/entitlement, unknown profit, adjustments, and calculated-versus-actual reconciliation.
