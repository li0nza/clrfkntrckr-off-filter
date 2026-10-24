import 'dart:convert';

import 'package:clrfkntrckr_off_filter/nutrition_checks.dart';
import 'package:clrfkntrckr_off_filter/off_rules.dart';
import 'package:clrfkntrckr_off_filter/src/off_export.dart';
import 'package:clrfkntrckr_off_filter/testing.dart';
import 'package:test/test.dart';

void main() {
  test('keeps the Dutch products and counts the rest by reason', () async {
    final lines = [
      jsonEncode(product()),
      jsonEncode(
        product({
          'code': '4012345678901',
          'countries_tags': ['en:germany'],
        }),
      ),
      jsonEncode(
        product({
          'countries_tags': ['en:belgium'],
          'origins_tags': ['en:netherlands'],
        }),
      ),
      jsonEncode(product({'code': '2012345678903'})),
      '{"countries_tags": ["en:netherlands"], "code": ',
      '',
    ];
    final export = Stream.value(utf8.encode(lines.join('\n')));

    final subset = await readOffSubset(export);

    expect(subset.products.map((p) => p.barcode), ['8710605030938']);
    expect(subset.scanned, 5);
    expect(subset.unreadable, 1);
    expect(subset.dropped[DropReason.notDutch], 2);
    expect(subset.dropped[DropReason.inStoreBarcode], 1);
  });

  test('counts the kept products failing each maths check', () async {
    final swapped = {...milk, 'energy-kcal': 194, 'energy-kj': 46};
    final tooMuchSugar = {...milk, 'sugars': 5.5};
    final lines = [
      jsonEncode(product()),
      jsonEncode(
        product({'code': '8711000000007', 'nutrition': nutrition(swapped)}),
      ),
      jsonEncode(
        product({
          'code': '8712000000004',
          'nutrition': nutrition(tooMuchSugar),
        }),
      ),
    ];
    final export = Stream.value(utf8.encode(lines.join('\n')));

    final subset = await readOffSubset(export);

    expect(subset.products, hasLength(3));
    expect(subset.failingProducts, 2);
    expect(subset.checkFailures, {
      Check.energyKcal: 1,
      Check.energyKj: 1,
      Check.energyRatio: 1,
      Check.sugarsWithinCarbs: 1,
      Check.polyolsWithinCarbs: 0,
      Check.saturatesWithinFat: 0,
      Check.saltMatchesSodium: 0,
      Check.totalWithin100g: 0,
    });
  });

  test('reads lines split across chunks', () async {
    final bytes = utf8.encode('${jsonEncode(product())}\n');
    final export = Stream.fromIterable([
      bytes.sublist(0, 10),
      bytes.sublist(10, 200),
      bytes.sublist(200),
    ]);

    final subset = await readOffSubset(export);

    expect(subset.products, hasLength(1));
  });
}
