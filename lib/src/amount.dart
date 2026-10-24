/// A label value as a range, so rounded and bounded values check correctly.
class Amount {
  const Amount.exact(double value) : min = value, max = value;

  /// A value printed as "<x".
  const Amount.below(double bound) : min = 0, max = bound;

  /// A value printed as "sporen" (traces).
  const Amount.traces() : min = 0, max = 0.5;

  const Amount.range(this.min, this.max) : assert(min <= max);

  static const zero = Amount.exact(0);

  final double min;
  final double max;

  Amount operator +(Amount other) =>
      Amount.range(min + other.min, max + other.max);

  Amount operator *(double factor) => Amount.range(min * factor, max * factor);

  /// Multiplies by a factor that is itself a range, e.g. polyols at 0–2.4 kcal/g.
  Amount scaledBy(double low, double high) =>
      Amount.range(min * low, max * high);

  bool overlaps(double low, double high) => max >= low && min <= high;

  @override
  String toString() => min == max ? '$min' : '$min–$max';
}
