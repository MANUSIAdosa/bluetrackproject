import 'package:blue_track/features/explore/domain/interest_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding interests map to the mock project categories', () {
    expect(InterestCategories.categoriesOf('terumbu_karang'), ['karang']);
    expect(InterestCategories.categoriesOf('mangrove'), ['mangrove']);
    expect(InterestCategories.categoriesOf('perikanan'), ['lamun']);
    expect(InterestCategories.categoriesOf('satwa_laut'), [
      'penyu',
      'mamalia_laut',
    ]);
  });

  test('marine debris has no project category yet', () {
    expect(InterestCategories.categoriesOf('sampah_laut'), isEmpty);
  });

  test('a raw category id still matches itself', () {
    expect(InterestCategories.matches('penyu', 'penyu'), isTrue);
    expect(InterestCategories.matches('terumbu_karang', 'penyu'), isFalse);
  });
}
