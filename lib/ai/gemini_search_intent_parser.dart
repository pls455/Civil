import 'dart:convert';

import 'ai_settings_service.dart';
import 'gemini_client.dart';
import 'search_intent.dart';

class GeminiSearchIntentParser {
  final AiSettingsService settings;
  final GeminiClient gemini;

  GeminiSearchIntentParser({
    AiSettingsService? settings,
    GeminiClient? gemini,
  })  : settings = settings ?? AiSettingsService(),
        gemini = gemini ?? GeminiClient();

  Future<SearchIntent> parse(String userText) async {
    final text = userText.trim();
    if (text.isEmpty) {
      throw const FormatException('اكتب سؤال البحث أولاً.');
    }

    final apiKey = await settings.readGeminiApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const FormatException('أدخل مفتاح Gemini من إعدادات الذكاء الاصطناعي أولاً.');
    }

    final json = await gemini.generateJson(
      apiKey: apiKey,
      prompt: _prompt(text),
      schema: _schema,
    );

    return SearchIntent.fromJson(json);
  }

  String _prompt(String text) {
    return '''
أنت محلل لطلبات البحث في تطبيق Civil.
حوّل سؤال المستخدم إلى JSON فقط، بدون شرح.
لا تخترع أسماء أو هويات أو قيماً غير موجودة في النص.
الهدف هو فهم طلب البحث فقط. Civil هو الذي يبحث في البيانات الحقيقية.

أنواع intent:
- person_search: بحث عن شخص.
- relation_search: سؤال عن قريب أو عن أشخاص تربطهم قرابة.

العلاقات المسموحة:
father, mother, siblings, children, grandparents

في person ضع مواصفات الشخص الذي يريد المستخدم البحث عنه.
في relative ضع مواصفات الشخص القريب إذا كان المستخدم يحدد اسم القريب.
استخدم نص السؤال كما هو مع تنظيف المسافات فقط.
أي حقل غير موجود اجعله نصاً فارغاً.
الحقول:
name, father, grandfather, family, identity, mother, birthDate, gender, area

أمثلة:
"أحمد محمد المصري" => person_search.
"مين أم أحمد محمد؟" => relation_search مع person فيه name=أحمد محمد ومع relation=mother.
"مين أخو محمد أحمد؟" => relation_search مع person فيه name=محمد أحمد ومع relation=siblings.
"مين الشخص اللي أخوه خالد؟" => relation_search مع relative فيه name=خالد ومع relation=siblings.
"مين الشخص اللي أمه سعاد؟" => relation_search مع relative فيه name=سعاد ومع relation=mother.

سؤال المستخدم:
$text
''';
  }

  static const Map<String, dynamic> _schema = {
    'type': 'object',
    'properties': {
      'intent': {'type': 'string'},
      'relation': {'type': 'string'},
      'person': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'father': {'type': 'string'},
          'grandfather': {'type': 'string'},
          'family': {'type': 'string'},
          'identity': {'type': 'string'},
          'mother': {'type': 'string'},
          'birthDate': {'type': 'string'},
          'gender': {'type': 'string'},
          'area': {'type': 'string'},
        },
        'required': [
          'name',
          'father',
          'grandfather',
          'family',
          'identity',
          'mother',
          'birthDate',
          'gender',
          'area',
        ],
      },
      'relative': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'father': {'type': 'string'},
          'grandfather': {'type': 'string'},
          'family': {'type': 'string'},
          'identity': {'type': 'string'},
          'mother': {'type': 'string'},
          'birthDate': {'type': 'string'},
          'gender': {'type': 'string'},
          'area': {'type': 'string'},
        },
        'required': [
          'name',
          'father',
          'grandfather',
          'family',
          'identity',
          'mother',
          'birthDate',
          'gender',
          'area',
        ],
      },
    },
    'required': ['intent', 'relation', 'person', 'relative'],
  };

  void close() => gemini.close();

  static Map<String, dynamic> parseJson(String raw) {
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
