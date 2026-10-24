import 'package:clrfkntrckr_off_filter/off_rules.dart';
import 'package:test/test.dart';

FoodKind? kind(
  List<String> categories, {
  double kcal = 351,
  double? fibre,
  Basis basis = Basis.per100g,
}) => offFoodKind(categories, basis, kcal, fibre: fibre);

void main() {
  group('bread', () {
    test('is a loaf in en:breads', () {
      expect(
        kind([
          'en:cereals-and-potatoes',
          'en:breads',
          'en:sliced-breads',
        ], kcal: 240),
        FoodKind.bread,
      );
      expect(kind(['en:breads', 'en:rye-breads'], kcal: 200), FoodKind.bread);
    });

    test('is not a roll, flatbread, crispbread, rusk or crumbs', () {
      for (final other in [
        'en:bread-rolls',
        'en:flatbreads',
        'en:wraps',
        'en:crispbreads',
        'en:rusks',
        'en:toasts',
        'en:bread-crumbs',
        'en:viennoiseries',
      ]) {
        expect(kind(['en:breads', other], kcal: 260), isNull, reason: other);
      }
    });

    test('is not dry enough to keep, as crispbread with sparse categories '
        'is', () {
      expect(kind(['en:breads'], kcal: 409), isNull);
    });
  });

  group('a dry grain', () {
    test('is pasta, white unless its categories or fibre say wholewheat', () {
      expect(
        kind(['en:pastas', 'en:dry-pastas', 'en:spaghetti'], fibre: 3),
        FoodKind.whitePasta,
      );
      expect(
        kind(['en:pastas', 'en:whole-durum-wheat-pasta']),
        FoodKind.wholewheatPasta,
      );
      expect(kind(['en:pastas'], fibre: 7.5), FoodKind.wholewheatPasta);
    });

    test('is rice, white unless its categories or fibre say brown', () {
      expect(
        kind(['en:rices', 'en:basmati-rices'], fibre: 1.3),
        FoodKind.whiteRice,
      );
      expect(kind(['en:rices', 'en:brown-rices']), FoodKind.brownRice);
      expect(
        kind(['en:rices', 'nl:Zilvervliesrijsten'], fibre: 1),
        FoodKind.brownRice,
      );
      expect(kind(['en:rices'], fibre: 3), FoodKind.brownRice);
    });

    test('is couscous, quinoa or bulgur', () {
      expect(
        kind(['en:durum-wheat-semolinas-for-couscous']),
        FoodKind.couscous,
      );
      expect(kind(['en:couscous']), FoodKind.couscous);
      expect(kind(['en:cereal-grains', 'en:quinoa']), FoodKind.quinoa);
      expect(kind(['en:wheat-groats', 'en:bulgur']), FoodKind.bulgur);
    });

    test('is none when cooked, fresh, per 100 ml or not the plain '
        'grain', () {
      expect(kind(['en:rices'], kcal: 146), isNull);
      expect(kind(['en:pastas', 'en:fresh-pasta'], kcal: 280), isNull);
      expect(kind(['en:rices'], basis: Basis.per100ml), isNull);
      for (final other in [
        'en:meals',
        'en:instant-noodles',
        'en:stuffed-pastas',
        'en:prepared-couscous',
        'en:puffed-cereal-cakes',
        'en:flours',
        'en:breakfast-cereals',
      ]) {
        expect(kind(['en:pastas', 'en:rices', other]), isNull, reason: other);
      }
      expect(kind(['en:pastas', 'en:rice-noodles']), isNull);
      expect(kind(['en:biscuits']), isNull);
    });
  });
}
