import 'dart:convert';

import 'package:clrfkntrckr_off_filter/nutrition_checks.dart';
import 'package:clrfkntrckr_off_filter/off_rules.dart';

const offExportUrl =
    'https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz';

class OffSubset {
  const OffSubset({
    required this.products,
    required this.scanned,
    required this.unreadable,
    required this.dropped,
    required this.checkFailures,
    required this.failingProducts,
  });

  final List<OffProduct> products;
  final int scanned;
  final int unreadable;
  final Map<DropReason, int> dropped;

  /// How many kept products fail each maths check.
  final Map<Check, int> checkFailures;

  /// Kept products that fail at least one maths check.
  final int failingProducts;
}

/// A cheap check on a raw export line; the parser checks `countries_tags`
/// itself.
bool mayBeDutch(String line) => line.contains('"en:netherlands"');

/// Filters the uncompressed OFF JSONL export, or the Dutch lines extracted
/// from it, down to the NL subset.
Future<OffSubset> readOffSubset(
  Stream<List<int>> export, {
  void Function(int scanned)? onProgress,
}) async {
  final products = <OffProduct>[];
  final dropped = {for (final reason in DropReason.values) reason: 0};
  final checkFailures = {for (final check in Check.values) check: 0};
  var failingProducts = 0;
  var scanned = 0;
  var unreadable = 0;

  final lines = utf8.decoder.bind(export).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.isEmpty) continue;
    scanned++;
    if (onProgress != null && scanned % 100000 == 0) onProgress(scanned);

    if (!mayBeDutch(line)) {
      dropped[DropReason.notDutch] = dropped[DropReason.notDutch]! + 1;
      continue;
    }
    final Object? json;
    try {
      json = jsonDecode(line);
    } on FormatException {
      unreadable++;
      continue;
    }
    if (json is! Map<String, Object?>) {
      unreadable++;
      continue;
    }
    switch (parseOffProduct(json)) {
      case Kept(:final product):
        products.add(product);
        final failed = failedChecks(product);
        if (failed.isNotEmpty) failingProducts++;
        for (final check in failed) {
          checkFailures[check] = checkFailures[check]! + 1;
        }
      case Dropped(:final reason):
        dropped[reason] = dropped[reason]! + 1;
    }
  }

  return OffSubset(
    products: products,
    scanned: scanned,
    unreadable: unreadable,
    dropped: dropped,
    checkFailures: checkFailures,
    failingProducts: failingProducts,
  );
}
