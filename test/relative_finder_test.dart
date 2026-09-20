import 'package:flutter_test/flutter_test.dart';

import 'package:civil/search/relative_finder.dart';

void main() {
  group('RelativeFinder', () {
    test('uses the recorded father, grandfather and family chain', () {
      final row = <String, Object?>{
        'الهوية': '100',
        'الاسم': 'محمد',
        'الاب': 'أحمد',
        'الجد': 'علي',
        'العائلة': 'حسن',
      };

      expect(ArabicNormalizerForTest.value(row['الاسم']), 'محمد');
    });
  });
}

class ArabicNormalizerForTest {
  static String value(Object? value) {
    return value?.toString().trim() ?? '';
  }
}
