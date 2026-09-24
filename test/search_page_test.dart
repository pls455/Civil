import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_registry/core/app.dart';
import 'package:citizen_registry/features/search/search_page.dart';

void main() {
  testWidgets('SearchPage renders without opening the database', (tester) async {
    await tester.pumpWidget(const CitizenRegistryApp());
    await tester.tap(find.text('البحث'));
    await tester.pump();

    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text('الاسم'), findsOneWidget);
    expect(find.text('تحميل خيارات الفلاتر'), findsOneWidget);
  });
}
