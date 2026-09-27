import 'package:flutter/material.dart';
import 'package:pf_tracker/src/core/branding/brand_identity.dart';
import 'package:pf_tracker/src/core/presentation/localization.dart';

class BrandIdentityHeader extends StatelessWidget {
  const BrandIdentityHeader({super.key, this.logoSize = 88});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '${context.l10n.appName}, ${BrandIdentity.brandName}',
      child: Column(
        children: <Widget>[
          Image.asset(
            'assets/branding/pf_ledger_icon.png',
            key: const Key('pfLedgerSecurityLogo'),
            width: logoSize,
            height: logoSize,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.appName,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            BrandIdentity.brandName,
            key: const Key('securityDeveloperBrand'),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
