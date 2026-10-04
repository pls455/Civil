import 'gemini_search_intent_parser.dart';
import 'search_intent.dart';

class AiSearchService {
  final GeminiSearchIntentParser parser;

  const AiSearchService(this.parser);

  Future<SearchIntent> interpret(String text) {
    return parser.parse(text);
  }

  void close() => parser.close();
}
