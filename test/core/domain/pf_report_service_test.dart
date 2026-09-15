import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_report_service.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

void main() {
  test('statement report assigns June work month to prior statement year', () {
    final reports = const PFReportService().statementSummaries(
      records: <StoredMonthlyPFRecord>[
        _record(const YearMonth(2026, 6), employee: 1000, employer: 1000),
        _record(const YearMonth(2026, 7), employee: 1100, employer: 1100),
      ],
      profits: <StoredProfitRecord>[_profit(DateTime(2026, 6, 30), 500)],
      configuration: const StatementYearConfiguration(
        startMonth: DateTime.july,
        startDay: 1,
      ),
    );

    expect(reports, hasLength(2));
    expect(
      reports.first.year,
      const PFStatementYear(startYear: 2026, endYear: 2027),
    );
    expect(reports.first.snapshot.openingBalance, Money.parse('2500'));
    expect(reports.first.snapshot.profit, isNull);
    expect(reports.first.snapshot.closingBalance, Money.parse('4700'));
    expect(
      reports.last.year,
      const PFStatementYear(startYear: 2025, endYear: 2026),
    );
    expect(reports.last.snapshot.closingBalance, Money.parse('2500'));
    expect(reports.last.snapshot.profit, Money.parse('500'));
  });

  test('explicit zero profit remains distinct from missing profit', () {
    final records = <StoredMonthlyPFRecord>[
      _record(const YearMonth(2026, 7), employee: 1000, employer: 1000),
    ];
    const configuration = StatementYearConfiguration(
      startMonth: DateTime.july,
      startDay: 1,
    );

    final missing = const PFReportService().statementSummaries(
      records: records,
      profits: const <StoredProfitRecord>[],
      configuration: configuration,
    );
    final explicitZero = const PFReportService().statementSummaries(
      records: records,
      profits: <StoredProfitRecord>[_profit(DateTime(2026, 12, 31), 0)],
      configuration: configuration,
    );

    expect(missing.single.snapshot.profit, isNull);
    expect(explicitZero.single.snapshot.profit, Money.zero());
    expect(missing.single.snapshot.closingBalance, Money.parse('2000'));
    expect(explicitZero.single.snapshot.closingBalance, Money.parse('2000'));
  });
}

StoredMonthlyPFRecord _record(
  YearMonth month, {
  required int employee,
  required int employer,
}) {
  final now = DateTime(2026);
  return StoredMonthlyPFRecord(
    id: 'record-$month',
    employmentId: 'employment-1',
    month: month,
    grossSalary: Money.parse('10000'),
    basicSalary: Money.parse('6000'),
    employeeContribution: Money.fromMinorUnits(employee),
    employerContribution: Money.fromMinorUnits(employer),
    adjustment: Money.zero(),
    basicRate: Rate.fromPercent('60'),
    employeeRate: Rate.fromPercent('10'),
    employerRate: Rate.fromPercent('10'),
    source: 'test',
    status: 'confirmed',
    createdAt: now,
    updatedAt: now,
  );
}

StoredProfitRecord _profit(DateTime date, int amount) {
  return StoredProfitRecord(
    id: 'profit-${date.toIso8601String()}',
    employmentId: 'employment-1',
    creditedDate: date,
    amount: Money.fromMinorUnits(amount),
    createdAt: date,
    updatedAt: date,
  );
}
