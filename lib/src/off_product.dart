import 'package:clrfkntrckr_off_filter/nutrition_checks.dart' show Basis;

import 'food_kind.dart';

export 'package:clrfkntrckr_off_filter/nutrition_checks.dart' show Basis;

/// The energy unit filled in at 4.184 kJ/kcal because the label lacked it.
enum DerivedEnergy { kcal, kj }

/// An Open Food Facts product as stored in the food database. Nutrients are
/// label values per 100 g or 100 ml; null means not declared.
class OffProduct {
  const OffProduct({
    required this.barcode,
    required this.name,
    this.nameNl,
    this.nameEn,
    this.brands,
    this.quantity,
    this.categories = const [],
    required this.basis,
    required this.energyKcal,
    required this.energyKj,
    this.derivedEnergy,
    required this.fat,
    this.saturates,
    required this.carbs,
    this.sugars,
    this.polyols,
    this.fibre,
    required this.protein,
    this.salt,
    this.sodium,
    this.abv,
    this.lastModified,
    this.servingSize,
    this.servingSlices,
  });

  final String barcode;

  /// The name as printed on the pack, in the pack's main language.
  final String name;
  final String? nameNl;
  final String? nameEn;
  final String? brands;
  final String? quantity;

  /// OFF category tags, e.g. `en:chicken-breasts`.
  final List<String> categories;
  final Basis basis;
  final double energyKcal;
  final double energyKj;
  final DerivedEnergy? derivedEnergy;
  final double fat;
  final double? saturates;
  final double carbs;
  final double? sugars;
  final double? polyols;
  final double? fibre;
  final double protein;
  final double? salt;
  final double? sodium;

  /// Alcohol by volume, in percent.
  final double? abv;
  final DateTime? lastModified;

  /// One serving in g for a product per 100 g, in ml for one per 100 ml.
  final double? servingSize;

  /// The slices one serving is, when the label counts it in slices or the
  /// product is bread sold per slice.
  final int? servingSlices;

  String get sourceKey => 'off:$barcode';

  FoodKind? get kind =>
      offFoodKind(categories, basis, energyKcal, fibre: fibre);

  /// Logged into Drinks: `en:beverages` without `en:dairies` or
  /// `en:milk-substitutes`, the food database's rule, so milk and plant
  /// drinks stay food.
  bool get drink =>
      categories.contains('en:beverages') &&
      !categories.contains('en:dairies') &&
      !categories.contains('en:milk-substitutes');
}
