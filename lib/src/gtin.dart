final _digits = RegExp(r'^\d+$');

/// Whether [code] is a GTIN-8, -12, -13 or -14 with a valid check digit.
bool isValidGtin(String code) {
  if (!const {8, 12, 13, 14}.contains(code.length)) return false;
  if (!_digits.hasMatch(code)) return false;
  return _checkDigit(code.substring(0, code.length - 1)) ==
      code[code.length - 1];
}

/// Whether [code] falls in the in-store ranges 02 and 20–29, which shops
/// assign themselves (weighed meat, cheese), so the same code means different
/// products in different shops.
bool isInStoreCode(String code) {
  final gtin13 = switch (code.length) {
    12 => '0$code',
    14 when code.startsWith('0') => code.substring(1),
    _ => code,
  };
  return gtin13.length == 13 &&
      (gtin13.startsWith('02') || gtin13.startsWith('2'));
}

/// [code] padded with zeros to 14 digits, or null when it isn't a valid GTIN.
/// A GTIN keeps its value at every length it is written in (UPC-A as 12 or
/// 13 digits, EAN-8 as 8 or 13), so two codes are the same product when their
/// GTIN-14s match. The food database's barcode lookup compares the same way.
String? gtin14(String code) => isValidGtin(code) ? code.padLeft(14, '0') : null;

/// The ways [gtin14] can be written: as 14 digits, and as 13, 12 and 8 while
/// only zeros are cut off.
List<String> gtinForms(String gtin14) => [
  gtin14,
  for (final length in const [13, 12, 8])
    if (gtin14.substring(0, 14 - length) == '0' * (14 - length))
      gtin14.substring(14 - length),
];

/// The GTIN-14 of a barcode as a scanner read it, or null when it isn't a
/// valid GTIN. A [upcE] code is expanded to the UPC-A it stands for first.
String? scannedGtin14(String value, {bool upcE = false}) {
  final code = value.trim();
  if (upcE && code.length <= 8) {
    final upcA = expandUpcE(code);
    return upcA == null ? null : gtin14(upcA);
  }
  return gtin14(code);
}

/// The UPC-A that UPC-E [code] compresses, or null when it isn't UPC-E.
/// Takes the 8 digits as printed, or 6 or 7 without the number system 0 or
/// the check digit, which some scanners leave off.
String? expandUpcE(String code) {
  if (!_digits.hasMatch(code)) return null;
  final body = switch (code.length) {
    6 => '0$code',
    7 || 8 => code.substring(0, 7),
    _ => null,
  };
  if (body == null || (body[0] != '0' && body[0] != '1')) return null;
  final d = body.substring(1);
  final payload =
      body[0] +
      switch (d.codeUnitAt(5) - 0x30) {
        <= 2 => '${d.substring(0, 2)}${d[5]}0000${d.substring(2, 5)}',
        3 => '${d.substring(0, 3)}00000${d.substring(3, 5)}',
        4 => '${d.substring(0, 4)}00000${d[4]}',
        _ => '${d.substring(0, 5)}0000${d[5]}',
      };
  final check = _checkDigit(payload);
  if (code.length == 8 && code[7] != check) return null;
  return payload + check;
}

/// The GS1 check digit for [payload], the code without its last digit.
String _checkDigit(String payload) {
  var sum = 0;
  for (var i = payload.length - 1, weight = 3; i >= 0; i--) {
    sum += (payload.codeUnitAt(i) - 0x30) * weight;
    weight = 4 - weight;
  }
  return '${(10 - sum % 10) % 10}';
}
