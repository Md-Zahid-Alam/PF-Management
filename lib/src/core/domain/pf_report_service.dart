import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';

class PFStatementSummary {
  const PFStatementSummary({
    required this.year,
    required this.periodStart,
    required this.periodEnd,
    required this.snapshot,
    required this.monthCount,
  });

  final PFStatementYear year;
  final DateTime periodStart;
  final DateTime periodEnd;
  final StatementSnapshot snapshot;
  final int monthCount;
}

class PFReportService {
  const PFReportService({this.engine = const PFCalculationEngine()});

  final PFCalculationEngine engine;

  List<PFStatementSummary> statementSummaries({
    required List<StoredMonthlyPFRecord> records,
    required List<StoredProfitRecord> profits,
    required StatementYearConfiguration configuration,
  }) {
    if (records.isEmpty) return const <PFStatementSummary>[];
    final years =
        <PFStatementYear>{
            for (final record in records)
              engine.statementYearFor(record.month, configuration),
          }.toList()
          ..sort((left, right) => right.startYear.compareTo(left.startYear));
    return <PFStatementSummary>[
      for (final year in years)
        _summaryFor(year, records, profits, configuration),
    ];
  }

  PFStatementSummary _summaryFor(
    PFStatementYear year,
    List<StoredMonthlyPFRecord> records,
    List<StoredProfitRecord> profits,
    StatementYearConfiguration configuration,
  ) {
    final start = DateTime(
      year.startYear,
      configuration.startMonth,
      configuration.startDay,
    );
    final end = DateTime(
      year.endYear,
      configuration.startMonth,
      configuration.startDay,
    ).subtract(const Duration(days: 1));
    final prototype = records.first.grossSalary;
    Money zero() => Money.zero(
      decimalPlaces: prototype.decimalPlaces,
      currencyCode: prototype.currencyCode,
    );
    var opening = zero();
    var employee = zero();
    var employer = zero();
    var adjustments = zero();
    var profit = zero();
    var profitRecorded = false;
    var monthCount = 0;
    for (final record in records) {
      final date = record.month.firstDay;
      final contribution =
          record.employeeContribution + record.employerContribution;
      if (date.isBefore(start)) {
        opening += contribution + record.adjustment;
      } else if (!date.isAfter(end)) {
        employee += record.employeeContribution;
        employer += record.employerContribution;
        adjustments += record.adjustment;
        monthCount++;
      }
    }
    for (final item in profits) {
      if (item.creditedDate.isBefore(start)) {
        opening += item.amount;
      } else if (!item.creditedDate.isAfter(end)) {
        profit += item.amount;
        profitRecorded = true;
      }
    }
    return PFStatementSummary(
      year: year,
      periodStart: start,
      periodEnd: end,
      monthCount: monthCount,
      snapshot: StatementSnapshot(
        openingBalance: opening,
        employeeContribution: employee,
        employerContribution: employer,
        profit: profitRecorded ? profit : null,
        adjustments: adjustments,
        closingBalance: opening + employee + employer + profit + adjustments,
      ),
    );
  }
}
