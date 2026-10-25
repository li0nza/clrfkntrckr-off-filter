import 'package:clrfkntrckr_off_filter/off_rules.dart';
import 'package:clrfkntrckr_off_filter/src/off_product_row.dart';
import 'package:test/test.dart';

void main() {
  test('maps a product to its output row', () {
    final row = offProductRow(
      OffProduct(
        barcode: '8710605030938',
        name: 'Pils',
        categories: const ['en:beers'],
        basis: Basis.per100ml,
        energyKcal: 43,
        energyKj: 179.912,
        derivedEnergy: DerivedEnergy.kj,
        fat: 0,
        carbs: 3.3,
        protein: 0.4,
        abv: 5,
        lastModified: DateTime.utc(2026, 9, 7, 13, 26, 46),
      ),
    );

    expect(row, {
      'barcode': '8710605030938',
      'name': 'Pils',
      'name_nl': null,
      'name_en': null,
      'brands': null,
      'quantity': null,
      'categories': ['en:beers'],
      'basis': '100ml',
      'energy_kcal': 43,
      'energy_kj': 179.912,
      'energy_derived': 'kj',
      'fat': 0,
      'saturates': null,
      'carbs': 3.3,
      'sugars': null,
      'polyols': null,
      'fibre': null,
      'protein': 0.4,
      'salt': null,
      'sodium': null,
      'abv': 5,
      'last_modified': '2026-09-07T13:26:46.000Z',
      'failed_checks': <String>[],
      'kind': null,
      'serving_size': null,
      'serving_slices': null,
      'serving_word': null,
    });
  });

  test('stores the kind and the serving with its slices', () {
    final row = offProductRow(
      const OffProduct(
        barcode: '8710400000007',
        name: 'Volkoren casino',
        categories: ['en:breads', 'en:sliced-breads'],
        basis: Basis.per100g,
        energyKcal: 230,
        energyKj: 970,
        fat: 3,
        carbs: 38,
        fibre: 6,
        protein: 10,
        servingSize: 35,
        servingSlices: 1,
        servingWord: 'snee',
      ),
    );

    expect(row, containsPair('kind', 'bread'));
    expect(row, containsPair('serving_size', 35));
    expect(row, containsPair('serving_slices', 1));
    expect(row, containsPair('serving_word', 'snee'));
  });

  test('stores the maths checks a product fails by name', () {
    final row = offProductRow(
      const OffProduct(
        barcode: '8710605030938',
        name: 'Spaghetti',
        basis: Basis.per100g,
        energyKcal: 1521,
        energyKj: 359,
        fat: 2,
        carbs: 70,
        fibre: 3,
        protein: 13,
      ),
    );

    expect(row['failed_checks'], ['energyKcal', 'energyKj', 'energyRatio']);
  });
}
