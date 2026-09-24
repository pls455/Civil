import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_registry/features/search/search_page.dart';

void main() {
  testWidgets('SearchPage renders without opening the database', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SearchPage(),
      ),
    );

    expect(find.text('البحث'), findsOneWidget);
    expect(find.text('الاسم'), findsOneWidget);
    expect(find.text('تحميل خيارات الفلاتر'), findsOneWidget);
  });
}
