import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';

class CreatePinScreen extends ConsumerStatefulWidget {
  const CreatePinScreen({super.key});

  @override
  ConsumerState<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends ConsumerState<CreatePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _saving = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final credential = await ref.read(pinCredentialFactoryProvider)(
        _pinController.text,
      );
      await ref.read(securityRepositoryProvider).saveCredential(credential);
      await ref.read(securityRepositoryProvider).clearAttemptGuard();
      ref.invalidate(hasPinProvider);
      final hasCompletedSetup = await ref
          .read(initialSetupRepositoryProvider)
          .hasCompletedSetup();
      _pinController.clear();
      _confirmationController.clear();
      if (mounted) {
        context.go(hasCompletedSetup ? '/' : '/setup');
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.pinCouldNotBeSaved)),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Icon(Icons.lock_outline_rounded, size: 72),
                    const SizedBox(height: 24),
                    Text(
                      context.l10n.createAppPin,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.createPinDescription,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      key: const Key('createPinField'),
                      controller: _pinController,
                      autofocus: true,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      maxLength: PinSecurityService.maximumLength,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: context.l10n.pin,
                        helperText: context.l10n.pinLengthHelp,
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
                      validator: (value) {
                        if (value == null ||
                            !RegExp(r'^\d{4,8}$').hasMatch(value)) {
                          return context.l10n.pinLengthError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('confirmPinField'),
                      controller: _confirmationController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: PinSecurityService.maximumLength,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: context.l10n.confirmPin,
                      ),
                      validator: (value) => value == _pinController.text
                          ? null
                          : context.l10n.pinMismatch,
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('savePinButton'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_rounded),
                      label: Text(context.l10n.savePin),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.pinPrivacyNotice,
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
