import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _saving = false;
  bool _obscurePin = true;
  bool _currentPinIncorrect = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _currentPinIncorrect = false;
    });
    try {
      final repository = ref.read(securityRepositoryProvider);
      final credential = await repository.readCredential();
      if (credential == null) {
        if (mounted) {
          context.go('/security/create-pin');
        }
        return;
      }
      final verified = await ref.read(pinVerifierProvider)(
        _currentPinController.text,
        credential,
      );
      if (!verified) {
        _currentPinController.clear();
        if (mounted) {
          setState(() {
            _currentPinIncorrect = true;
            _saving = false;
          });
        }
        return;
      }

      final replacement = await ref.read(pinCredentialFactoryProvider)(
        _newPinController.text,
      );
      await repository.saveCredential(replacement);
      await repository.clearAttemptGuard();
      _clearControllers();
      if (mounted) {
        ref.invalidate(hasPinProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.pinChangedSuccessfully)),
        );
        context.pop();
      }
    } on Object {
      _clearControllers();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.pinCouldNotBeChanged)),
        );
      }
    }
  }

  void _clearControllers() {
    _currentPinController.clear();
    _newPinController.clear();
    _confirmationController.clear();
  }

  String? _validatePin(String? value) {
    if (value == null || !RegExp(r'^\d{4,8}$').hasMatch(value)) {
      return context.l10n.pinLengthError;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.changePin)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      key: const Key('currentPinField'),
                      controller: _currentPinController,
                      autofocus: true,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      maxLength: PinSecurityService.maximumLength,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: context.l10n.currentPin,
                        errorText: _currentPinIncorrect
                            ? context.l10n.currentPinIncorrect
                            : null,
                        suffixIcon: IconButton(
                          tooltip: _obscurePin
                              ? context.l10n.showPin
                              : context.l10n.hidePin,
                          onPressed: () {
                            setState(() => _obscurePin = !_obscurePin);
                          },
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validatePin,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('newPinField'),
                      controller: _newPinController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      maxLength: PinSecurityService.maximumLength,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: context.l10n.newPin,
                        helperText: context.l10n.pinLengthHelp,
                      ),
                      validator: _validatePin,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('confirmNewPinField'),
                      controller: _confirmationController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: PinSecurityService.maximumLength,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: context.l10n.confirmNewPin,
                      ),
                      validator: (value) => value == _newPinController.text
                          ? null
                          : context.l10n.pinMismatch,
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('changePinButton'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.password_rounded),
                      label: Text(context.l10n.changePin),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.changePinSafetyNotice,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
