import 'dart:convert';
import 'dart:io';

import '../core/constants/cloud_api_config.dart';
import 'search_engine.dart';

class CloudPerson {
  final String id;
  final String fullName;
  final String name;
  final String father;
  final String grandfather;
  final String family;
  final String gender;
  final String birth;
  final String oldFamily;
  final String mother;
  final String motherFamily;
  final String englishName;
  final String street;

  const CloudPerson({
    required this.id, required this.fullName, required this.name,
    required this.father, required this.grandfather, required this.family,
    required this.gender, required this.birth, required this.oldFamily,
    required this.mother, required this.motherFamily,
    required this.englishName, required this.street,
  });

  factory CloudPerson.fromJson(Map<String, dynamic> json) {
    String value(String key) => json[key]?.toString().trim() ?? '';
    return CloudPerson(
      id: value('id'), fullName: value('full_name'), name: value('name1'),
      father: value('name2'), grandfather: value('name3'), family: value('name4'),
      gender: value('sex'), birth: value('birth'), oldFamily: value('old_family'),
      mother: value('mather'), motherFamily: value('m_family'),
      englishName: value('name_en'), street: value('street'),
    );
  }

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    return [name, father, grandfather, family]
        .where((value) => value.isNotEmpty).join(' ');
  }
}

class CloudSearchResult {
  final List<CloudPerson> results;
  final int limit;
  final int offset;
  final bool hasMore;
  const CloudSearchResult({required this.results, required this.limit, required this.offset, required this.hasMore});
}

class CloudSearchEngine {
  static const int defaultLimit = 50;
  final HttpClient _client;
  CloudSearchEngine({HttpClient? client}) : _client = client ?? HttpClient();

  Future<CloudSearchResult> search(SearchQuery query, {int limit = defaultLimit, int offset = 0}) async {
    final parameters = <String, String>{};
    void add(String key, String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) parameters[key] = trimmed;
    }
    add('id', query.identity);
    add('name', query.name);
    add('father', query.father);
    add('grandfather', query.grandfather);
    add('family', query.family);
    add('mother', query.mother);
    add('dob', query.birthDate);
    add('gender', query.gender ?? '');
    add('area', query.areaCode ?? '');
    if (parameters.isEmpty) {
      throw const FormatException('يجب إدخال معيار يدعمه البحث السحابي.');
    }
    parameters['limit'] = limit.toString();
    parameters['offset'] = offset.toString();
    final uri = Uri.parse(CloudApiConfig.endpoint).replace(queryParameters: parameters);
    try {
      final request = await _client.getUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (CloudApiConfig.token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${CloudApiConfig.token}');
      }
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw const FormatException('استجابة API غير صالحة.');
      final json = decoded;
      if (response.statusCode != 200 || json['ok'] != true) {
        final message = json['error']?.toString().trim();
        throw HttpException(message?.isNotEmpty == true ? message! : 'فشل البحث السحابي (${response.statusCode}).', uri: uri);
      }
      final rawResults = json['results'];
      if (rawResults is! List) throw const FormatException('استجابة API لا تحتوي على نتائج صالحة.');
      final results = rawResults.whereType<Map>().map((row) => CloudPerson.fromJson(Map<String, dynamic>.from(row))).toList();
      return CloudSearchResult(
        results: results,
        limit: (json['limit'] as num?)?.toInt() ?? limit,
        offset: (json['offset'] as num?)?.toInt() ?? offset,
        hasMore: json['hasMore'] == true,
      );
    } on SocketException {
      throw const SocketException('تعذر الاتصال بالخادم.');
    } on HttpException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw Exception('تعذر تنفيذ البحث السحابي: $e');
    }
  }
  void close() => _client.close(force: true);
}