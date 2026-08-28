import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/pf_calculation_engine.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/year_month.dart';

void main() {
  const engine = PFCalculationEngine();
  const followingMonthSchedule = SalarySchedule(
    paymentMonthOffset: 1,
    paymentWindowStartDay: 1,
    paymentWindowEndDay: 5,
  );
  final defaultRule = PFRuleVersion(
    id: 'PF-2026-01',
    effectiveFrom: DateTime(2026),
    basicSalaryRate: Rate.fromPercent('60'),
    employeePFRate: Rate.fromPercent('10'),
    employerPFRate: Rate.fromPercent('10'),
    maturityMonths: 24,
    maturityBasis: MaturityBasis.joiningDate,
  );
  final employment = EmploymentDates(
    joiningDate: DateTime(2026),
    pfStartDate: DateTime(2026, 4),
    permanentDate: DateTime(2026, 4),
  );

  group('money and rounding', () {
    test('calculates approved whole-BDT example with half-up rounding', () {
      final gross = Money.parse('30000');
      final basic = engine.calculateBasicSalary(gross, Rate.fromPercent('60'));
      final employee = engine.calculateEmployeeContribution(basic, Rate.fromPercent('10'));

      expect(basic, Money.parse('18000'));
      expect(employee, Money.parse('1800'));
    });

    test('supports configurable decimal places', () {
      final amount = Money.parse('10.05', decimalPlaces: 2);

      expect(amount.multiply(Rate.fromPercent('50')), Money.parse('5.03', decimalPlaces: 2));
    });

    test('rounds exact halves away from zero', () {
      expect(Money.parse('5').multiply(Rate.fromPercent('10')), Money.parse('1'));
      expect(Money.parse('-5').multiply(Rate.fromPercent('10')), Money.parse('-1'));
    });

    test('rejects incompatible currency precision', () {
      expect(
        () => Money.parse('1') + Money.parse('1.00', decimalPlaces: 2),
        throwsArgumentError,
      );
    });
  });

  group('eligibility and effective dating', () {
    test('full-contribution policy includes a mid-month PF start', () {
      final midMonth = EmploymentDates(
        joiningDate: DateTime(2026),
        pfStartDate: DateTime(2026, 4, 20),
      );

      expect(engine.isEligibleForMonth(midMonth, const YearMonth(2026, 4)), isTrue);
      expect(engine.isEligibleForMonth(midMonth, const YearMonth(2026, 3)), isFalse);
    });

    test('end-of-month policy selects a mid-month salary change', () {
      final salary = engine.selectEffectiveVersion(
        const YearMonth(2026, 7),
        <SalaryHistoryEntry>[
          SalaryHistoryEntry(effectiveFrom: DateTime(2026), grossSalary: Money.parse('30000')),
          SalaryHistoryEntry(
            effectiveFrom: DateTime(2026, 7, 15),
            grossSalary: Money.parse('35000'),
          ),
        ],
        (entry) => entry.effectiveFrom,
      );

      expect(salary!.grossSalary, Money.parse('35000'));
    });

    test('old months retain their historical rule version', () {
      final rules = <PFRuleVersion>[
        defaultRule,
        PFRuleVersion(
          id: 'PF-2026-07',
          effectiveFrom: DateTime(2026, 7),
          basicSalaryRate: Rate.fromPercent('60'),
          employeePFRate: Rate.fromPercent('12'),
          employerPFRate: Rate.fromPercent('12'),
          maturityMonths: 24,
          maturityBasis: MaturityBasis.joiningDate,
        ),
      ];

      expect(
        engine.selectEffectiveVersion(
          const YearMonth(2026, 6),
          rules,
          (rule) => rule.effectiveFrom,
        )!.id,
        'PF-2026-01',
      );
      expect(
        engine.selectEffectiveVersion(
          const YearMonth(2026, 7),
          rules,
          (rule) => rule.effectiveFrom,
        )!.id,
        'PF-2026-07',
      );
    });

    test('missing salary is not treated as zero', () {
      expect(
        () => engine.calculateMonth(
          month: const YearMonth(2026, 4),
          employment: employment,
          salaryHistory: const <SalaryHistoryEntry>[],
          ruleHistory: <PFRuleVersion>[defaultRule],
          salarySchedule: followingMonthSchedule,
        ),
        throwsA(isA<MissingCalculationInput>()),
      );
    });
  });

  group('monthly and historical calculations', () {
    test('calculates independent employee and employer rates', () {
      final unequalRule = PFRuleVersion(
        id: 'unequal',
        effectiveFrom: DateTime(2026),
        basicSalaryRate: Rate.fromPercent('60'),
        employeePFRate: Rate.fromPercent('10'),
        employerPFRate: Rate.fromPercent('12'),
        maturityMonths: 24,
        maturityBasis: MaturityBasis.joiningDate,
      );
      final result = engine.calculateMonth(
        month: const YearMonth(2026, 4),
        employment: employment,
        salaryHistory: <SalaryHistoryEntry>[
          SalaryHistoryEntry(effectiveFrom: DateTime(2026), grossSalary: Money.parse('30000')),
        ],
        ruleHistory: <PFRuleVersion>[unequalRule],
        salarySchedule: followingMonthSchedule,
      );

      expect(result.employeeContribution, Money.parse('1800'));
      expect(result.employerContribution, Money.parse('2160'));
      expect(result.totalContribution, Money.parse('3960'));
    });

    test('reconstructs history using salary changes', () {
      final records = engine.reconstructHistory(
        employment: employment,
        calculationThrough: const YearMonth(2026, 7),
        salaryHistory: <SalaryHistoryEntry>[
          SalaryHistoryEntry(effectiveFrom: DateTime(2026), grossSalary: Money.parse('30000')),
          SalaryHistoryEntry(effectiveFrom: DateTime(2026, 7), grossSalary: Money.parse('35000')),
        ],
        ruleHistory: <PFRuleVersion>[defaultRule],
        salarySchedule: followingMonthSchedule,
      );

      expect(records, hasLength(4));
      expect(records.first.totalContribution, Money.parse('3600'));
      expect(records.last.totalContribution, Money.parse('4200'));
    });

    test('generation date clamps to the last calendar day', () {
      const endOfMonthSchedule = SalarySchedule(
        paymentMonthOffset: 1,
        paymentWindowStartDay: 28,
        paymentWindowEndDay: 31,
      );

      expect(
        engine.scheduledGenerationDate(const YearMonth(2026, 1), endOfMonthSchedule),
        DateTime(2026, 2, 28),
      );
      expect(
        engine.scheduledGenerationDate(const YearMonth(2027, 1), endOfMonthSchedule),
        DateTime(2027, 2, 28),
      );
    });
  });

  group('maturity and statement years', () {
    test('exit exactly on maturity date is mature', () {
      final maturityDate = engine.calculateMaturityDate(employment, defaultRule);

      expect(maturityDate, DateTime(2028));
      expect(engine.maturityStatus(DateTime(2027, 12, 31), maturityDate), MaturityStatus.beforeMaturity);
      expect(engine.maturityStatus(DateTime(2028), maturityDate), MaturityStatus.mature);
      expect(engine.maturityStatus(DateTime(2028, 1, 2), maturityDate), MaturityStatus.mature);
    });

    test('clamps leap-day maturity safely', () {
      final leapEmployment = EmploymentDates(
        joiningDate: DateTime(2024, 2, 29),
        pfStartDate: DateTime(2024, 2, 29),
      );

      expect(engine.calculateMaturityDate(leapEmployment, defaultRule), DateTime(2026, 2, 28));
    });

    test('selects the maturity rule effective on the configured basis date', () {
      final laterRule = PFRuleVersion(
        id: 'later',
        effectiveFrom: DateTime(2027),
        basicSalaryRate: Rate.fromPercent('60'),
        employeePFRate: Rate.fromPercent('10'),
        employerPFRate: Rate.fromPercent('10'),
        maturityMonths: 36,
        maturityBasis: MaturityBasis.joiningDate,
      );

      expect(
        engine
            .selectMaturityRule(
              employment: employment,
              basis: MaturityBasis.joiningDate,
              ruleHistory: <PFRuleVersion>[defaultRule, laterRule],
            )
            .id,
        defaultRule.id,
      );
    });

    test('assigns June and July to the correct July-June statement years', () {
      const configuration = StatementYearConfiguration(startMonth: 7, startDay: 1);

      expect(
        engine.statementYearFor(const YearMonth(2026, 6), configuration),
        const PFStatementYear(startYear: 2025, endYear: 2026),
      );
      expect(
        engine.statementYearFor(const YearMonth(2026, 7), configuration),
        const PFStatementYear(startYear: 2026, endYear: 2027),
      );
    });
  });

  group('balances and exit estimates', () {
    late List<MonthlyPFCalculation> records;

    setUp(() {
      records = engine.reconstructHistory(
        employment: employment,
        calculationThrough: const YearMonth(2026, 5),
        salaryHistory: <SalaryHistoryEntry>[
          SalaryHistoryEntry(effectiveFrom: DateTime(2026), grossSalary: Money.parse('30000')),
        ],
        ruleHistory: <PFRuleVersion>[defaultRule],
        salarySchedule: followingMonthSchedule,
      );
    });

    test('includes only known profit and dated adjustments through cutoff', () {
      final balance = engine.calculateBalance(
        records: records,
        knownProfit: <DatedMoney>[
          DatedMoney(date: DateTime(2026, 5, 20), amount: Money.parse('500')),
          DatedMoney(date: DateTime(2026, 7), amount: Money.parse('900')),
        ],
        adjustments: <DatedMoney>[
          DatedMoney(date: DateTime(2026, 5), amount: Money.parse('-100')),
        ],
        throughDate: DateTime(2026, 5, 31),
      );

      expect(balance, Money.parse('7600'));
    });

    test('forfeits employer contributions before maturity', () {
      final estimate = engine.estimateExit(
        exitDate: DateTime(2026, 5, 31),
        employment: employment,
        maturityRule: defaultRule,
        records: records,
        knownProfit: <DatedMoney>[
          DatedMoney(date: DateTime(2026, 5, 20), amount: Money.parse('500')),
        ],
        adjustments: <DatedMoney>[
          DatedMoney(date: DateTime(2026, 5), amount: Money.parse('-100')),
        ],
        profitComplete: false,
      );

      expect(estimate.status, MaturityStatus.beforeMaturity);
      expect(estimate.employeeContribution, Money.parse('3600'));
      expect(estimate.employerContribution, Money.zero());
      expect(estimate.forfeitedEmployerContribution, Money.parse('3600'));
      expect(estimate.estimatedReceivable, Money.parse('4000'));
      expect(estimate.profitComplete, isFalse);
    });

    test('includes employer contributions on maturity date', () {
      final estimate = engine.estimateExit(
        exitDate: DateTime(2028),
        employment: employment,
        maturityRule: defaultRule,
        records: records,
        knownProfit: const <DatedMoney>[],
        adjustments: const <DatedMoney>[],
        profitComplete: true,
      );

      expect(estimate.status, MaturityStatus.mature);
      expect(estimate.employerContribution, Money.parse('3600'));
      expect(estimate.forfeitedEmployerContribution, Money.zero());
      expect(estimate.estimatedReceivable, Money.parse('7200'));
    });
  });

  group('company statement reconciliation', () {
    test('keeps actual and calculated values separate', () {
      final calculated = StatementSnapshot(closingBalance: Money.parse('85450'));
      final actual = StatementSnapshot(closingBalance: Money.parse('85720'));

      final comparison = engine.reconcileStatement(calculated: calculated, actual: actual);

      expect(comparison.calculated.closingBalance, Money.parse('85450'));
      expect(comparison.actual.closingBalance, Money.parse('85720'));
      expect(comparison.closingDifference, Money.parse('270'));
    });

    test('leaves a difference unknown when either value is missing', () {
      final comparison = engine.reconcileStatement(
        calculated: const StatementSnapshot(),
        actual: StatementSnapshot(profit: Money.zero()),
      );

      expect(comparison.profitDifference, isNull);
      expect(comparison.actual.profit, Money.zero());
    });
  });
}
