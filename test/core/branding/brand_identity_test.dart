import 'package:flutter_test/flutter_test.dart';
import 'package:pf_tracker/src/core/branding/brand_identity.dart';

void main() {
  test('keeps approved public identity values centralized', () {
    expect(BrandIdentity.productName, 'PF Ledger');
    expect(BrandIdentity.developerName, 'Md. Zahid Alam Rifat');
    expect(BrandIdentity.brandName, 'Rifat Labs');
    expect(BrandIdentity.productOwnerName, 'Md. Zahid Alam Rifat');
    expect(BrandIdentity.copyrightOwner, 'Rifat Labs');
    expect(BrandIdentity.copyrightYear, 2026);
  });
}
