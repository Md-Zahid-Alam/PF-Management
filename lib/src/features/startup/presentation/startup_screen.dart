import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pf_tracker/src/core/database/database_provider.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _openInitialDestination();
  }

  Future<void> _openInitialDestination() async {
    if (_error != null) {
      setState(() => _error = null);
    }
    try {
      final hasCompletedSetup = await ref
          .read(initialSetupRepositoryProvider)
          .hasCompletedSetup();
      if (!mounted) {
        return;
      }
      context.go(hasCompletedSetup ? '/' : '/setup');
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    'assets/branding/pf_ledger_icon.png',
                    key: const Key('pfLedgerLogo'),
                    width: 96,
                    height: 96,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.appName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  if (error == null)
                    const CircularProgressIndicator()
                  else ...<Widget>[
                    Text(
                      context.l10n.couldNotOpenData,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.checkStorageAndRetry,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('retryStartupButton'),
                      onPressed: _openInitialDestination,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.tryAgain),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
