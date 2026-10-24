# clrfkntrckr OFF filter

The filter that turns the [Open Food Facts](https://world.openfoodfacts.org) (OFF) product export into the Dutch subset used by clrfkntrckr, a calorie tracker for the Netherlands (working name). The app's food data includes this subset, which makes it a derivative database of Open Food Facts; this repository publishes the method that produces it, as the Open Database License asks.

The rules are a snapshot of the app's, copied from its source on 2026-10-24. The app's repository is private; this copy is updated when its rules change.

## What it keeps

The filter reads every product in the export and keeps the ones that:

- are sold in the Netherlands: `countries_tags` contains `en:netherlands`;
- have a GTIN-8, -12, -13 or -14 barcode with a valid check digit, outside the in-store ranges 02 and 20–29, which shops assign themselves (weighed meat, cheese), so the same code means different products in different shops;
- have a name in any language (the main name, else the Dutch, the English or any other);
- aren't marked obsolete;
- declare energy, fat, carbohydrates and protein as sold, per 100 g or 100 ml, from the label.

Everything else is dropped. In particular:

- OFF's estimated values, which it computes from ingredients or category, are ignored. A product whose energy or macros exist only as estimates is dropped.
- Values per serving or for the prepared product don't count, and neither do products OFF marks as having no nutrition data. Products still in OFF's older nutrition schema are read from its per 100 g fields.

A few things are filled in or flagged rather than dropped:

- A pack sold in ml counts as per 100 ml, even when OFF says per 100 g. OFF's form defaults to 100 g, also for drinks.
- When the label gives only kcal or only kJ, the other is derived at 4.184 kJ/kcal and marked in `energy_derived`.
- Implausible values stay in. Each product lists the maths checks it fails in `failed_checks`; derived energy counts as not declared there.

The maths checks:

| Check | Fails when |
| --- | --- |
| `energyKcal`, `energyKj` | The declared energy is more than 10% (15% without fibre on the label), and at least 5 kcal or 20 kJ, away from the energy computed from fat, carbs, protein, fibre, polyols and alcohol with the EU conversion factors (Regulation (EU) No 1169/2011, Annex XIV). Alcohol comes from the ABV for products per 100 ml. |
| `energyRatio` | kJ divided by kcal falls outside 4.0–4.35, for products with both declared and at least 20 kcal. |
| `sugarsWithinCarbs` | Sugars are above carbohydrates. |
| `polyolsWithinCarbs` | Polyols are above carbohydrates. |
| `saturatesWithinFat` | Saturates are above fat. |
| `saltMatchesSodium` | Salt is more than 10% (at least 0.05 g) away from sodium × 2.5. |
| `totalWithin100g` | Fat, carbs, protein, fibre and salt add up to more than 101.5 g per 100 g; labels round values of 10 g or more to whole grams. |

In OFF's current nutrition schema a value counts only when the label input declares it; OFF's own estimates and filled-in values are left out. Values are otherwise copied as OFF gives them.

## Output

One JSON object per line, one line per kept product, in the order of the export:

| Field | Meaning |
| --- | --- |
| `barcode` | The barcode as OFF has it |
| `name`, `name_nl`, `name_en` | The name used, and the Dutch and English names when OFF has them |
| `brands`, `quantity` | As OFF has them |
| `categories` | OFF category tags, e.g. `en:biscuits` |
| `basis` | `100g` or `100ml` |
| `energy_kcal`, `energy_kj` | Energy per 100 g or 100 ml |
| `energy_derived` | `kcal` or `kj` when that value was derived, else null |
| `fat`, `saturates`, `carbs`, `sugars`, `polyols`, `fibre`, `protein`, `salt`, `sodium` | Grams per 100 g or 100 ml; null when not declared |
| `abv` | Alcohol by volume, in percent |
| `last_modified` | When the product last changed on OFF (UTC) |
| `failed_checks` | The maths checks the product fails |
| `kind` | `bread` for a loaf to slice, or a dry grain to weigh cooked: `whitePasta`, `wholewheatPasta`, `whiteRice`, `brownRice`, `couscous`, `quinoa`, `bulgur`; null otherwise. Taken from the categories: a bread under 350 kcal per 100 g, a grain per 100 g with at least 300 kcal per 100 g; a pasta counts as wholewheat from 6 g fibre and a rice as brown from 2.5 g when its categories don't say |
| `serving_size`, `serving_slices` | One serving in g (ml for a product per 100 ml): OFF's `serving_quantity` when it is above zero in g or ml, else the last weight or volume in `serving_size`, never one's number with the other's unit; and the slices it counts when its text names them ("2 sneetjes (70 g)"); for bread, a serving given as a weight alone under 100 g counts as one slice |

No images or other fields from the export are included.

## Running it

Needs the [Dart SDK](https://dart.dev/get-dart) 3.13.4 or later.

```sh
dart pub get
dart run bin/filter_off.dart \
  --input https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz \
  --output off-nl.jsonl.gz
```

- `--input` takes the export as a URL or a local file, compressed (`.jsonl.gz`) or not (`.jsonl`). Streaming the full export from OFF takes over an hour, so to run it more than once, download it first and pass the file. OFF publishes a new export daily; see [their data page](https://world.openfoodfacts.org/data).
- `--output` is where the kept products go; the file is gzipped when its name ends in `.gz`.
- The filter prints how many products it kept, how many it dropped for each reason and how many fail each maths check.

Tests: `dart test`. Analysis: `dart analyze`.

## Licences

The code is under the MIT licence; see [LICENSE](LICENSE).

The data is not. The output is a derivative of the Open Food Facts database, which is available under the [Open Database License (ODbL) v1.0](https://opendatacommons.org/licenses/odbl/1-0/); individual contents of the database are available under the [Database Contents License (DbCL) v1.0](https://opendatacommons.org/licenses/dbcl/1-0/). The output is therefore available under the ODbL v1.0 too. If you use or publish it, credit Open Food Facts with a link to [world.openfoodfacts.org](https://world.openfoodfacts.org) and keep it under the ODbL. See OFF's [terms of use](https://world.openfoodfacts.org/terms-of-use).

Data from [Open Food Facts](https://world.openfoodfacts.org), by its contributors, under the ODbL v1.0.

## Source

These rules are a snapshot of the clrfkntrckr app's food import, copied by hand when its rules change.
