import 'package:clrfkntrckr_off_filter/off_rules.dart';
import 'package:test/test.dart';

OffServing? serving(
  Object? text, {
  Object? quantity,
  Object? unit,
  Basis basis = Basis.per100g,
  bool bread = false,
}) => parseOffServing(text, quantity, unit, basis: basis, bread: bread);

void main() {
  test('takes OFF\'s serving quantity in the basis unit', () {
    expect(serving('1 portie (35 g)', quantity: 35, unit: 'g'), (
      size: 35.0,
      slices: null,
    ));
    expect(
      serving('250 ml', quantity: '250', unit: 'ml', basis: Basis.per100ml),
      (size: 250.0, slices: null),
    );
  });

  test('reads the size from the text when OFF worked out none', () {
    expect(serving('35,5 gram'), (size: 35.5, slices: null));
    expect(serving('1 snee (35g)'), (size: 35.0, slices: 1));
    expect(serving('50 grammes', quantity: 50), (size: 50.0, slices: null));
  });

  test('is none without a size, in another unit than the basis, or '
      'zero', () {
    expect(serving(null), isNull);
    expect(serving('1 stuk'), isNull);
    expect(serving('1150'), isNull);
    expect(serving('200 ml', quantity: 200, unit: 'ml'), isNull);
    expect(serving('30 g', basis: Basis.per100ml), isNull);
    expect(serving('0 g', quantity: 0, unit: 'g'), isNull);
  });

  test('counts the slices its text names', () {
    expect(serving('2 slices (80 g)', quantity: 80, unit: 'g'), (
      size: 80.0,
      slices: 2,
    ));
    expect(serving('2 sneetjes (70 g)'), (size: 70.0, slices: 2));
    expect(serving('Snee (35 g)'), (size: 35.0, slices: 1));
    expect(serving('1 boterham (35 g)'), (size: 35.0, slices: 1));
    expect(serving('1 tranche (25 g)'), (size: 25.0, slices: 1));
    expect(serving('2 Scheiben (100 g)'), (size: 100.0, slices: 2));
    expect(serving('1 piece (60 g)', bread: true), (size: 60.0, slices: null));
  });

  test('counts a bread serving given as a weight alone under 100 g as one '
      'slice', () {
    expect(serving('35 g', quantity: 35, unit: 'g', bread: true), (
      size: 35.0,
      slices: 1,
    ));
    expect(serving('1 serving (38 g)', bread: true), (size: 38.0, slices: 1));
    expect(serving('35.0g', bread: true), (size: 35.0, slices: 1));
    expect(serving('100.0g', bread: true), (size: 100.0, slices: null));
    expect(serving('1 puntje (50 g)', bread: true), (size: 50.0, slices: null));
    expect(serving('35 g', bread: false), (size: 35.0, slices: null));
  });
}
