import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_registry/core/app.dart';
import 'package:citizen_registry/features/search/search_page.dart';

void main() {
  testWidgets('SearchPage builds directly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SearchPage()),
    );
    await tester.pump();

    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text('الاسم'), findsOneWidget);
    expect(find.text('تحميل خيارات الفلاتر'), findsOneWidget);
  });

  testWidgets('Home opens SearchPage', (tester) async {
    await tester.pumpWidget(const CitizenRegistryApp());
    await tester.tap(find.text('البحث'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text('الاسم'), findsOneWidget);
  });
}
