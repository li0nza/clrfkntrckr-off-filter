/// OFF product JSON for tests of code that reads it, in OFF's current
/// schema as the export and the API (v3.5) give it.
library;

String unitOf(String nutrient) => switch (nutrient) {
  'energy-kcal' => 'kcal',
  'energy-kj' || 'energy' => 'kJ',
  'alcohol' => '% vol',
  _ => 'g',
};

/// OFF's current schema: input set 0 is the label, input set 1 OFF's
/// estimates, and the aggregated set what OFF shows. [filledIn] values appear
/// in the aggregated set although the label left them empty.
Map<String, Object?> nutrition(
  Map<String, num> declared, {
  String per = '100g',
  String preparation = 'as_sold',
  Map<String, num> filledIn = const {},
  Map<String, num> estimated = const {},
}) => {
  'aggregated_set': {
    'per': per,
    'preparation': preparation,
    'nutrients': {
      for (final MapEntry(:key, :value) in {...declared, ...filledIn}.entries)
        key: {
          'value': value,
          'unit': unitOf(key),
          'source': 'packaging',
          'source_index': 0,
        },
      for (final MapEntry(:key, :value) in estimated.entries)
        key: {
          'value': value,
          'unit': unitOf(key),
          'source': 'estimate',
          'source_index': 1,
        },
    },
  },
  'input_sets': [
    {
      'source': 'packaging',
      'per': per,
      'preparation': preparation,
      'nutrients': {
        for (final MapEntry(:key, :value) in declared.entries)
          key: {'value': value, 'unit': unitOf(key)},
        for (final key in filledIn.keys)
          key: {'value': null, 'unit': unitOf(key)},
      },
    },
    {
      'source': 'estimate',
      'per': '100g',
      'preparation': 'as_sold',
      'nutrients': {
        for (final MapEntry(:key, :value) in estimated.entries)
          key: {'value': value, 'unit': unitOf(key)},
      },
    },
  ],
};

const milk = {
  'energy-kcal': 46,
  'energy-kj': 194,
  'fat': 1.5,
  'saturated-fat': 1.0,
  'carbohydrates': 4.7,
  'sugars': 4.7,
  'proteins': 3.5,
  'salt': 0.1,
};

Map<String, Object?> product([Map<String, Object?> overrides = const {}]) => {
  'code': '8710605030938',
  'countries_tags': ['en:netherlands', 'en:belgium'],
  'product_name': 'Halfvolle melk',
  'product_name_nl': 'Halfvolle melk',
  'product_name_en': 'Semi-skimmed milk',
  'brands': 'Melkunie',
  'quantity': '1 l',
  'product_quantity_unit': 'ml',
  'categories_tags': ['en:dairies', 'en:milks'],
  'last_modified_t': 1788787606,
  'obsolete': '',
  'nutrition': nutrition(milk, per: '100ml'),
  'nutriments': <String, Object?>{},
  ...overrides,
};
