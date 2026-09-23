import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';
import 'package:pf_tracker/src/core/security/pin_security.dart';
import 'package:pf_tracker/src/core/security/security_provider.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({required this.destination, super.key});

  final String destination;

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _pinController = TextEditingController();
  PinAttemptGuard _guard = const PinAttemptGuard();
  Timer? _timer;
  bool _loading = true;
  bool _verifying = false;
  bool _obscurePin = true;
  bool _incorrect = false;

  @override
  void initState() {
    super.initState();
    _loadAttemptState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadAttemptState() async {
    try {
      final guard = await ref
          .read(securityRepositoryProvider)
          .readAttemptGuard();
      if (!mounted) {
        return;
      }
      setState(() {
        _guard = guard;
        _loading = false;
      });
      _startTimerIfBlocked();
    } on Object {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.securityDataUnavailable)),
        );
      }
    }
  }

  void _startTimerIfBlocked() {
    _timer?.cancel();
    if (!_guard.isBlockedAt(DateTime.now().toUtc())) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (!_guard.isBlockedAt(DateTime.now().toUtc())) {
        _timer?.cancel();
      }
      setState(() {});
    });
  }

  Future<void> _unlock() async {
    if (_loading || _verifying) {
      return;
    }
    final now = DateTime.now().toUtc();
    if (_guard.isBlockedAt(now)) {
      _startTimerIfBlocked();
      return;
    }
    final pin = _pinController.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() => _incorrect = true);
      return;
    }

    setState(() {
      _verifying = true;
      _incorrect = false;
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
      final verified = await ref.read(pinVerifierProvider)(pin, credential);
      _pinController.clear();
      if (verified) {
        await repository.clearAttemptGuard();
        if (mounted) {
          context.go(widget.destination);
        }
        return;
      }

      final guard = _guard.recordFailure(DateTime.now().toUtc());
      await repository.saveAttemptGuard(guard);
      if (mounted) {
        setState(() {
          _guard = guard;
          _incorrect = true;
          _verifying = false;
        });
        _startTimerIfBlocked();
      }
    } on Object {
      _pinController.clear();
      if (mounted) {
        setState(() => _verifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.securityDataUnavailable)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final remaining = _guard.remainingAt(now);
    final blocked = remaining > Duration.zero;
    final seconds =
        remaining.inSeconds +
        (remaining.inMilliseconds % Duration.millisecondsPerSecond == 0
            ? 0
            : 1);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Image.asset(
                    'assets/branding/pf_ledger_icon.png',
                    width: 88,
                    height: 88,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.unlockPFApp,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.enterPinToContinue,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('unlockPinField'),
                    controller: _pinController,
                    autofocus: true,
                    enabled: !_loading && !blocked && !_verifying,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: PinSecurityService.maximumLength,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: context.l10n.pin,
                      errorText: blocked
                          ? context.l10n.tryAgainInSeconds(seconds)
                          : _incorrect
                          ? context.l10n.incorrectPin
                          : null,
                      suffixIcon: IconButton(
                        tooltip: _obscurePin
                            ? context.l10n.showPin
                            : context.l10n.hidePin,
                        onPressed: blocked
                            ? null
                            : () {
                                setState(() => _obscurePin = !_obscurePin);
                              },
                        icon: Icon(
                          _obscurePin
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('unlockButton'),
                    onPressed: _loading || blocked || _verifying
                        ? null
                        : _unlock,
                    icon: _loading || _verifying
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: Text(context.l10n.unlock),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.pinStaysOnDevice,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
