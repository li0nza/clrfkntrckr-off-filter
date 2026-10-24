import 'package:clrfkntrckr_off_filter/nutrition_checks.dart';
import 'package:clrfkntrckr_off_filter/off_rules.dart';
import 'package:clrfkntrckr_off_filter/testing.dart';
import 'package:test/test.dart';

import 'off_parser_test.dart' show kept;

Set<Check> failed(Map<String, num> declared, {String unit = 'g'}) =>
    failedChecks(
      kept(
        product({
          'product_quantity_unit': unit,
          'nutrition': nutrition(declared),
        }),
      ),
    );

void main() {
  test('a regular label passes', () {
    expect(failed(milk, unit: 'ml'), isEmpty);
  });

  group('beer', () {
    const beer = {
      'energy-kcal': 42,
      'energy-kj': 176,
      'fat': 0,
      'carbohydrates': 3.2,
      'sugars': 0,
      'proteins': 0.4,
    };

    test('passes with ABV', () {
      expect(failed({...beer, 'alcohol': 5.0}, unit: 'ml'), isEmpty);
    });

    test('fails both energy checks without ABV', () {
      expect(failed(beer, unit: 'ml'), {Check.energyKcal, Check.energyKj});
    });
  });

  group('sugar-free gum', () {
    const gum = {
      'energy-kcal': 153,
      'energy-kj': 637,
      'fat': 0,
      'carbohydrates': 63,
      'sugars': 0,
      'fiber': 0,
      'proteins': 0,
    };

    test('passes with polyols', () {
      expect(failed({...gum, 'polyols': 62}), isEmpty);
    });

    test('fails both energy checks without polyols', () {
      expect(failed(gum), {Check.energyKcal, Check.energyKj});
    });
  });

  test('a near-0 kcal diet drink passes', () {
    const dietCola = {
      'energy-kcal': 0.3,
      'energy-kj': 1.3,
      'fat': 0,
      'carbohydrates': 0,
      'sugars': 0,
      'proteins': 0,
      'salt': 0.02,
    };
    expect(failed(dietCola, unit: 'ml'), isEmpty);
  });

  group('pasta', () {
    Map<String, num> pasta({required num kcal, required num kj}) => {
      'energy-kcal': kcal,
      'energy-kj': kj,
      'fat': 2.0,
      'saturated-fat': 0.5,
      'carbohydrates': 70,
      'sugars': 3.5,
      'fiber': 3.0,
      'proteins': 13,
      'salt': 0.01,
    };

    test('passes with kcal and kJ in place', () {
      expect(failed(pasta(kcal: 359, kj: 1521)), isEmpty);
    });

    test('fails the ratio and both energy checks with kJ and kcal swapped', () {
      expect(failed(pasta(kcal: 1521, kj: 359)), {
        Check.energyKcal,
        Check.energyKj,
        Check.energyRatio,
      });
    });
  });

  group('crispbread', () {
    const crispbread = {
      'energy-kcal': 334,
      'energy-kj': 1408,
      'fat': 2,
      'carbohydrates': 60,
      'proteins': 10,
    };

    test('passes without fibre on the label', () {
      expect(failed(crispbread), isEmpty);
    });

    test('fails when the label declares 0 g fibre', () {
      expect(failed({...crispbread, 'fiber': 0}), {
        Check.energyKcal,
        Check.energyKj,
      });
    });
  });

  test('derived energy is not checked', () {
    final kcalTypo = {...milk, 'energy-kcal': 146}..remove('energy-kj');
    expect(failed(kcalTypo, unit: 'ml'), {Check.energyKcal});
  });
}
