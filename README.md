# سجل المواطنين

تطبيق Android محلي، Read Only لبيانات المواطنين، بلا Backend أو Firebase أو Cloud أو AI أو اتصال إنترنت مطلوب للتشغيل.

## الحالة الحالية

Phase 0 + Phase 1 foundation: تم تثبيت قرار تقني حقيقي لـ MDB/Jet4 وبناء هيكل Flutter/Android قابل للتوسعة. لا توجد بيانات مواطنين حقيقية أو Mock citizen records في المستودع.

## قرار MDB

يستخدم التطبيق Jackcess عبر طبقة Android Native Java. Jackcess مكتبة Java خالصة تقرأ ملفات Microsoft Access مباشرة بدون MS Access أو ODBC، وتدعم MDB/ACCDB. توثيق Jackcess يذكر متطلبات Android الخاصة بموارد المكتبة وNIO، لذلك تم عزلها خلف MethodChannel.

- MDB/Jet4: قراءة فعلية من خلال DatabaseBuilder.open(File).
- الجداول والأعمدة والأنواع تُكتشف أثناء الاستيراد.
- DATETIME يُحوّل إلى ISO-8601 نصيًا في SQLite التشغيلية.
- القراءة Read Only من المصدر.
- العلاقات/المفاتيح تُعامل كبيانات schema metadata، ولا تُفترض إذا لم يكتشفها القارئ.
- قواعد Access المشفرة تحتاج CodecProvider مناسب، وليست مدعومة افتراضيًا.

## SQLite

SQLite مدمج في Android، والتطبيق يستخدم sqflite مع transactions وbatching وpagination، ولا يحمل كل السجلات إلى RAM.

## الحجم

- حتى 2 GB: ضمن النطاق المستهدف.
- 2-4 GB: تحذير قبل الاستيراد.
- أكبر من 4 GB: مرفوض في النسخة الحالية.
- قبل الاستيراد يجب توفير مساحة مؤقتة كافية للمصدر والنسخة التشغيلية والفهارس.

هذه حدود منتج مقصودة وليست حد SQLite النظري.

## الخصوصية المحلية

لا يطلب التطبيق Internet أو Contacts أو Location أو Camera أو Microphone. لا يسجل أسماء أو هويات أو عناوين المواطنين في logs أو analytics. قواعد التشغيل تحفظ داخل Application Private Storage. الملف الأصلي لا يعدّل.

## البناء

1. ثبّت Flutter stable وAndroid SDK.
2. نفّذ flutter pub get.
3. نفّذ flutter analyze.
4. نفّذ flutter test.
5. نفّذ flutter build apk --release.

## اختبار MDB

يجب توفير ملف MDB اختباري غير حساس خارج المستودع. من داخل التطبيق اختر استيراد MDB، ثم راقب نتيجة schema وعدد السجلات. لا تضع بيانات مواطنين حقيقية في Git.

## التوقيع

بكل فخر، صنع بأيدي فلسطينية 🇵🇸
كرم

هذا النص ثابت في التطبيق، وليس مأخوذًا من قاعدة البيانات.
