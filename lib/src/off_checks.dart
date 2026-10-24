import 'package:clrfkntrckr_off_filter/nutrition_checks.dart';

import 'off_product.dart';

/// The maths checks [product] fails. Derived
/// energy isn't on the label, so the checks treat it as undeclared.
Set<Check> failedChecks(OffProduct product) => {
  for (final result in checkLabel(_label(product)))
    if (result.outcome == Outcome.fail) result.check,
};

NutritionLabel _label(OffProduct product) => NutritionLabel(
  basis: product.basis,
  energyKcal: product.derivedEnergy == DerivedEnergy.kcal
      ? null
      : Amount.exact(product.energyKcal),
  energyKj: product.derivedEnergy == DerivedEnergy.kj
      ? null
      : Amount.exact(product.energyKj),
  fat: Amount.exact(product.fat),
  saturates: _amount(product.saturates),
  carbs: Amount.exact(product.carbs),
  sugars: _amount(product.sugars),
  polyols: _amount(product.polyols),
  fibre: _amount(product.fibre),
  protein: Amount.exact(product.protein),
  salt: _amount(product.salt),
  sodium: _amount(product.sodium),
  abv: product.abv,
);

Amount? _amount(double? value) => value == null ? null : Amount.exact(value);
