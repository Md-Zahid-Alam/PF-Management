class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month)
    : assert(month >= DateTime.january && month <= DateTime.december);

  factory YearMonth.fromDate(DateTime date) => YearMonth(date.year, date.month);

  final int year;
  final int month;

  DateTime get firstDay => DateTime(year, month);
  DateTime get lastDay => DateTime(year, month + 1, 0);

  YearMonth addMonths(int value) {
    final date = DateTime(year, month + value);
    return YearMonth(date.year, date.month);
  }

  Iterable<YearMonth> through(YearMonth end) sync* {
    if (compareTo(end) > 0) return;
    var current = this;
    while (current.compareTo(end) <= 0) {
      yield current;
      current = current.addMonths(1);
    }
  }

  @override
  int compareTo(YearMonth other) =>
      year == other.year ? month.compareTo(other.month) : year.compareTo(other.year);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}
