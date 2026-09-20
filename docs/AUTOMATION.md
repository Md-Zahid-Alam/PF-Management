# Local PF automation

Phase 5 implements offline, app-triggered PF automation. It performs no server work and does not require an internet connection.

## Due-period workflow

1. Start at the employment's actual PF start month.
2. Select the effective salary schedule for each PF month using the calendar month's last day.
3. Calculate the scheduled generation date from the end of that schedule's payment window. Invalid dates clamp to the last calendar day.
4. On or after that date, inspect every missed month through the current month.
5. Leave an existing month unchanged, preventing duplicates.
6. Include an eligible partial PF-start month with the approved full contribution.
7. Select salary and PF-rule history on the PF month's final calendar day.
8. If salary or rule information is unavailable, return a pending status and never create a zero-valued record.
9. If **Auto Calculate PF** is off, return `readyForManualCalculation` without creating a record.
10. If it is on, calculate with the deterministic domain engine and store both scheduled and actual generation dates.

The Auto Calculate and notification switches are stored in SQLite and remain unchanged until the user changes them.

## Historical generation and recalculation

Historical preview begins at the configured PF start date. It reports employee and employer contributions separately and marks profit as unknown; it never invents profit.

Historical generation uses the salary, PF rule, and salary schedule effective for every individual month. Schedule versions may begin in any month, so permanent changes and one-month exceptions are supported; a one-month exception is followed by another version restoring the normal schedule. Recalculation preview enumerates each affected month and the salary/rule versions used. Recalculation replaces ordinary calculated records. A `manuallyAdjusted` month is preserved unless the user explicitly selects that exact month for replacement. Actual statement records are stored separately and are not modified by recalculation.

## Notifications

The Android adapter uses local device notifications for due calculations, automatic completion, and missing salary information. Notifications are configurable and permission is requested through an explicit application action. The domain layer depends only on a platform-neutral gateway, leaving future desktop and iOS adapters independent from PF business rules.

## Application integration

The application initializes the notification gateway and invokes `PFAutomationService.processDuePeriods` after the active employment, effective schedules, salary history, and PF rules are loaded. It repeats this check when the app resumes so missed periods are caught after a device restart or time away. Android does not perform hidden server-side or continuous background processing.
