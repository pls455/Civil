# Phase 0 - Technical Validation

## MDB / Jet4 على Android

القرار: Jackcess عبر Android Native Java + MethodChannel.

Jackcess هو Java library خالص للتعامل المباشر مع Access، ولا يحتاج MS Access أو ODBC. توثيقه الرسمي يذكر توافق Android مع إعدادات خاصة لـ broken NIO ومسار الموارد وContext ClassLoader. هذا يجعله مناسبًا كطبقة قراءة محلية معزولة.

المراجع:
- https://jackcess.sourceforge.io/
- https://jackcess.sourceforge.io/faq.html
- https://github.com/spannm/jackcess/

### لماذا لا UCanAccess؟

UCanAccess طبقة JDBC كاملة فوق Jackcess وتستخدم mirror database، بينما التطبيق يحتاج فقط قراءة MDB وتحويله إلى SQLite. إضافة JDBC/HSQLDB تزيد التعقيد واستهلاك الذاكرة. لذلك Jackcess هو المسار الأبسط لهذه المهمة.

## Schema

Jackcess يتيح قراءة Tables وColumns وColumn types وRows وIndexes/primary key metadata، والعلاقات حيث تكشفها المكتبة.

طبقة MdbImporter تحول الأنواع إلى SQLite affinities:
- النصوص -> TEXT
- الأرقام الصحيحة -> INTEGER
- floating/decimal -> REAL
- dates -> TEXT ISO-8601
- binary -> BLOB
- الأنواع غير المعروفة -> TEXT كحل محافظ

## Unicode والعربية

النصوص تمر كـ Java String ثم إلى SQLite TEXT، ما يحافظ على Unicode. البحث العربي لا يعتمد على SQLite collation الخاصة بالنظام؛ بل يُخزن عمود normalized عند الاستيراد/الفهرسة.

## SQLite

تستخدم طبقة Dart sqflite مع transactions وbatch inserts وindexes وLIMIT/OFFSET pagination وparameterized queries.

## الملفات الكبيرة

الاستيراد يتم على دفعات. المصدر يبقى منفصلًا عن قاعدة الإنتاج. النتيجة تُبنى في ملف مؤقت ثم تُفحص بـ SQLite integrity check قبل commit ذري.

## قيود معروفة

- Access encryption ليست مدعومة تلقائيًا من Jackcess.
- بعض ميزات Access المعقدة لا تتحول 1:1 إلى SQLite.
- حجم 2-4 GB يحتاج مساحة مؤقتة كبيرة وأداء الجهاز يختلف.
- >4 GB مرفوض في المنتج الحالي.
- لا يمكن اعتبار MDB مدعومًا إلا بعد اختبار ملف MDB حقيقي غير حساس على جهاز Android فعلي.

## شرط الصدق

لا يوجد زر MDB وهمي: الاستيراد يستدعي Native Java importer فعليًا، وإذا فشل القارئ يظهر الخطأ للمستخدم بدل إظهار نجاح مصطنع.
