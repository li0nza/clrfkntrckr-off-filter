import 'gtin.dart';
import 'off_product.dart';

const kjPerKcal = 4.184;

enum DropReason {
  notDutch,
  invalidBarcode,
  inStoreBarcode,
  noName,
  obsolete,
  noLabel,
  noEnergy,
  noMacros,
}

sealed class ParsedProduct {
  const ParsedProduct();
}

final class Kept extends ParsedProduct {
  const Kept(this.product);

  final OffProduct product;
}

final class Dropped extends ParsedProduct {
  const Dropped(this.reason);

  final DropReason reason;
}

/// Applies the NL subset rules to one product
/// from the OFF JSONL export or the API. A [scanned] product is in the user's
/// hands, so the countries OFF lists and its obsolete flag don't count.
ParsedProduct parseOffProduct(
  Map<String, Object?> json, {
  bool scanned = false,
}) {
  final countries = json['countries_tags'];
  if (!scanned &&
      (countries is! List<Object?> || !countries.contains('en:netherlands'))) {
    return const Dropped(DropReason.notDutch);
  }

  final barcode = _text(json['code']);
  if (barcode == null || !isValidGtin(barcode)) {
    return const Dropped(DropReason.invalidBarcode);
  }
  if (isInStoreCode(barcode)) return const Dropped(DropReason.inStoreBarcode);

  final nameNl = _text(json['product_name_nl']);
  final nameEn = _text(json['product_name_en']);
  final name =
      _text(json['product_name']) ?? nameNl ?? nameEn ?? _otherName(json);
  if (name == null) return const Dropped(DropReason.noName);

  if (!scanned && _isOn(json['obsolete'])) {
    return const Dropped(DropReason.obsolete);
  }

  final label = _isOn(json['no_nutrition_data'])
      ? null
      : _AggregatedSet.from(json) ?? _Nutriments.from(json);
  if (label == null) return const Dropped(DropReason.noLabel);

  var kcal = label.value('energy-kcal', 'kcal');
  var kj = label.value('energy-kj', 'kJ');
  if (kcal == null && kj == null) kj = label.value('energy', 'kJ');
  if (kcal == null && kj == null) return const Dropped(DropReason.noEnergy);
  final derivedEnergy = kcal == null
      ? DerivedEnergy.kcal
      : kj == null
      ? DerivedEnergy.kj
      : null;
  kcal ??= kj! / kjPerKcal;
  kj ??= kcal * kjPerKcal;

  final fat = label.value('fat', 'g');
  final carbs = label.value('carbohydrates', 'g');
  final protein = label.value('proteins', 'g');
  if (fat == null || carbs == null || protein == null) {
    return const Dropped(DropReason.noMacros);
  }

  final categories = json['categories_tags'];
  final lastModified = json['last_modified_t'];
  return Kept(
    OffProduct(
      barcode: barcode,
      name: name,
      nameNl: nameNl,
      nameEn: nameEn,
      brands: _text(json['brands']),
      quantity: _text(json['quantity']),
      categories: categories is List<Object?>
          ? categories.whereType<String>().toList()
          : const [],
      basis: label.basis,
      energyKcal: kcal,
      energyKj: kj,
      derivedEnergy: derivedEnergy,
      fat: fat,
      saturates: label.value('saturated-fat', 'g'),
      carbs: carbs,
      sugars: label.value('sugars', 'g'),
      polyols: label.value('polyols', 'g'),
      fibre: label.value('fiber', 'g'),
      protein: protein,
      salt: label.value('salt', 'g'),
      sodium: label.value('sodium', 'g'),
      abv: label.value('alcohol', '% vol'),
      lastModified: lastModified is int
          ? DateTime.fromMillisecondsSinceEpoch(
              lastModified * 1000,
              isUtc: true,
            )
          : null,
    ),
  );
}

/// Label values per 100 g or 100 ml, as sold.
abstract interface class _Label {
  Basis get basis;

  /// The declared value of an OFF nutrient in [unit], or null when the label
  /// doesn't give it.
  double? value(String nutrient, String unit);
}

/// The current OFF nutrition schema. The aggregated set also holds values OFF
/// estimated or filled in itself; a value counts only when the input set it
/// came from declares it.
class _AggregatedSet implements _Label {
  _AggregatedSet(this.basis, this._nutrients, this._inputs);

  static _AggregatedSet? from(Map<String, Object?> json) {
    final nutrition = json['nutrition'];
    if (nutrition is! Map<String, Object?>) return null;
    final set = nutrition['aggregated_set'];
    if (set is! Map<String, Object?>) return null;
    final preparation = set['preparation'];
    if (preparation != null && preparation != 'as_sold') return null;
    // OFF's form defaults to per 100 g, also for drinks.
    final basis = switch (set['per']) {
      '100g' when json['product_quantity_unit'] == 'ml' => Basis.per100ml,
      final per => _basis(per),
    };
    final nutrients = set['nutrients'];
    if (basis == null || nutrients is! Map<String, Object?>) return null;
    final inputs = nutrition['input_sets'];
    return _AggregatedSet(
      basis,
      nutrients,
      inputs is List<Object?> ? inputs : const [],
    );
  }

  @override
  final Basis basis;
  final Map<String, Object?> _nutrients;
  final List<Object?> _inputs;

  @override
  double? value(String nutrient, String unit) {
    final aggregated = _nutrients[nutrient];
    if (aggregated is! Map<String, Object?>) return null;
    if (aggregated['source'] == 'estimate' || aggregated['unit'] != unit) {
      return null;
    }
    final index = aggregated['source_index'];
    if (index is int && index < _inputs.length) {
      final input = _inputs[index];
      final inputNutrients = input is Map<String, Object?>
          ? input['nutrients']
          : null;
      final declared = inputNutrients is Map<String, Object?>
          ? inputNutrients[nutrient]
          : null;
      if (declared is! Map<String, Object?> || declared['value'] == null) {
        return null;
      }
    }
    return _number(aggregated['value']);
  }
}

/// The legacy OFF schema: flat `<nutrient>_100g` keys in g, kcal, kJ or % vol.
/// Estimates there have keys of their own.
class _Nutriments implements _Label {
  _Nutriments(this.basis, this._nutriments);

  static _Nutriments? from(Map<String, Object?> json) {
    final nutriments = json['nutriments'];
    if (nutriments is! Map<String, Object?> || nutriments.isEmpty) return null;
    final basis = json['product_quantity_unit'] == 'ml'
        ? Basis.per100ml
        : Basis.per100g;
    return _Nutriments(basis, nutriments);
  }

  @override
  final Basis basis;
  final Map<String, Object?> _nutriments;

  @override
  double? value(String nutrient, String unit) =>
      _number(_nutriments['${nutrient}_100g']);
}

Basis? _basis(Object? per) => switch (per) {
  '100g' => Basis.per100g,
  '100ml' => Basis.per100ml,
  _ => null,
};

final _languageName = RegExp(r'^product_name_[a-z]{2}$');

String? _otherName(Map<String, Object?> json) {
  for (final MapEntry(:key, :value) in json.entries) {
    if (_languageName.hasMatch(key)) {
      final name = _text(value);
      if (name != null) return name;
    }
  }
  return null;
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _number(Object? value) {
  final number = switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value.trim().replaceAll(',', '.')),
    _ => null,
  };
  return number != null && number.isFinite ? number : null;
}

bool _isOn(Object? value) => const {'on', 'true', '1'}.contains('$value');
