import 'package:clrfkntrckr_off_filter/nutrition_checks.dart';
import 'package:test/test.dart';

Amount g(double value) => Amount.exact(value);

CheckResult result(NutritionLabel label, Check check) =>
    checkLabel(label).singleWhere((r) => r.check == check);

Outcome outcome(NutritionLabel label, Check check) =>
    result(label, check).outcome;

void main() {
  group('a regular label', () {
    final yoghurt = NutritionLabel(
      basis: Basis.per100g,
      energyKcal: g(60),
      energyKj: g(251),
      fat: g(3.0),
      saturates: g(2.0),
      carbs: g(4.5),
      sugars: g(4.5),
      fibre: g(0),
      protein: g(3.8),
      salt: g(0.12),
    );

    test('passes every check that applies', () {
      final results = {for (final r in checkLabel(yoghurt)) r.check: r.outcome};
      expect(results, {
        Check.energyKcal: Outcome.pass,
        Check.energyKj: Outcome.pass,
        Check.energyRatio: Outcome.pass,
        Check.sugarsWithinCarbs: Outcome.pass,
        Check.polyolsWithinCarbs: Outcome.skipped,
        Check.saturatesWithinFat: Outcome.pass,
        Check.saltMatchesSodium: Outcome.skipped,
        Check.totalWithin100g: Outcome.pass,
      });
    });
  });

  group('beer with ABV', () {
    NutritionLabel beer({double? abv}) => NutritionLabel(
      basis: Basis.per100ml,
      energyKcal: g(42),
      energyKj: g(176),
      fat: g(0),
      carbs: g(3.2),
      sugars: g(0),
      protein: g(0.4),
      abv: abv,
    );

    test('passes when ABV is entered', () {
      expect(outcome(beer(abv: 5), Check.energyKcal), Outcome.pass);
      expect(outcome(beer(abv: 5), Check.energyKj), Outcome.pass);
    });

    test('fails without ABV', () {
      final r = result(beer(), Check.energyKcal);
      expect(r.outcome, Outcome.fail);
      expect(r.fields, containsAll([Field.energyKcal, Field.carbs]));
    });

    test('skips the 100 g total for per 100 ml labels', () {
      expect(outcome(beer(abv: 5), Check.totalWithin100g), Outcome.skipped);
    });
  });

  group('polyols', () {
    NutritionLabel gum({Amount? polyols}) => NutritionLabel(
      basis: Basis.per100g,
      energyKcal: g(153),
      energyKj: g(637),
      fat: g(0),
      carbs: g(63),
      sugars: g(0),
      polyols: polyols,
      fibre: g(0),
      protein: g(0),
    );

    test('sugar-free gum passes with polyols at 2.4 kcal/g', () {
      expect(outcome(gum(polyols: g(62)), Check.energyKcal), Outcome.pass);
      expect(outcome(gum(polyols: g(62)), Check.energyKj), Outcome.pass);
    });

    test('sugar-free gum fails when polyols are missing', () {
      expect(outcome(gum(), Check.energyKcal), Outcome.fail);
    });

    test('erythritol counts as 0 kcal', () {
      final erythritol = NutritionLabel(
        basis: Basis.per100g,
        energyKcal: g(0),
        energyKj: g(0),
        fat: g(0),
        carbs: g(100),
        polyols: g(100),
        protein: g(0),
      );
      expect(outcome(erythritol, Check.energyKcal), Outcome.pass);
      expect(outcome(erythritol, Check.energyKj), Outcome.pass);
    });

    test('polyols above carbs fail', () {
      expect(
        outcome(gum(polyols: g(70)), Check.polyolsWithinCarbs),
        Outcome.fail,
      );
    });
  });

  group('near-zero energy', () {
    final dietCola = NutritionLabel(
      basis: Basis.per100ml,
      energyKcal: g(0.3),
      energyKj: g(1.3),
      fat: g(0),
      carbs: g(0),
      sugars: g(0),
      protein: g(0),
      salt: g(0.02),
    );

    test('passes on the absolute floor', () {
      expect(outcome(dietCola, Check.energyKcal), Outcome.pass);
      expect(outcome(dietCola, Check.energyKj), Outcome.pass);
    });

    test('skips the kJ/kcal ratio below 20 kcal', () {
      expect(outcome(dietCola, Check.energyRatio), Outcome.skipped);
    });
  });

  group('swapped kJ and kcal', () {
    NutritionLabel pasta({required double kcal, required double kj}) =>
        NutritionLabel(
          basis: Basis.per100g,
          energyKcal: g(kcal),
          energyKj: g(kj),
          fat: g(2.0),
          saturates: g(0.5),
          carbs: g(70),
          sugars: g(3.5),
          fibre: g(3.0),
          protein: g(13),
          salt: g(0.01),
        );

    test('the correct label passes', () {
      final correct = pasta(kcal: 359, kj: 1521);
      expect(outcome(correct, Check.energyKcal), Outcome.pass);
      expect(outcome(correct, Check.energyKj), Outcome.pass);
      expect(outcome(correct, Check.energyRatio), Outcome.pass);
    });

    test('swapped values fail the ratio and both energy checks', () {
      final swapped = pasta(kcal: 1521, kj: 359);
      final ratio = result(swapped, Check.energyRatio);
      expect(ratio.outcome, Outcome.fail);
      expect(ratio.fields, {Field.energyKcal, Field.energyKj});
      expect(outcome(swapped, Check.energyKcal), Outcome.fail);
      expect(outcome(swapped, Check.energyKj), Outcome.fail);
    });
  });

  group('fibre', () {
    NutritionLabel crispbread({Amount? fibre}) => NutritionLabel(
      basis: Basis.per100g,
      energyKcal: g(334),
      energyKj: g(1408),
      fat: g(2),
      carbs: g(60),
      fibre: fibre,
      protein: g(10),
    );

    test('an undeclared fibre value widens the tolerance to 15%', () {
      expect(outcome(crispbread(), Check.energyKcal), Outcome.pass);
      expect(outcome(crispbread(), Check.energyKj), Outcome.pass);
    });

    test('a declared fibre value keeps the tolerance at 10%', () {
      expect(outcome(crispbread(fibre: g(0)), Check.energyKcal), Outcome.fail);
      expect(outcome(crispbread(fibre: g(18)), Check.energyKcal), Outcome.pass);
    });
  });

  group('bounded values', () {
    test('"<0,5 g" and "sporen" count as a range', () {
      final label = NutritionLabel(
        basis: Basis.per100g,
        energyKcal: g(50),
        energyKj: g(210),
        fat: const Amount.below(0.5),
        carbs: g(10),
        sugars: const Amount.traces(),
        protein: g(2),
      );
      expect(outcome(label, Check.energyKcal), Outcome.pass);
      expect(outcome(label, Check.sugarsWithinCarbs), Outcome.pass);
    });

    test(
      'energy checks skip when macros are missing; the ratio still runs',
      () {
        final wine = NutritionLabel(
          basis: Basis.per100ml,
          energyKcal: g(83),
          energyKj: g(347),
        );
        expect(outcome(wine, Check.energyKcal), Outcome.skipped);
        expect(outcome(wine, Check.energyRatio), Outcome.pass);
      },
    );
  });

  group('parts and totals', () {
    test('sugars above carbs fail', () {
      final label = NutritionLabel(
        basis: Basis.per100g,
        carbs: g(10),
        sugars: g(12),
      );
      final r = result(label, Check.sugarsWithinCarbs);
      expect(r.outcome, Outcome.fail);
      expect(r.fields, {Field.sugars, Field.carbs});
    });

    test('saturates above fat fail', () {
      final label = NutritionLabel(
        basis: Basis.per100g,
        fat: g(3),
        saturates: g(4),
      );
      expect(outcome(label, Check.saturatesWithinFat), Outcome.fail);
    });

    test('salt must be sodium × 2.5', () {
      NutritionLabel label(double sodium) =>
          NutritionLabel(basis: Basis.per100g, salt: g(1.0), sodium: g(sodium));
      expect(outcome(label(0.4), Check.saltMatchesSodium), Outcome.pass);
      expect(outcome(label(1.0), Check.saltMatchesSodium), Outcome.fail);
    });

    test('up to 1.5 g over 100 g passes as rounding', () {
      NutritionLabel label(double salt) => NutritionLabel(
        basis: Basis.per100g,
        fat: g(1),
        carbs: g(89),
        fibre: g(1.2),
        protein: g(10),
        salt: g(salt),
      );
      expect(outcome(label(0.2), Check.totalWithin100g), Outcome.pass);
      expect(outcome(label(0.5), Check.totalWithin100g), Outcome.fail);
    });

    test('more than 100 g per 100 g fails', () {
      final label = NutritionLabel(
        basis: Basis.per100g,
        fat: g(60),
        carbs: g(50),
      );
      final r = result(label, Check.totalWithin100g);
      expect(r.outcome, Outcome.fail);
      expect(r.fields, {Field.fat, Field.carbs});
    });
  });
}
