import 'package:clrfkntrckr_off_filter/nutrition_checks.dart' show Basis;

/// What the app offers a food extra ways to log for: slices for bread,
/// "Weighed cooked" for a dry grain. Stored by name.
enum FoodKind {
  bread,
  whitePasta,
  wholewheatPasta,
  whiteRice,
  brownRice,
  couscous,
  quinoa,
  bulgur,
}

/// Below this a grain isn't dry: cooked, fresh or a ready meal. Dry pasta,
/// rice, couscous, quinoa and bulgur have 330 to 370 kcal per 100 g.
const dryGrainMinKcal = 300.0;

/// From this a "bread" is a dry one: crispbread, rusk, breadcrumbs. Loaves,
/// seeded ones too, stay under it.
const breadMaxKcal = 350.0;

/// Fibre per 100 g from which a dry pasta counts as wholewheat and a dry
/// rice as brown when its categories don't say: NEVO gives 3.0 g for white
/// pasta and 7.5 g for wholewheat, 1.3 g for white rice and 3.0 g for brown.
const wholewheatPastaMinFibre = 6.0;
const brownRiceMinFibre = 2.5;

/// The kind of an OFF product from its categories: a loaf of bread under
/// [breadMaxKcal], or a dry grain sold per 100 g with at least
/// [dryGrainMinKcal]. Rolls, flatbreads, crackers, prepared dishes, snacks,
/// flours, flakes and puffed grains are none, as far as their categories
/// say.
FoodKind? offFoodKind(
  List<String> categories,
  Basis basis,
  double energyKcal, {
  double? fibre,
}) {
  final tags = {for (final tag in categories) tag.toLowerCase()};
  bool any(Set<String> some) => tags.any(some.contains);
  if (tags.contains('en:breads')) {
    return any(_notLoaves) || energyKcal >= breadMaxKcal
        ? null
        : FoodKind.bread;
  }
  if (basis != Basis.per100g ||
      energyKcal < dryGrainMinKcal ||
      any(_notPlainGrains)) {
    return null;
  }
  if (tags.contains('en:pastas')) {
    if (any(_notWheatPastas)) return null;
    return any(_wholewheatPastas) || (fibre ?? 0) >= wholewheatPastaMinFibre
        ? FoodKind.wholewheatPasta
        : FoodKind.whitePasta;
  }
  if (tags.contains('en:rices')) {
    return any(_wholegrainRices) || (fibre ?? 0) >= brownRiceMinFibre
        ? FoodKind.brownRice
        : FoodKind.whiteRice;
  }
  if (any(_couscous)) return FoodKind.couscous;
  if (tags.contains('en:quinoa')) return FoodKind.quinoa;
  if (tags.contains('en:bulgur')) return FoodKind.bulgur;
  return null;
}

/// Breads that aren't a loaf to slice.
const _notLoaves = {
  'en:bread-rolls',
  'en:hamburger-buns',
  'en:hot-dog-buns',
  'en:bagel-breads',
  'en:flatbreads',
  'en:wraps',
  'en:crispbreads',
  'en:rusks',
  'en:toasts',
  'en:breadsticks',
  'en:biscuits-and-crackers',
  'en:crackers-appetizers',
  'en:croutons',
  'en:bread-crumbs',
  'en:viennoiseries',
  'en:sweet-pastries-and-pies',
  'en:biscuits-and-cakes',
  'en:sandwiches',
  'en:meals',
  'en:snacks',
};

/// Grain products that aren't the plain grain weighed into a pan.
const _notPlainGrains = {
  'en:meals',
  'en:dried-meals',
  'en:meal-kits',
  'en:pasta-dishes',
  'en:rice-dishes',
  'en:risottos',
  'en:savory-semolina-dishes',
  'en:prepared-couscous',
  'en:prepared-salads',
  'en:soups',
  'en:dehydrated-soups',
  'en:instant-noodles',
  'en:instant-noodle-soups',
  'en:fresh-pasta',
  'en:stuffed-pastas',
  'en:gnocchi',
  'en:lasagna-sheets',
  'en:breakfast-cereals',
  'en:cereal-flakes',
  'en:puffed-cereals',
  'en:puffed-cereal-cakes',
  'en:puffed-rice-cakes',
  'en:flours',
  'en:snacks',
  'en:sauces',
  'en:frozen-foods',
  'en:microwave-meals',
  'en:rice-in-pots',
};

/// Pastas that cook unlike wheat pasta.
const _notWheatPastas = {
  'en:rice-noodles',
  'en:dried-rice-noodles',
  'en:rice-vermicelli',
  'en:legume-pastas',
  'en:lentil-pasta',
  'en:chickpea-pasta',
};

const _wholewheatPastas = {
  'en:whole-durum-wheat-pasta',
  'en:whole-or-semi-whole-durum-wheat-pasta',
  'en:whole-durm-wheat-spaghetti',
  'en:wholemeal-pastas',
  'en:whole-wheat-noodles',
};

const _wholegrainRices = {
  'en:brown-rices',
  'en:brown-basmati-rices',
  'en:black-rices',
  'en:red-rices',
  'en:wild-rice',
  'nl:zilvervliesrijst',
  'nl:zilvervliesrijsten',
};

const _couscous = {'en:couscous', 'en:durum-wheat-semolinas-for-couscous'};
