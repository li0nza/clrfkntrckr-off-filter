import 'amount.dart';

enum Basis { per100g, per100ml }

enum Field {
  energyKcal,
  energyKj,
  fat,
  saturates,
  carbs,
  sugars,
  polyols,
  fibre,
  protein,
  salt,
  sodium,
  alcohol,
  abv,
}

/// Values from the per 100 g or per 100 ml column of a label. Null means not
/// declared. Polyols and sugars are part of carbs, saturates part of fat.
class NutritionLabel {
  const NutritionLabel({
    required this.basis,
    this.energyKcal,
    this.energyKj,
    this.fat,
    this.saturates,
    this.carbs,
    this.sugars,
    this.polyols,
    this.fibre,
    this.protein,
    this.salt,
    this.sodium,
    this.alcohol,
    this.abv,
  });

  final Basis basis;
  final Amount? energyKcal;
  final Amount? energyKj;
  final Amount? fat;
  final Amount? saturates;
  final Amount? carbs;
  final Amount? sugars;
  final Amount? polyols;
  final Amount? fibre;
  final Amount? protein;
  final Amount? salt;
  final Amount? sodium;

  /// Grams of ethanol.
  final Amount? alcohol;

  /// Alcohol by volume, in percent.
  final double? abv;
}
