import 'dart:math' as math;

import 'amount.dart';
import 'label.dart';

enum Check {
  energyKcal,
  energyKj,
  energyRatio,
  sugarsWithinCarbs,
  polyolsWithinCarbs,
  saturatesWithinFat,
  saltMatchesSodium,
  totalWithin100g,
}

enum Outcome { pass, fail, skipped }

class CheckResult {
  const CheckResult(this.check, this.outcome, [this.fields = const {}]);

  final Check check;
  final Outcome outcome;

  /// The fields to highlight when the check fails.
  final Set<Field> fields;

  @override
  String toString() => '${check.name}: ${outcome.name}';
}

/// EU energy conversion factors per gram (Reg. 1169/2011 Annex XIV).
typedef _Factors = ({
  double carbs,
  double protein,
  double fat,
  double fibre,
  double polyolsMax,
  double alcohol,
  double floor,
});

const _kcal = (
  carbs: 4.0,
  protein: 4.0,
  fat: 9.0,
  fibre: 2.0,
  polyolsMax: 2.4,
  alcohol: 7.0,
  floor: 5.0,
);

const _kj = (
  carbs: 17.0,
  protein: 17.0,
  fat: 37.0,
  fibre: 8.0,
  polyolsMax: 10.0,
  alcohol: 29.0,
  floor: 20.0,
);

const _ethanolDensity = 0.789;

/// Labels round values of 10 g or more to whole grams, so three of them can
/// add up to 1.5 g over the real total.
const _roundingSlack = 1.5;

List<CheckResult> checkLabel(NutritionLabel label) => [
  _energy(Check.energyKcal, Field.energyKcal, label.energyKcal, label, _kcal),
  _energy(Check.energyKj, Field.energyKj, label.energyKj, label, _kj),
  _ratio(label),
  _notAbove(
    Check.sugarsWithinCarbs,
    Field.sugars,
    label.sugars,
    Field.carbs,
    label.carbs,
  ),
  _notAbove(
    Check.polyolsWithinCarbs,
    Field.polyols,
    label.polyols,
    Field.carbs,
    label.carbs,
  ),
  _notAbove(
    Check.saturatesWithinFat,
    Field.saturates,
    label.saturates,
    Field.fat,
    label.fat,
  ),
  _saltMatchesSodium(label),
  _totalWithin100g(label),
];

Amount? _alcohol(NutritionLabel label) {
  if (label.alcohol != null) return label.alcohol;
  final abv = label.abv;
  if (abv == null || label.basis != Basis.per100ml) return null;
  return Amount.exact(abv * _ethanolDensity);
}

CheckResult _energy(
  Check check,
  Field field,
  Amount? declared,
  NutritionLabel label,
  _Factors f,
) {
  final fat = label.fat, carbs = label.carbs, protein = label.protein;
  if (declared == null || fat == null || carbs == null || protein == null) {
    return CheckResult(check, Outcome.skipped);
  }
  final polyols = label.polyols ?? Amount.zero;
  final carbsExclPolyols = Amount.range(
    math.max(0, carbs.min - polyols.max),
    math.max(0, carbs.max - polyols.min),
  );
  final alcohol = _alcohol(label);
  final computed =
      carbsExclPolyols * f.carbs +
      protein * f.protein +
      fat * f.fat +
      (label.fibre ?? Amount.zero) * f.fibre +
      polyols.scaledBy(0, f.polyolsMax) +
      (alcohol ?? Amount.zero) * f.alcohol;

  // Fibre is optional on EU labels; its energy may be in the declared value.
  final share = label.fibre == null ? 0.15 : 0.10;
  final low = computed.min - math.max(computed.min * share, f.floor);
  final high = computed.max + math.max(computed.max * share, f.floor);
  if (declared.overlaps(low, high)) return CheckResult(check, Outcome.pass);

  return CheckResult(check, Outcome.fail, {
    field,
    Field.fat,
    Field.carbs,
    Field.protein,
    if (label.fibre != null) Field.fibre,
    if (label.polyols != null) Field.polyols,
    if (label.alcohol != null) Field.alcohol,
    if (label.alcohol == null && alcohol != null) Field.abv,
  });
}

CheckResult _ratio(NutritionLabel label) {
  final kcal = label.energyKcal, kj = label.energyKj;
  if (kcal == null || kj == null || kcal.min < 20) {
    return const CheckResult(Check.energyRatio, Outcome.skipped);
  }
  final ratio = Amount.range(kj.min / kcal.max, kj.max / kcal.min);
  return ratio.overlaps(4.0, 4.35)
      ? const CheckResult(Check.energyRatio, Outcome.pass)
      : const CheckResult(Check.energyRatio, Outcome.fail, {
          Field.energyKcal,
          Field.energyKj,
        });
}

CheckResult _notAbove(
  Check check,
  Field partField,
  Amount? part,
  Field wholeField,
  Amount? whole,
) {
  if (part == null || whole == null) return CheckResult(check, Outcome.skipped);
  return part.min > whole.max
      ? CheckResult(check, Outcome.fail, {partField, wholeField})
      : CheckResult(check, Outcome.pass);
}

CheckResult _saltMatchesSodium(NutritionLabel label) {
  final salt = label.salt, sodium = label.sodium;
  if (salt == null || sodium == null) {
    return const CheckResult(Check.saltMatchesSodium, Outcome.skipped);
  }
  final expected = sodium * 2.5;
  final tolerance = math.max(expected.max * 0.10, 0.05);
  return salt.overlaps(expected.min - tolerance, expected.max + tolerance)
      ? const CheckResult(Check.saltMatchesSodium, Outcome.pass)
      : const CheckResult(Check.saltMatchesSodium, Outcome.fail, {
          Field.salt,
          Field.sodium,
        });
}

CheckResult _totalWithin100g(NutritionLabel label) {
  if (label.basis != Basis.per100g) {
    return const CheckResult(Check.totalWithin100g, Outcome.skipped);
  }
  final parts = {
    Field.fat: label.fat,
    Field.carbs: label.carbs,
    Field.protein: label.protein,
    Field.fibre: label.fibre,
    Field.salt: label.salt,
    Field.alcohol: label.alcohol,
  }..removeWhere((_, amount) => amount == null);
  if (parts.isEmpty) {
    return const CheckResult(Check.totalWithin100g, Outcome.skipped);
  }
  final total = parts.values.fold(0.0, (sum, amount) => sum + amount!.min);
  return total > 100 + _roundingSlack
      ? CheckResult(Check.totalWithin100g, Outcome.fail, parts.keys.toSet())
      : const CheckResult(Check.totalWithin100g, Outcome.pass);
}
