import 'package:clrfkntrckr_off_filter/nutrition_checks.dart';
import 'package:clrfkntrckr_off_filter/off_rules.dart';
import 'package:clrfkntrckr_off_filter/testing.dart';
import 'package:test/test.dart';

OffProduct kept(Map<String, Object?> json) =>
    (parseOffProduct(json) as Kept).product;

DropReason? dropReason(Map<String, Object?> json) =>
    switch (parseOffProduct(json)) {
      Kept() => null,
      Dropped(:final reason) => reason,
    };

void main() {
  test('keeps a Dutch product with label energy and macros', () {
    final milk = kept(product());

    expect(milk.barcode, '8710605030938');
    expect(milk.sourceKey, 'off:8710605030938');
    expect(milk.name, 'Halfvolle melk');
    expect(milk.nameNl, 'Halfvolle melk');
    expect(milk.nameEn, 'Semi-skimmed milk');
    expect(milk.brands, 'Melkunie');
    expect(milk.quantity, '1 l');
    expect(milk.categories, ['en:dairies', 'en:milks']);
    expect(milk.basis, Basis.per100ml);
    expect(milk.energyKcal, 46);
    expect(milk.energyKj, 194);
    expect(milk.derivedEnergy, isNull);
    expect(milk.fat, 1.5);
    expect(milk.saturates, 1.0);
    expect(milk.carbs, 4.7);
    expect(milk.sugars, 4.7);
    expect(milk.protein, 3.5);
    expect(milk.salt, 0.1);
    expect(milk.fibre, isNull);
    expect(milk.abv, isNull);
    expect(milk.lastModified, DateTime.utc(2026, 9, 7, 13, 26, 46));
  });

  test('reads per 100 g from the label set', () {
    final json = product({
      'product_quantity_unit': 'g',
      'nutrition': nutrition(milk),
    });
    expect(kept(json).basis, Basis.per100g);
  });

  test('reads per 100 g as per 100 ml when the pack is in ml', () {
    expect(kept(product({'nutrition': nutrition(milk)})).basis, Basis.per100ml);
  });

  group('drops', () {
    test('products not sold in the Netherlands', () {
      expect(
        dropReason(
          product({
            'countries_tags': ['en:belgium'],
            'origins_tags': ['en:netherlands'],
          }),
        ),
        DropReason.notDutch,
      );
      expect(
        dropReason(product({'countries_tags': null})),
        DropReason.notDutch,
      );
    });

    test('barcodes that are missing or fail the check digit', () {
      expect(
        dropReason(product({'code': '8710605030939'})),
        DropReason.invalidBarcode,
      );
      expect(dropReason(product({'code': null})), DropReason.invalidBarcode);
    });

    test('in-store barcodes', () {
      expect(
        dropReason(product({'code': '2012345678903'})),
        DropReason.inStoreBarcode,
      );
    });

    test('products without a name in any language', () {
      expect(
        dropReason(
          product({
            'product_name': ' ',
            'product_name_nl': '',
            'product_name_en': null,
          }),
        ),
        DropReason.noName,
      );
    });

    test('obsolete products', () {
      expect(dropReason(product({'obsolete': 'on'})), DropReason.obsolete);
    });

    test('products without as-sold values per 100 g or 100 ml', () {
      expect(dropReason(product({'nutrition': null})), DropReason.noLabel);
      expect(
        dropReason(
          product({'nutrition': nutrition(milk, preparation: 'prepared')}),
        ),
        DropReason.noLabel,
      );
      expect(
        dropReason(product({'nutrition': nutrition(milk, per: 'serving')})),
        DropReason.noLabel,
      );
      expect(
        dropReason(product({'no_nutrition_data': 'on'})),
        DropReason.noLabel,
      );
    });

    test('products without energy', () {
      final noEnergy = {...milk}
        ..remove('energy-kcal')
        ..remove('energy-kj');
      expect(
        dropReason(product({'nutrition': nutrition(noEnergy)})),
        DropReason.noEnergy,
      );
    });

    test('products missing fat, carbs or protein', () {
      final noProtein = {...milk}..remove('proteins');
      expect(
        dropReason(product({'nutrition': nutrition(noProtein)})),
        DropReason.noMacros,
      );
    });
  });

  group('names', () {
    test('fall back to the Dutch, then the English name', () {
      expect(kept(product({'product_name': null})).name, 'Halfvolle melk');
      expect(
        kept(product({'product_name': null, 'product_name_nl': null})).name,
        'Semi-skimmed milk',
      );
    });

    test('fall back to a name in any other language', () {
      final json = product({
        'product_name': null,
        'product_name_nl': null,
        'product_name_en': null,
        'product_name_de': 'Fettarme Milch',
      });
      expect(kept(json).name, 'Fettarme Milch');
    });
  });

  group('estimates', () {
    test('never stand in for label values', () {
      final json = product({
        'nutrition': nutrition(
          {'energy-kcal': 46, 'energy-kj': 194},
          estimated: {'fat': 1.4, 'carbohydrates': 4.8, 'proteins': 3.4},
        ),
      });
      expect(dropReason(json), DropReason.noMacros);
    });

    test('of alcohol are left out', () {
      final json = product({
        'nutrition': nutrition(milk, estimated: {'alcohol': 0}),
      });
      expect(kept(json).abv, isNull);
    });
  });

  group('energy', () {
    test('derives kJ when only kcal is on the label', () {
      final kcalOnly = {...milk}..remove('energy-kj');
      final json = product({
        'nutrition': nutrition(kcalOnly, filledIn: {'energy-kj': 190}),
      });
      final parsed = kept(json);
      expect(parsed.energyKcal, 46);
      expect(parsed.energyKj, closeTo(192.46, 0.01));
      expect(parsed.derivedEnergy, DerivedEnergy.kj);
    });

    test('derives kcal when only kJ is on the label', () {
      final kjOnly = {...milk}..remove('energy-kcal');
      final parsed = kept(product({'nutrition': nutrition(kjOnly)}));
      expect(parsed.energyKj, 194);
      expect(parsed.energyKcal, closeTo(46.37, 0.01));
      expect(parsed.derivedEnergy, DerivedEnergy.kcal);
    });

    for (final scanned in [false, true]) {
      for (final legacy in [false, true]) {
        test(
          'repairs kcal from kJ for the cheese (${legacy ? 'legacy' : 'current'}, '
          '${scanned ? 'scan' : 'import'})',
          () {
            const cheese = {
              'energy-kcal': 1060.31636,
              'energy-kj': 1464,
              'fat': 29,
              'saturated-fat': 20,
              'carbohydrates': 0,
              'proteins': 23,
              'salt': 1.9,
            };
            final json = product({
              'code': '8718907844994',
              'product_name': 'Goudse Jonge Kaas 48+',
              'brands': 'De Zaanse Hoeve',
              'product_quantity_unit': 'g',
              'nutrition': legacy ? null : nutrition(cheese),
              'nutriments': {
                for (final entry in cheese.entries)
                  '${entry.key}_100g': entry.value,
              },
            });
            final parsed =
                (parseOffProduct(json, scanned: scanned) as Kept).product;

            expect(parsed.energyKj, 1464);
            expect(parsed.energyKcal, 1464 / 4.184);
            expect(parsed.derivedEnergy, DerivedEnergy.kcal);
            expect(failedChecks(parsed), isEmpty);
          },
        );
      }
    }

    test('repairs kJ from kcal and keeps unrelated failed checks', () {
      final parsed = kept(
        product({
          'nutrition': nutrition({...milk, 'energy-kj': 900, 'sugars': 6}),
        }),
      );

      expect(parsed.energyKcal, 46);
      expect(parsed.energyKj, 46 * 4.184);
      expect(parsed.derivedEnergy, DerivedEnergy.kj);
      expect(failedChecks(parsed), {Check.sugarsWithinCarbs});
    });

    test(
      'treats repaired energy as undeclared even outside its macro range',
      () {
        final parsed = kept(
          product({
            'product_quantity_unit': 'g',
            'nutrition': nutrition({
              'energy-kcal': 1800,
              'energy-kj': 3330,
              'fat': 100,
              'carbohydrates': 0,
              'proteins': 0,
              'fiber': 0,
            }),
          }),
        );

        expect(parsed.energyKj, 3330);
        expect(parsed.energyKcal, 3330 / 4.184);
        expect(parsed.derivedEnergy, DerivedEnergy.kcal);
        expect(failedChecks(parsed), isEmpty);
      },
    );

    for (final scenario in [
      (
        name: 'leaves both energies off the macros as published',
        kcal: 146.0,
        kj: 294.0,
        failed: {Check.energyKcal, Check.energyKj, Check.energyRatio},
      ),
      (
        name: 'leaves a ratio mismatch when both energies fit the macros',
        kcal: 50.0,
        kj: 180.0,
        failed: {Check.energyRatio},
      ),
      (
        name: 'leaves kcal below 20 when the ratio check is skipped',
        kcal: 10.0,
        kj: 194.0,
        failed: {Check.energyKcal},
      ),
      (
        name: 'leaves an energy mismatch when the ratio passes',
        kcal: 53.3,
        kj: 223.0,
        failed: {Check.energyKcal},
      ),
    ]) {
      test(scenario.name, () {
        final parsed = kept(
          product({
            'nutrition': nutrition({
              ...milk,
              'energy-kcal': scenario.kcal,
              'energy-kj': scenario.kj,
            }),
          }),
        );

        expect(parsed.energyKcal, scenario.kcal);
        expect(parsed.energyKj, scenario.kj);
        expect(parsed.derivedEnergy, isNull);
        expect(failedChecks(parsed), scenario.failed);
      });
    }

    for (final scenario in [
      (name: 'fibre', nutrients: {'fiber': 20}, kcal: 86, kj: 355),
      (name: 'polyols', nutrients: {'polyols': 4.7}, kcal: 35, kj: 140),
      (name: 'ABV', nutrients: {'alcohol': 10}, kcal: 102, kj: 424),
    ]) {
      test('counts ${scenario.name} when repairing energy', () {
        final parsed = kept(
          product({
            'nutrition': nutrition({
              ...milk,
              ...scenario.nutrients,
              'energy-kcal': scenario.kcal * 3,
              'energy-kj': scenario.kj,
            }, per: '100ml'),
          }),
        );

        expect(parsed.energyKj, scenario.kj);
        expect(parsed.energyKcal, scenario.kj / 4.184);
        expect(parsed.derivedEnergy, DerivedEnergy.kcal);
        expect(failedChecks(parsed), isEmpty);
      });
    }

    test('reads a legacy energy value as kJ', () {
      final legacy = {...milk}
        ..remove('energy-kcal')
        ..remove('energy-kj')
        ..['energy'] = 194;
      final parsed = kept(product({'nutrition': nutrition(legacy)}));
      expect(parsed.energyKj, 194);
      expect(parsed.derivedEnergy, DerivedEnergy.kcal);
    });
  });

  test('stores declared alcohol as ABV', () {
    final beer = {
      'energy-kcal': 43,
      'energy-kj': 180,
      'fat': 0,
      'carbohydrates': 3.3,
      'proteins': 0.4,
      'alcohol': 5.0,
    };
    final json = product({'nutrition': nutrition(beer, per: '100ml')});
    expect(kept(json).abv, 5.0);
  });

  test('reads the legacy nutriments schema', () {
    final json = product({
      'nutrition': null,
      'nutriments': {
        'energy-kcal_100g': 46,
        'energy-kj_100g': '194',
        'energy_100g': 194,
        'fat_100g': 1.5,
        'carbohydrates_100g': 4.7,
        'proteins_100g': 3.5,
        'fruits-vegetables-nuts-estimate-from-ingredients_100g': 0,
      },
    });
    final milk = kept(json);
    expect(milk.basis, Basis.per100ml);
    expect(milk.energyKcal, 46);
    expect(milk.energyKj, 194);
    expect(milk.fat, 1.5);
    expect(milk.derivedEnergy, isNull);
  });

  group('a scanned product', () {
    DropReason? scannedDrop(Map<String, Object?> json) =>
        switch (parseOffProduct(json, scanned: true)) {
          Kept() => null,
          Dropped(:final reason) => reason,
        };

    test('counts whatever countries OFF lists', () {
      expect(
        scannedDrop(
          product({
            'countries_tags': ['en:germany'],
          }),
        ),
        isNull,
      );
      expect(scannedDrop(product({'countries_tags': null})), isNull);
    });

    test('counts when OFF marks it obsolete', () {
      expect(scannedDrop(product({'obsolete': 'on'})), isNull);
    });

    test('still needs label energy and macros', () {
      final noProtein = {...milk}..remove('proteins');
      expect(
        scannedDrop(product({'nutrition': nutrition(noProtein)})),
        DropReason.noMacros,
      );
      expect(
        scannedDrop(product({'nutrition': nutrition(milk, per: 'serving')})),
        DropReason.noLabel,
      );
    });
  });

  group('kind and serving', () {
    test('are none for a product without them', () {
      final milk = kept(product());

      expect(milk.kind, isNull);
      expect(milk.servingSize, isNull);
      expect(milk.servingSlices, isNull);
    });

    test('tag a loaf of bread and read its serving as a slice', () {
      final bread = kept(
        product({
          'product_quantity_unit': 'g',
          'categories_tags': ['en:breads', 'en:sliced-breads'],
          'nutrition': nutrition({
            'energy-kcal': 240,
            'energy-kj': 1010,
            'fat': 3,
            'carbohydrates': 40,
            'proteins': 10,
          }),
          'serving_size': '35 g',
          'serving_quantity': 35,
          'serving_quantity_unit': 'g',
        }),
      );

      expect(bread.kind, FoodKind.bread);
      expect(bread.servingSize, 35);
      expect(bread.servingSlices, 1);
      expect(bread.servingWord, isNull);
    });

    test('tag dry pasta by its categories and fibre', () {
      final pasta = kept(
        product({
          'product_quantity_unit': 'g',
          'categories_tags': ['en:pastas', 'en:dry-pastas'],
          'nutrition': nutrition({
            'energy-kcal': 351,
            'energy-kj': 1490,
            'fat': 1.5,
            'carbohydrates': 70,
            'fiber': 7,
            'proteins': 13,
          }),
          'serving_size': '1 portion (80 g)',
        }),
      );

      expect(pasta.kind, FoodKind.wholewheatPasta);
      expect(pasta.servingSize, 80);
      expect(pasta.servingSlices, isNull);
    });
  });

  group('drink', () {
    bool drink(List<String> categories) =>
        kept(product({'categories_tags': categories})).drink;

    test('is a beverage that is not dairy or a milk substitute', () {
      expect(drink(['en:beverages', 'en:sodas']), isTrue);
      expect(drink(['en:beverages', 'en:dairies', 'en:milks']), isFalse);
      expect(drink(['en:beverages', 'en:milk-substitutes']), isFalse);
      expect(drink(['en:biscuits']), isFalse);
    });
  });
}
