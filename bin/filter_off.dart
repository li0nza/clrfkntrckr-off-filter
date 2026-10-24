import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:clrfkntrckr_off_filter/nutrition_checks.dart' show Check;
import 'package:clrfkntrckr_off_filter/off_rules.dart';
import 'package:clrfkntrckr_off_filter/src/off_export.dart';
import 'package:clrfkntrckr_off_filter/src/off_product_row.dart';

const _userAgent = 'clrfkntrckr-off-filter/0.1';

typedef _Export = ({Stream<List<int>> bytes, DateTime? exportDate});

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'input',
      valueHelp: 'file or URL',
      help:
          'The OFF JSONL export (.jsonl.gz or .jsonl), as a local file or a '
          'URL such as $offExportUrl. A file\'s modification time is taken as '
          'the export date.',
    )
    ..addOption(
      'output',
      valueHelp: 'file',
      help:
          'Where to write the kept products, one JSON object per line; '
          'gzipped when the name ends in .gz.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    _usageError(e.message, parser);
    return;
  }
  if (args.flag('help')) {
    print(
      'Filters the Open Food Facts export down to the Dutch products the '
      'clrfkntrckr app serves.\n\n'
      '${parser.usage}',
    );
    return;
  }
  final input = args.option('input');
  final output = args.option('output');
  if (input == null || output == null) {
    _usageError('--input and --output are required.', parser);
    return;
  }

  try {
    final export = _isUrl(input)
        ? await _download(Uri.parse(input))
        : await _openFile(input);
    final subset = await readOffSubset(export.bytes, onProgress: _progress);
    if (subset.scanned >= 100000) stderr.writeln();
    _printSummary(subset, export.exportDate);
    await _write(subset.products, output);
    print('Wrote ${_count(subset.products.length)} products to $output.');
  } on IOException catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  } on FormatException catch (e) {
    stderr.writeln('$input is not a readable export: ${e.message}');
    exitCode = 1;
  }
}

void _usageError(String message, ArgParser parser) {
  stderr
    ..writeln(message)
    ..writeln(parser.usage);
  exitCode = 64;
}

bool _isUrl(String input) =>
    input.startsWith('https://') || input.startsWith('http://');

Future<_Export> _openFile(String path) async {
  final file = File(path);
  final bytes = file.openRead();
  return (
    bytes: path.endsWith('.gz') ? bytes.transform(gzip.decoder) : bytes,
    exportDate: (await file.lastModified()).toUtc(),
  );
}

Future<_Export> _download(Uri uri) async {
  final client = HttpClient()..userAgent = _userAgent;
  try {
    final response = await (await client.getUrl(uri)).close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    final lastModified = response.headers.value(HttpHeaders.lastModifiedHeader);
    final bytes = _complete(response, uri);
    return (
      bytes: uri.path.endsWith('.gz') ? bytes.transform(gzip.decoder) : bytes,
      exportDate: lastModified == null ? null : HttpDate.parse(lastModified),
    );
  } finally {
    client.close();
  }
}

/// gzip.decoder ends quietly on a truncated stream, so check the length.
Stream<List<int>> _complete(HttpClientResponse response, Uri uri) {
  final expected = response.contentLength;
  var received = 0;
  return response.transform(
    StreamTransformer.fromHandlers(
      handleData: (chunk, sink) {
        received += chunk.length;
        sink.add(chunk);
      },
      handleDone: (sink) {
        if (expected >= 0 && received != expected) {
          sink.addError(
            HttpException(
              'Download ended after $received of $expected bytes',
              uri: uri,
            ),
          );
        }
        sink.close();
      },
    ),
  );
}

Future<void> _write(List<OffProduct> products, String path) {
  final lines = Stream.fromIterable(
    products.map((product) => '${jsonEncode(offProductRow(product))}\n'),
  ).transform(utf8.encoder);
  return (path.endsWith('.gz') ? lines.transform(gzip.encoder) : lines).pipe(
    File(path).openWrite(),
  );
}

void _progress(int scanned) => stderr.write('\rScanned ${_count(scanned)}');

void _printSummary(OffSubset subset, DateTime? exportDate) {
  final dropped = [
    for (final reason in DropReason.values)
      if (reason != DropReason.notDutch && subset.dropped[reason]! > 0)
        '${_reason(reason)} ${_count(subset.dropped[reason]!)}',
  ];
  final dutch =
      subset.scanned - subset.dropped[DropReason.notDutch]! - subset.unreadable;
  final export = exportDate == null
      ? 'Export'
      : 'Export of ${_date(exportDate)}';
  print(
    '$export: '
    'read ${_count(subset.scanned)} lines, Dutch ${_count(dutch)}, '
    'kept ${_count(subset.products.length)}.',
  );
  if (dropped.isNotEmpty) print('Dropped: ${dropped.join(', ')}.');
  final failed = [
    for (final check in Check.values)
      '${_check(check)} ${_count(subset.checkFailures[check]!)}',
  ];
  print(
    'Failing maths checks: ${_count(subset.failingProducts)} products. '
    'Per check: ${failed.join(', ')}.',
  );
  if (subset.unreadable > 0) {
    print('Unreadable lines: ${_count(subset.unreadable)}.');
  }
}

String _reason(DropReason reason) => switch (reason) {
  DropReason.notDutch => 'not Dutch',
  DropReason.invalidBarcode => 'invalid barcode',
  DropReason.inStoreBarcode => 'in-store barcode',
  DropReason.noName => 'no name',
  DropReason.obsolete => 'obsolete',
  DropReason.noLabel => 'no label values',
  DropReason.noEnergy => 'no energy',
  DropReason.noMacros => 'no fat, carbs or protein',
};

String _check(Check check) => switch (check) {
  Check.energyKcal => 'kcal',
  Check.energyKj => 'kJ',
  Check.energyRatio => 'kJ/kcal ratio',
  Check.sugarsWithinCarbs => 'sugars above carbs',
  Check.polyolsWithinCarbs => 'polyols above carbs',
  Check.saturatesWithinFat => 'saturates above fat',
  Check.saltMatchesSodium => 'salt vs sodium',
  Check.totalWithin100g => 'over 100 g per 100 g',
};

String _count(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

String _date(DateTime date) => date.toIso8601String().substring(0, 10);
