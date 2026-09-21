import 'package:flutter/widgets.dart';
import 'package:pf_tracker/l10n/generated/app_localizations.dart';

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
