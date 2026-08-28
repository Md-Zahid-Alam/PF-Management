class Rate {
  const Rate._(this.partsPerMillion);

  factory Rate.fromPartsPerMillion(int partsPerMillion) {
    return Rate._(partsPerMillion);
  }

  factory Rate.fromPercent(String percent) {
    final normalized = percent.trim();
    final negative = normalized.startsWith('-');
    final unsigned = negative ? normalized.substring(1) : normalized;
    final pieces = unsigned.split('.');
    if (pieces.length > 2 || pieces.first.isEmpty) {
      throw FormatException('Invalid percentage: $percent');
    }
    final whole = int.parse(pieces.first);
    final fraction = pieces.length == 1 ? '' : pieces.last;
    if (fraction.length > 4) {
      throw FormatException('Percentage supports at most 4 decimal places.');
    }
    final paddedFraction = fraction.padRight(4, '0');
    final value =
        whole * 10000 +
        (paddedFraction.isEmpty ? 0 : int.parse(paddedFraction));
    return Rate._(negative ? -value : value);
  }

  static const zero = Rate._(0);

  final int partsPerMillion;

  @override
  bool operator ==(Object other) =>
      other is Rate && other.partsPerMillion == partsPerMillion;

  @override
  int get hashCode => partsPerMillion.hashCode;
}

class Money implements Comparable<Money> {
  const Money._(this.minorUnits, this.decimalPlaces, this.currencyCode);

  factory Money.fromMinorUnits(
    int minorUnits, {
    int decimalPlaces = 0,
    String currencyCode = 'BDT',
  }) {
    _validateDecimalPlaces(decimalPlaces);
    return Money._(minorUnits, decimalPlaces, currencyCode);
  }

  factory Money.parse(
    String amount, {
    int decimalPlaces = 0,
    String currencyCode = 'BDT',
  }) {
    _validateDecimalPlaces(decimalPlaces);
    final normalized = amount.trim().replaceAll(',', '');
    final negative = normalized.startsWith('-');
    final unsigned = negative ? normalized.substring(1) : normalized;
    final pieces = unsigned.split('.');
    if (pieces.length > 2 || pieces.first.isEmpty) {
      throw FormatException('Invalid money amount: $amount');
    }
    final fraction = pieces.length == 1 ? '' : pieces.last;
    if (fraction.length > decimalPlaces) {
      throw FormatException('Amount exceeds configured decimal places.');
    }
    final scale = _powerOfTen(decimalPlaces);
    final padded = fraction.padRight(decimalPlaces, '0');
    final units =
        int.parse(pieces.first) * scale +
        (padded.isEmpty ? 0 : int.parse(padded));
    return Money._(negative ? -units : units, decimalPlaces, currencyCode);
  }

  factory Money.zero({int decimalPlaces = 0, String currencyCode = 'BDT'}) {
    return Money.fromMinorUnits(
      0,
      decimalPlaces: decimalPlaces,
      currencyCode: currencyCode,
    );
  }

  final int minorUnits;
  final int decimalPlaces;
  final String currencyCode;

  Money multiply(Rate rate) {
    final numerator =
        BigInt.from(minorUnits) * BigInt.from(rate.partsPerMillion);
    final rounded = _divideHalfUp(numerator, BigInt.from(1000000));
    return Money._(rounded.toInt(), decimalPlaces, currencyCode);
  }

  Money operator +(Money other) {
    _requireCompatible(other);
    return Money._(minorUnits + other.minorUnits, decimalPlaces, currencyCode);
  }

  Money operator -(Money other) {
    _requireCompatible(other);
    return Money._(minorUnits - other.minorUnits, decimalPlaces, currencyCode);
  }

  Money operator -() => Money._(-minorUnits, decimalPlaces, currencyCode);

  @override
  int compareTo(Money other) {
    _requireCompatible(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  void _requireCompatible(Money other) {
    if (decimalPlaces != other.decimalPlaces ||
        currencyCode != other.currencyCode) {
      throw ArgumentError(
        'Money values must use the same currency and precision.',
      );
    }
  }

  static BigInt _divideHalfUp(BigInt numerator, BigInt denominator) {
    final negative = numerator.isNegative;
    final absolute = numerator.abs();
    final quotient = absolute ~/ denominator;
    final remainder = absolute.remainder(denominator);
    final rounded = remainder * BigInt.two >= denominator
        ? quotient + BigInt.one
        : quotient;
    return negative ? -rounded : rounded;
  }

  static int _powerOfTen(int exponent) {
    var result = 1;
    for (var index = 0; index < exponent; index++) {
      result *= 10;
    }
    return result;
  }

  static void _validateDecimalPlaces(int decimalPlaces) {
    if (decimalPlaces < 0 || decimalPlaces > 6) {
      throw RangeError.range(decimalPlaces, 0, 6, 'decimalPlaces');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.decimalPlaces == decimalPlaces &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, decimalPlaces, currencyCode);

  @override
  String toString() => '$currencyCode $minorUnits@$decimalPlaces';
}
