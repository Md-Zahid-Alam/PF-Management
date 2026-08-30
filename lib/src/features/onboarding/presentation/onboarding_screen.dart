import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/database/drift_repositories.dart';
import 'package:pf_tracker/src/core/domain/automation_models.dart';
import 'package:pf_tracker/src/core/domain/calculation_policy.dart';
import 'package:pf_tracker/src/core/domain/money.dart';
import 'package:pf_tracker/src/core/domain/persistence_models.dart';
import 'package:pf_tracker/src/core/domain/pf_models.dart';
import 'package:pf_tracker/src/core/domain/setup_models.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({this.editExisting = false, super.key});

  final bool editExisting;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeName = TextEditingController();
  final _employeeCode = TextEditingController();
  final _organizationName = TextEditingController();
  final _grossSalary = TextEditingController();
  final _basicRate = TextEditingController(text: '60');
  final _employeeRate = TextEditingController(text: '10');
  final _employerRate = TextEditingController(text: '10');
  final _maturityYears = TextEditingController(text: '2');
  final _windowStart = TextEditingController(text: '1');
  final _windowEnd = TextEditingController(text: '5');

  var _step = 0;
  var _joiningDate = DateTime.now();
  DateTime? _permanentDate;
  var _pfStartDate = DateTime.now();
  var _maturityBasis = MaturityBasis.joiningDate;
  var _entitledBeforeMaturity = false;
  var _entitledAfterMaturity = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _employeeName,
      _employeeCode,
      _organizationName,
      _grossSalary,
      _basicRate,
      _employeeRate,
      _employerRate,
      _maturityYears,
      _windowStart,
      _windowEnd,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editExisting ? 'Edit PF setup' : 'Set up PF Tracker',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Stepper(
            currentStep: _step,
            onStepTapped: (value) => setState(() => _step = value),
            onStepContinue: _saving ? null : _continue,
            onStepCancel: _step == 0 ? null : () => setState(() => _step -= 1),
            controlsBuilder: (context, details) {
              final last = _step == 2;
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  children: <Widget>[
                    FilledButton(
                      key: Key(last ? 'saveSetupButton' : 'continueButton'),
                      onPressed: details.onStepContinue,
                      child: Text(
                        _saving
                            ? 'Saving…'
                            : last
                            ? 'Save setup'
                            : 'Continue',
                      ),
                    ),
                    if (details.onStepCancel != null) ...<Widget>[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: <Step>[
              Step(
                title: const Text('Profile & employment'),
                isActive: _step >= 0,
                content: Column(
                  children: <Widget>[
                    _requiredTextField(
                      key: const Key('employeeNameField'),
                      controller: _employeeName,
                      label: 'Employee name',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _employeeCode,
                      decoration: const InputDecoration(
                        labelText: 'Employee ID (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'Joining date',
                      value: _joiningDate,
                      onChanged: (value) => setState(() {
                        _joiningDate = value;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'Permanent date (optional)',
                      value: _permanentDate,
                      optional: true,
                      onChanged: (value) => setState(() {
                        _permanentDate = value;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'PF start date',
                      value: _pfStartDate,
                      onChanged: (value) => setState(() {
                        _pfStartDate = value;
                      }),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Organization & PF rules'),
                isActive: _step >= 1,
                content: Column(
                  children: <Widget>[
                    _requiredTextField(
                      controller: _organizationName,
                      label: 'Organization name',
                    ),
                    const SizedBox(height: 12),
                    _positiveNumberField(
                      controller: _grossSalary,
                      label: 'Current gross salary',
                      prefix: '৳ ',
                    ),
                    const SizedBox(height: 12),
                    _percentageField(_basicRate, 'Basic salary'),
                    const SizedBox(height: 12),
                    _percentageField(_employeeRate, 'Employee PF'),
                    const SizedBox(height: 12),
                    _percentageField(_employerRate, 'Employer PF'),
                    const SizedBox(height: 12),
                    _positiveNumberField(
                      controller: _maturityYears,
                      label: 'Maturity period',
                      suffix: 'years',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<MaturityBasis>(
                      initialValue: _maturityBasis,
                      decoration: const InputDecoration(
                        labelText: 'Maturity basis',
                      ),
                      items: const <DropdownMenuItem<MaturityBasis>>[
                        DropdownMenuItem(
                          value: MaturityBasis.joiningDate,
                          child: Text('Joining date'),
                        ),
                        DropdownMenuItem(
                          value: MaturityBasis.pfStartDate,
                          child: Text('PF start date'),
                        ),
                        DropdownMenuItem(
                          value: MaturityBasis.permanentDate,
                          child: Text('Permanent date'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _maturityBasis = value ?? MaturityBasis.joiningDate;
                      }),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Company PF entitled before maturity'),
                      value: _entitledBeforeMaturity,
                      onChanged: (value) => setState(() {
                        _entitledBeforeMaturity = value;
                      }),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Company PF entitled after maturity'),
                      value: _entitledAfterMaturity,
                      onChanged: (value) => setState(() {
                        _entitledAfterMaturity = value;
                      }),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Salary schedule'),
                isActive: _step >= 2,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Salary is paid in the following month. PF generation uses the last day of this payment window.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(child: _dayField(_windowStart, 'Start day')),
                        const SizedBox(width: 12),
                        Expanded(child: _dayField(_windowEnd, 'End day')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'If a configured day does not exist, the last calendar day is used.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _requiredTextField({
    required TextEditingController controller,
    required String label,
    Key? key,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label is required' : null,
    );
  }

  TextFormField _positiveNumberField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        final number = int.tryParse(value ?? '');
        return number == null || number <= 0 ? 'Enter a valid $label' : null;
      },
    );
  }

  TextFormField _percentageField(
    TextEditingController controller,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        final number = double.tryParse(value ?? '');
        return number == null || number < 0 || number > 100
            ? 'Enter a percentage from 0 to 100'
            : null;
      },
    );
  }

  TextFormField _dayField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      validator: (value) {
        final day = int.tryParse(value ?? '');
        return day == null || day < 1 || day > 31 ? 'Use 1–31' : null;
      },
    );
  }

  Future<void> _continue() async {
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_pfStartDate.isBefore(_joiningDate)) {
      _showMessage('PF start date cannot be before joining date.');
      return;
    }
    if (_permanentDate != null && _permanentDate!.isBefore(_joiningDate)) {
      _showMessage('Permanent date cannot be before joining date.');
      return;
    }
    if (_maturityBasis == MaturityBasis.permanentDate &&
        _permanentDate == null) {
      _showMessage('Set a permanent date for the selected maturity basis.');
      return;
    }
    final windowStart = int.parse(_windowStart.text);
    final windowEnd = int.parse(_windowEnd.text);
    if (windowEnd < windowStart) {
      _showMessage('End day must be on or after start day.');
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final setup = InitialPFSetup(
      employeeName: _employeeName.text,
      employeeCode: _employeeCode.text,
      organizationName: _organizationName.text,
      joiningDate: _joiningDate,
      permanentDate: _permanentDate,
      pfStartDate: _pfStartDate,
      salary: StoredSalary(
        id: 'initial-salary',
        employmentId: DriftInitialSetupRepository.employmentId,
        effectiveFrom: _pfStartDate,
        grossSalary: Money.parse(_grossSalary.text),
        createdAt: now,
        updatedAt: now,
      ),
      rule: StoredPFRule(
        rule: PFRuleVersion(
          id: 'initial-pf-rule',
          effectiveFrom: _pfStartDate,
          basicSalaryRate: Rate.fromPercent(_basicRate.text),
          employeePFRate: Rate.fromPercent(_employeeRate.text),
          employerPFRate: Rate.fromPercent(_employerRate.text),
          maturityMonths: int.parse(_maturityYears.text) * 12,
          maturityBasis: _maturityBasis,
          employerEntitledBeforeMaturity: _entitledBeforeMaturity,
          employerEntitledAfterMaturity: _entitledAfterMaturity,
        ),
        organizationId: DriftInitialSetupRepository.organizationId,
        partialMonthPolicy: PartialMonthPolicy.fullContribution,
        effectiveVersionPolicy: EffectiveVersionPolicy.monthEnd,
        createdAt: now,
        updatedAt: now,
      ),
      salarySchedule: EffectiveSalarySchedule(
        id: 'initial-salary-schedule',
        effectiveFrom: _pfStartDate,
        schedule: SalarySchedule(
          paymentMonthOffset: 1,
          paymentWindowStartDay: windowStart,
          paymentWindowEndDay: windowEnd,
        ),
      ),
    );
    try {
      await ref.read(initialSetupRepositoryProvider).save(setup);
      if (mounted) {
        context.go(widget.editExisting ? '/settings' : '/');
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save setup. Try again.')),
        );
      }
    }
  }

  Future<void> _initialize() async {
    try {
      final repository = ref.read(initialSetupRepositoryProvider);
      final existing = await repository.load();
      if (!mounted || existing == null) {
        return;
      }
      if (!widget.editExisting) {
        context.go('/');
        return;
      }
      setState(() {
        _employeeName.text = existing.employeeName;
        _employeeCode.text = existing.employeeCode ?? '';
        _organizationName.text = existing.organizationName;
        _joiningDate = existing.joiningDate;
        _permanentDate = existing.permanentDate;
        _pfStartDate = existing.pfStartDate;
        _grossSalary.text = existing.salary.grossSalary.minorUnits.toString();
        _basicRate.text = _formatRate(existing.rule.rule.basicSalaryRate);
        _employeeRate.text = _formatRate(existing.rule.rule.employeePFRate);
        _employerRate.text = _formatRate(existing.rule.rule.employerPFRate);
        _maturityYears.text = (existing.rule.rule.maturityMonths ~/ 12)
            .toString();
        _maturityBasis = existing.rule.rule.maturityBasis;
        _entitledBeforeMaturity =
            existing.rule.rule.employerEntitledBeforeMaturity;
        _entitledAfterMaturity =
            existing.rule.rule.employerEntitledAfterMaturity;
        _windowStart.text = existing
            .salarySchedule
            .schedule
            .paymentWindowStartDay
            .toString();
        _windowEnd.text = existing.salarySchedule.schedule.paymentWindowEndDay
            .toString();
      });
    } on Object {
      // A setup read failure leaves the recoverable setup form visible.
    }
  }

  static String _formatRate(Rate rate) {
    final value = rate.partsPerMillion / 10000;
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.optional = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: optional && value != null
              ? IconButton(
                  tooltip: 'Clear $label',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.clear),
                )
              : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value == null ? 'Not set' : DateFormat.yMMMd().format(value!),
        ),
      ),
    );
  }
}
