import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_registry/core/utils/arabic_normalizer.dart';

void main() {
  test('normalizes Arabic variants without conflating words', () {
    expect(ArabicNormalizer.normalize('أحمد'), 'احمد');
    expect(ArabicNormalizer.normalize('إحمد'), 'احمد');
    expect(ArabicNormalizer.normalize('آحمد'), 'احمد');
    expect(ArabicNormalizer.normalize('مُحَمَّد'), 'محمد');
    expect(ArabicNormalizer.normalize('محمود'), 'محمود');
    expect(ArabicNormalizer.normalize('محمد'), isNot('محمود'));
  });
}
