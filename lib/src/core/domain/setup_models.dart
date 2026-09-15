import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';

class InitialPFSetup {
  const InitialPFSetup({
    required this.employeeName,
    required this.organizationName,
    required this.joiningDate,
    required this.pfStartDate,
    required this.salary,
    required this.rule,
    required this.salarySchedule,
    this.employeeCode,
    this.probationStartDate,
    this.probationMonths,
    this.permanentDate,
    this.exitDate,
    this.employmentStatus = 'active',
  });

  final String employeeName;
  final String? employeeCode;
  final String organizationName;
  final DateTime joiningDate;
  final DateTime? probationStartDate;
  final int? probationMonths;
  final DateTime? permanentDate;
  final DateTime pfStartDate;
  final DateTime? exitDate;
  final String employmentStatus;
  final StoredSalary salary;
  final StoredPFRule rule;
  final EffectiveSalarySchedule salarySchedule;

  EmploymentDates get employmentDates => EmploymentDates(
    joiningDate: joiningDate,
    permanentDate: permanentDate,
    pfStartDate: pfStartDate,
    exitDate: exitDate,
  );
}
