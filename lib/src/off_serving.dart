import 'package:clrfkntrckr_off_filter/nutrition_checks.dart' show Basis;

/// One serving as an OFF product gives it: [size] in g for a product per
/// 100 g, in ml for one per 100 ml, and the [slices] it counts when its text
/// names them ("2 sneetjes (70 g)"), with a printed single-unit [word].
typedef OffServing = ({double size, int? slices, String? word});

/// A bread serving at or above this is a reference amount, not a slice.
const sliceMaxGrams = 100.0;

/// The serving from OFF's `serving_size` text and its `serving_quantity` and
/// `serving_quantity_unit`, which OFF works out from that text; null when
/// there is none, or it is in another unit than [basis]. The size and its
/// unit come from one of the two: OFF's quantity when it is above zero in g
/// or ml, else the last weight or volume in the text. With [bread], a
/// serving given as a weight alone ("35 g", "1 portie (35 g)") under
/// [sliceMaxGrams] counts as one slice, as Dutch packs give bread per slice.
OffServing? parseOffServing(
  Object? servingSize,
  Object? servingQuantity,
  Object? servingQuantityUnit, {
  required Basis basis,
  bool bread = false,
}) {
  final text = servingSize is String ? servingSize.trim().toLowerCase() : '';
  final quantity = _number(servingQuantity);
  final quantityUnit = servingQuantityUnit is String
      ? _unit(servingQuantityUnit.trim().toLowerCase())
      : null;
  final written = _weight.allMatches(text).lastOrNull;
  final (size, unit) = quantity != null && quantity > 0 && quantityUnit != null
      ? (quantity, quantityUnit)
      : (_number(written?[1]), written == null ? null : _unit(written[2]!));
  final basisUnit = switch (basis) {
    Basis.per100g => 'g',
    Basis.per100ml => 'ml',
  };
  if (size == null || size <= 0 || unit != basisUnit) return null;

  final named = _slices.firstMatch(text);
  final slices = named != null
      ? int.tryParse(named[1] ?? '1')
      : bread && _plain.hasMatch(text) && size < sliceMaxGrams
      ? 1
      : null;
  return (
    size: size,
    slices: slices == 0 ? null : slices,
    word: _servingWord(servingSize),
  );
}

/// A weight or volume in a serving text: "35 g", "35,5 gram", "(250 ml)".
final _weight = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(g|gr|gram|grams|grammes|grammi|gramm|ml)\b',
);

/// A count of slices at the start: "snee", "2 sneetjes", "1 slice", "2 x
/// boterham".
final _slices = RegExp(
  r'^(\d+)?\s*(?:x\s*)?(?:snee|sneetjes?|sneden|boterhams?|boterhammen|'
  r'plak|plakje|plakjes|plakken|slices?|tranches?|scheiben?)\b',
);

/// A serving that is a weight alone, or one serving of a weight: "35 g",
/// "35.0g", "1 portie (35 g)", "1 serving (35 g)".
final _plain = RegExp(
  r'^(?:1\s*(?:portie|portion|serving|serve)\s*)?'
  r'\(?\s*\d+(?:[.,]\d+)?\s*(?:g|gr|gram|grams|grammes|grammi|gramm)\s*\)?$',
);

String? _unit(String unit) => switch (unit) {
  'g' || 'gr' || 'gram' || 'grams' || 'grammes' || 'grammi' || 'gramm' => 'g',
  'ml' => 'ml',
  _ => null,
};

double? _number(Object? value) {
  final number = switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value.trim().replaceAll(',', '.')),
    _ => null,
  };
  return number != null && number.isFinite ? number : null;
}

/// Only an unambiguous single unit names the whole serving. Multiple units
/// remain one generic portion; bread's slice count is parsed independently.
String? _servingWord(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  final match = _namedServing.firstMatch(text) ?? _unitOnly.firstMatch(text);
  if (match == null) return null;
  final word = match[1]!;
  if (_genericWords.contains(word.toLowerCase())) return null;
  return word;
}

const _genericWords = {
  'portion',
  'portie',
  'serving',
  'serve',
  'portions',
  'porties',
  'servings',
  'porción',
  'porzione',
  'per',
  'about',
  'approx',
  'approximately',
  'circa',
  'g',
  'ml',
};

final _namedServing = RegExp(
  r'^(?:(?:1\s*(?:[x×]\s*)?|per\s+))?'
  r"([a-zÀ-ÖØ-öø-ÿ]+(?:[-'][a-zÀ-ÖØ-öø-ÿ]+)*)\s*"
  r'(?:[=(]\s*)?\d+(?:[.,]\d+)?\s*'
  r'(?:g|gr|gram|grams|grammes|grammi|gramm|ml)\s*\)?$',
  caseSensitive: false,
);

// A trustworthy serving_quantity can supply the weight absent from the text.
final _unitOnly = RegExp(
  r'^(?:1\s*(?:[x×]\s*)?|per\s+)'
  r"([a-zÀ-ÖØ-öø-ÿ]+(?:[-'][a-zÀ-ÖØ-öø-ÿ]+)*)$",
  caseSensitive: false,
);
