import 'package:clrfkntrckr_off_filter/off_rules.dart';
import 'package:test/test.dart';

void main() {
  group('isValidGtin', () {
    test('accepts GTIN-8, -12, -13 and -14 with a correct check digit', () {
      expect(isValidGtin('96385074'), isTrue);
      expect(isValidGtin('036000291452'), isTrue);
      expect(isValidGtin('8710605030938'), isTrue);
      expect(isValidGtin('10012345678902'), isTrue);
    });

    test('rejects a wrong check digit', () {
      expect(isValidGtin('8710605030939'), isFalse);
    });

    test('rejects other lengths and non-digits', () {
      expect(isValidGtin('1234567'), isFalse);
      expect(isValidGtin('87106050309381'), isFalse);
      expect(isValidGtin('871060503093a'), isFalse);
      expect(isValidGtin(''), isFalse);
    });
  });

  group('isInStoreCode', () {
    test('flags GTIN-13 codes starting with 02 or 20–29', () {
      expect(isInStoreCode('0212345678909'), isTrue);
      expect(isInStoreCode('2012345678903'), isTrue);
      expect(isInStoreCode('2912345678901'), isTrue);
    });

    test('flags the same ranges written as GTIN-12 or GTIN-14', () {
      expect(isInStoreCode('212345678909'), isTrue);
      expect(isInStoreCode('00212345678909'), isTrue);
    });

    test('leaves regular codes alone', () {
      expect(isInStoreCode('8710605030938'), isFalse);
      expect(isInStoreCode('4012345678901'), isFalse);
      expect(isInStoreCode('036000291452'), isFalse);
      expect(isInStoreCode('0012345678905'), isFalse);
      expect(isInStoreCode('96385074'), isFalse);
      expect(isInStoreCode('10012345678902'), isFalse);
    });
  });

  group('gtin14', () {
    test('pads every length of a GTIN to the same 14 digits', () {
      expect(gtin14('036000291452'), '00036000291452');
      expect(gtin14('0036000291452'), '00036000291452');
      expect(gtin14('00036000291452'), '00036000291452');
      expect(gtin14('96385074'), '00000096385074');
      expect(gtin14('0000096385074'), '00000096385074');
      expect(gtin14('8710605030938'), '08710605030938');
    });

    test('is null for codes that are not a valid GTIN', () {
      expect(gtin14('8710605030939'), isNull);
      expect(gtin14('1234567'), isNull);
    });

    test('keeps the in-store ranges where the import finds them', () {
      for (final code in [
        '0212345678909',
        '212345678909',
        '2012345678903',
        '8710605030938',
        '96385074',
        '10012345678902',
      ]) {
        expect(isInStoreCode(gtin14(code)!), isInStoreCode(code), reason: code);
      }
    });
  });

  group('gtinForms', () {
    test('cuts off leading zeros down to GTIN-13, -12 and -8', () {
      expect(gtinForms('00000096385074'), [
        '00000096385074',
        '0000096385074',
        '000096385074',
        '96385074',
      ]);
      expect(gtinForms('00036000291452'), [
        '00036000291452',
        '0036000291452',
        '036000291452',
      ]);
      expect(gtinForms('08710605030938'), ['08710605030938', '8710605030938']);
      expect(gtinForms('10012345678902'), ['10012345678902']);
    });
  });

  group('expandUpcE', () {
    test('expands each of the four UPC-E patterns', () {
      expect(expandUpcE('04252614'), '042100005264');
      expect(expandUpcE('01234531'), '012300000451');
      expect(expandUpcE('01234543'), '012340000053');
      expect(expandUpcE('01234565'), '012345000065');
    });

    test('takes the code without number system or check digit', () {
      expect(expandUpcE('123456'), '012345000065');
      expect(expandUpcE('0123456'), '012345000065');
    });

    test('accepts number system 1', () {
      expect(isValidGtin(expandUpcE('11234562')!), isTrue);
    });

    test('rejects a wrong check digit, another number system or length', () {
      expect(expandUpcE('01234566'), isNull);
      expect(expandUpcE('21234565'), isNull);
      expect(expandUpcE('12345'), isNull);
      expect(expandUpcE('0123456a'), isNull);
    });
  });

  group('scannedGtin14', () {
    test('expands UPC-E before padding', () {
      expect(scannedGtin14('01234565', upcE: true), '00012345000065');
    });

    test('takes UPC-E a scanner already expanded', () {
      expect(scannedGtin14('012345000065', upcE: true), '00012345000065');
    });

    test('reads an 8-digit code as EAN-8 unless it is UPC-E', () {
      expect(scannedGtin14('96385074'), '00000096385074');
    });

    test('finds UPC-A read as 12 or as 13 digits at the same GTIN', () {
      expect(scannedGtin14('036000291452'), scannedGtin14('0036000291452'));
    });

    test('is null for an invalid code', () {
      expect(scannedGtin14('8710605030939'), isNull);
      expect(scannedGtin14('01234566', upcE: true), isNull);
    });
  });
}
