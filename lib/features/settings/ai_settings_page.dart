import 'package:flutter/material.dart';

import '../../ai/ai_settings_service.dart';
import '../../ai/gemini_client.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _apiKeyController = TextEditingController();
  final _settings = AiSettingsService();
  final _gemini = GeminiClient();

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _configured = false;
  bool _obscureKey = true;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _gemini.close();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final key = await _settings.readGeminiApiKey();
      if (!mounted) return;

      setState(() {
        _configured = key?.trim().isNotEmpty == true;
        _apiKeyController.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messageIsError = true;
        _message = 'تعذر قراءة إعدادات Gemini: $e';
      });
    }
  }

  Future<void> _save() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _messageIsError = true;
        _message = 'أدخل مفتاح Gemini أولاً.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      await _settings.saveGeminiApiKey(key);
      if (!mounted) return;

      setState(() {
        _configured = true;
        _saving = false;
        _apiKeyController.clear();
        _messageIsError = false;
        _message = 'تم حفظ مفتاح Gemini في التخزين الآمن للجهاز.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _messageIsError = true;
        _message = 'تعذر حفظ مفتاح Gemini: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    String key = _apiKeyController.text.trim();

    if (key.isEmpty) {
      key = await _settings.readGeminiApiKey() ?? '';
    }

    if (key.isEmpty) {
      setState(() {
        _messageIsError = true;
        _message = 'أدخل مفتاح Gemini أو احفظ مفتاحاً أولاً.';
      });
      return;
    }

    setState(() {
      _testing = true;
      _message = null;
    });

    try {
      await _gemini.testConnection(apiKey: key);
      if (!mounted) return;

      setState(() {
        _testing = false;
        _messageIsError = false;
        _message = 'تم الاتصال بـ Gemini بنجاح.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _messageIsError = true;
        _message = 'فشل اختبار Gemini: $e';
      });
    }
  }

  Future<void> _delete() async {
    await _settings.deleteGeminiApiKey();
    if (!mounted) return;

    setState(() {
      _configured = false;
      _apiKeyController.clear();
      _messageIsError = false;
      _message = 'تم حذف مفتاح Gemini من الجهاز.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إعدادات الذكاء الاصطناعي')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Gemini',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'أدخل مفتاح Gemini هنا. سيُحفظ محلياً في التخزين الآمن للنظام، ولا يتم وضعه داخل الكود أو المستودع.',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _apiKeyController,
                            obscureText: _obscureKey,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: 'Gemini API Key',
                              hintText: _configured
                                  ? 'مفتاح محفوظ. أدخل مفتاحاً جديداً لاستبداله.'
                                  : 'الصق مفتاح Gemini هنا',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip:
                                    _obscureKey ? 'إظهار المفتاح' : 'إخفاء المفتاح',
                                onPressed: () {
                                  setState(() => _obscureKey = !_obscureKey);
                                },
                                icon: Icon(
                                  _obscureKey
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_configured)
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.lock),
                              title: Text('مفتاح Gemini محفوظ'),
                              subtitle: Text(
                                'المفتاح الكامل لا يُعرض داخل التطبيق بعد حفظه.',
                              ),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _saving ? 'جارٍ الحفظ...' : 'حفظ المفتاح',
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _testing ? null : _testConnection,
                            icon: _testing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering),
                            label: Text(
                              _testing
                                  ? 'جارٍ اختبار الاتصال...'
                                  : 'اختبار الاتصال',
                            ),
                          ),
                          if (_configured) ...[
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _saving || _testing ? null : _delete,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('حذف المفتاح من الجهاز'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'الموديل المستخدم حالياً: gemini-3.8-flash. '
                        'سيُستخدم لاحقاً لفهم أسئلة البحث والقرابة، بينما تبقى البيانات والنتائج تحت تحكم Civil.',
                      ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _messageIsError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
