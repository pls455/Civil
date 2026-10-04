import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../ai/ai_search_service.dart';
import '../../ai/gemini_search_intent_parser.dart';
import '../../ai/search_intent.dart';
import '../../database/database_manager.dart';
import '../../search/cloud_cache_store.dart';
import '../../search/cloud_graph_cache_service.dart';
import '../../search/cloud_hybrid_search_engine.dart';
import '../../search/cloud_relative_finder.dart';
import '../../search/cloud_search_engine.dart';
import '../../search/relative_finder.dart';
import '../../search/search_engine.dart';
import '../person/cloud_person_details_page.dart';
import '../person/person_details_page.dart';

class _LookupOption {
  final String code;
  final String name;

  const _LookupOption({
    required this.code,
    required this.name,
  });
}

class _ValueOption {
  final String value;

  const _ValueOption(this.value);
}

enum _SearchSource {
  civilLocal,
  cloudCache,
  hybrid,
  cloud,
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final nameController = TextEditingController();
  final fatherController = TextEditingController();
  final grandfatherController = TextEditingController();
  final familyController = TextEditingController();
  final identityController = TextEditingController();
  final motherController = TextEditingController();
  final birthDateController = TextEditingController();
  final districtController = TextEditingController();
  final neighborhoodController = TextEditingController();
  final birthplaceController = TextEditingController();
  final workplaceController = TextEditingController();
  final aiController = TextEditingController();

  final _cloudCache = CloudCacheStore();
  late final CloudSearchEngine _cloudEngine;
  late final CloudHybridSearchEngine _hybridEngine;
  late final AiSearchService _ai;

  _SearchSource source = _SearchSource.civilLocal;
  bool busy = false;
  bool loadingFilters = false;
  bool filtersLoaded = false;
  String? error;
  String? filterError;
  String? aiStatus;
  String? selectedProvinceCode;
  String? selectedAreaCode;
  String? selectedGender;
  String? selectedMaritalStatus;

  List<_LookupOption> provinces = [];
  List<_LookupOption> areas = [];
  List<_ValueOption> genders = [];
  List<_ValueOption> maritalStatuses = [];
  List<Map<String, Object?>> rows = [];
  List<CloudPerson> cloudRows = [];
  bool cloudHasMore = false;
  int cloudOffset = 0;

  @override
  void initState() {
    super.initState();
    _cloudEngine = CloudSearchEngine(cache: _cloudCache);
    _hybridEngine = CloudHybridSearchEngine(
      cache: _cloudCache,
      cloud: _cloudEngine,
    );
    _ai = AiSearchService(GeminiSearchIntentParser());
  }

  @override
  void dispose() {
    nameController.dispose();
    fatherController.dispose();
    grandfatherController.dispose();
    familyController.dispose();
    identityController.dispose();
    motherController.dispose();
    birthDateController.dispose();
    districtController.dispose();
    neighborhoodController.dispose();
    birthplaceController.dispose();
    workplaceController.dispose();
    aiController.dispose();
    _cloudEngine.close();
    _ai.close();
    super.dispose();
  }

  Future<List<_ValueOption>> _loadValues(
    Database db,
    String table,
    String column,
  ) async {
    final result = await db.rawQuery(
      'SELECT DISTINCT "$column" AS value '
      'FROM "$table" '
      'WHERE "$column" IS NOT NULL '
      'AND TRIM(CAST("$column" AS TEXT)) <> "" '
      'ORDER BY "$column"',
    );

    return result
        .map(
          (row) => _ValueOption(
            row['value']?.toString().trim() ?? '',
          ),
        )
        .where((option) => option.value.isNotEmpty)
        .toList();
  }

  Future<void> _loadFilters() async {
    if (loadingFilters || filtersLoaded) return;

    setState(() {
      loadingFilters = true;
      filterError = null;
    });

    try {
      final db = await DatabaseManager().open();
      final provinceRows = await db.rawQuery(
        'SELECT "رقم المحافظة" AS code, "اسم المحافظة" AS name '
        'FROM "المحافظات" ORDER BY "اسم المحافظة"',
      );
      final areaRows = await db.rawQuery(
        'SELECT "رمز المنطقة" AS code, "اسم النطقة" AS name '
        'FROM "المناطق" ORDER BY "اسم النطقة"',
      );

      final loadedProvinces = provinceRows
          .map(
            (row) => _LookupOption(
              code: row['code']?.toString() ?? '',
              name: row['name']?.toString() ?? '',
            ),
          )
          .where((option) => option.code.isNotEmpty)
          .toList();

      final loadedAreas = areaRows
          .map(
            (row) => _LookupOption(
              code: row['code']?.toString() ?? '',
              name: row['name']?.toString() ?? '',
            ),
          )
          .where((option) => option.code.isNotEmpty)
          .toList();

      final loadedGenders = await _loadValues(
        db,
        'قائمة_الموظفين',
        'الجنس',
      );
      final loadedMaritalStatuses = await _loadValues(
        db,
        'قائمة_الموظفين',
        'الحالة الجتماعية',
      );

      if (!mounted) return;
      setState(() {
        provinces = loadedProvinces;
        areas = loadedAreas;
        genders = loadedGenders;
        maritalStatuses = loadedMaritalStatuses;
        filtersLoaded = true;
        loadingFilters = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingFilters = false;
        filterError = 'تعذر تحميل الفلاتر من قاعدة البيانات: ' + e.toString();
      });
    }
  }

  SearchQuery _query({bool cloudCompatible = false}) {
    if (cloudCompatible) {
      return SearchQuery(
        name: nameController.text,
        father: fatherController.text,
        grandfather: grandfatherController.text,
        family: familyController.text,
        identity: identityController.text,
        mother: motherController.text,
        birthDate: birthDateController.text,
        gender: selectedGender,
        areaCode: selectedAreaCode,
      );
    }

    return SearchQuery(
      name: nameController.text,
      father: fatherController.text,
      grandfather: grandfatherController.text,
      family: familyController.text,
      identity: identityController.text,
      mother: motherController.text,
      birthDate: birthDateController.text,
      provinceCode: selectedProvinceCode,
      areaCode: selectedAreaCode,
      gender: selectedGender,
      maritalStatus: selectedMaritalStatus,
      district: districtController.text,
      neighborhood: neighborhoodController.text,
      birthplace: birthplaceController.text,
      workplace: workplaceController.text,
    );
  }

  bool get _isCloudSource =>
      source != _SearchSource.civilLocal;

  String _sourceTitle(_SearchSource value) {
    switch (value) {
      case _SearchSource.civilLocal:
        return 'قاعدة المواطنين';
      case _SearchSource.cloudCache:
        return 'السحابة المحلية';
      case _SearchSource.hybrid:
        return 'هجين';
      case _SearchSource.cloud:
        return 'السحابة';
    }
  }

  Future<void> search() async {
    final query = _query(cloudCompatible: _isCloudSource);

    if (query.isEmpty) {
      setState(() => error = 'أدخل معيار بحث واحداً على الأقل.');
      return;
    }

    if (source == _SearchSource.cloudCache &&
        query.areaCode?.trim().isNotEmpty == true) {
      setState(() {
        error = 'فلتر المنطقة يحتاج السحابة، لأن قاعدة السحابة المحلية '
            'لا تخزن حقل المنطقة ضمن بيانات API المتاحة.';
      });
      return;
    }

    setState(() {
      busy = true;
      error = null;
      aiStatus = null;
    });

    try {
      await _performSearch(query);
    } catch (e) {
      if (mounted) {
        setState(() => error = 'تعذر البحث: ' + e.toString());
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _performSearch(
    SearchQuery query, {
    int offset = 0,
  }) async {
    if (source == _SearchSource.civilLocal) {
      final db = await DatabaseManager().open();
      final result = await SearchEngine(db).search(
        query,
        offset: offset,
      );

      if (!mounted) return;
      setState(() {
        if (offset == 0) {
          rows = result;
        } else {
          rows.addAll(result);
        }
      });
      return;
    }

    CloudSearchResult result;
    switch (source) {
      case _SearchSource.cloudCache:
        final cached = await _cloudCache.search(
          query,
          offset: offset,
        );
        result = CloudSearchResult(
          results: cached.results,
          limit: cached.limit,
          offset: cached.offset,
          hasMore: cached.hasMore,
        );
      case _SearchSource.hybrid:
        result = await _hybridEngine.search(
          query,
          offset: offset,
        );
      case _SearchSource.cloud:
        result = await _cloudEngine.search(
          query,
          offset: offset,
        );
      case _SearchSource.civilLocal:
        throw StateError('مصدر البحث غير صحيح.');
    }

    if (!mounted) return;
    setState(() {
      if (offset == 0) {
        cloudRows = result.results;
      } else {
        final existingIds = cloudRows.map((person) => person.id).toSet();
        for (final person in result.results) {
          if (person.id.isEmpty || existingIds.add(person.id)) {
            cloudRows.add(person);
          }
        }
      }
      cloudOffset = result.offset + result.results.length;
      cloudHasMore = result.hasMore;
    });
  }

  Future<void> _loadMoreCloud() async {
    if (busy || !cloudHasMore || source == _SearchSource.civilLocal) return;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await _performSearch(
        _query(cloudCompatible: true),
        offset: cloudOffset,
      );
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر تحميل المزيد: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _runAiSearch() async {
    final text = aiController.text.trim();
    if (text.isEmpty) {
      setState(() => error = 'اكتب سؤال البحث أولاً.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
      aiStatus = 'جارٍ فهم سؤال البحث...';
    });

    try {
      final intent = await _ai.interpret(text);
      if (intent.type == AiSearchIntentType.personSearch) {
        _applyPersonIntent(intent);
        if (!mounted) return;
        setState(() => aiStatus = 'تم تحويل السؤال إلى معايير بحث حقيقية.');
        await _performSearch(
          _query(cloudCompatible: _isCloudSource),
        );
      } else {
        await _runAiRelationSearch(intent);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          aiStatus = null;
          error = 'تعذر تنفيذ بحث الذكاء الاصطناعي: ' + e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _applyPersonIntent(SearchIntent intent) {
    final values = intent.person;
    nameController.text = values['name'] ?? '';
    fatherController.text = values['father'] ?? '';
    grandfatherController.text = values['grandfather'] ?? '';
    familyController.text = values['family'] ?? '';
    identityController.text = values['identity'] ?? '';
    motherController.text = values['mother'] ?? '';
    birthDateController.text = values['birthDate'] ?? '';

    final gender = values['gender'] ?? '';
    selectedGender = gender.isEmpty ? null : gender;

    final area = values['area'] ?? '';
    final knownArea = areas.any((item) => item.code == area);
    selectedAreaCode = area.isEmpty || !knownArea ? null : area;
  }

  Future<void> _runAiRelationSearch(SearchIntent intent) async {
    final relation = intent.relation;
    if (relation == null) {
      throw const FormatException('لم يتم تحديد نوع القرابة.');
    }

    if (source == _SearchSource.civilLocal) {
      await _runLocalAiRelation(intent);
      return;
    }

    await _runCloudAiRelation(intent);
  }

  Future<void> _runLocalAiRelation(SearchIntent intent) async {
    final db = await DatabaseManager().open();

    if (intent.hasPersonCriteria) {
      final personMatches = await SearchEngine(db).search(
        intent.toPersonQuery(),
        limit: 2,
      );
      if (personMatches.length != 1) {
        throw const FormatException(
          'لا يمكن تحديد الشخص الأساسي بشكل فريد من قاعدة المواطنين.',
        );
      }

      final relatives = await RelativeFinder(db).findForPerson(
        personMatches.first,
      );
      final wanted = relatives
          .where((candidate) => candidate.type.name == intent.relation!.name)
          .map((candidate) => candidate.person)
          .toList();

      if (!mounted) return;
      setState(() {
        rows = wanted;
        cloudRows = [];
        aiStatus = 'تم العثور على روابط القرابة من قاعدة المواطنين المحلية.';
      });
      return;
    }

    if (!intent.hasRelativeCriteria) {
      throw const FormatException('حدد الشخص أو القريب المطلوب.');
    }

    final targetMatches = await SearchEngine(db).search(
      intent.toRelativeQuery(),
      limit: 2,
    );
    if (targetMatches.length != 1) {
      throw const FormatException(
        'لا يمكن تحديد القريب المحدد بشكل فريد من قاعدة المواطنين.',
      );
    }

    final target = targetMatches.first;
    switch (intent.relation) {
      case AiRelationType.siblings:
        final relatives = await RelativeFinder(db).findForPerson(target);
        final wanted = relatives
            .where((candidate) =>
                candidate.type == RelativeType.siblings)
            .map((candidate) => candidate.person)
            .toList();
        if (!mounted) return;
        setState(() {
          rows = wanted;
          cloudRows = [];
          aiStatus = 'تم البحث عن الإخوة اعتماداً على بيانات الأب والجد والعائلة والأم.';
        });
      case AiRelationType.father:
        final wanted = await db.rawQuery(
          'SELECT * FROM "Sgaza" '
          'WHERE "الاب" = ? '
          'AND "الجد" = ? '
          'AND "العائلة" = ?',
          [
            _value(target, 'الاسم'),
            _value(target, 'الاب'),
            _value(target, 'العائلة'),
          ],
        );
        if (!mounted) return;
        setState(() {
          rows = wanted;
          cloudRows = [];
          aiStatus = 'تم البحث في سجل الأبناء المرتبطين ببيانات الأب.';
        });
      case AiRelationType.mother:
        final wanted = await db.rawQuery(
          'SELECT * FROM "Sgaza" WHERE "اسم الام" = ?',
          [_value(target, 'الاسم')],
        );
        if (!mounted) return;
        setState(() {
          rows = wanted;
          cloudRows = [];
          aiStatus = 'أُظهرت السجلات التي تحمل اسم الأم نفسه، بدون ادعاء هوية الأم.';
        });
      case AiRelationType.children:
      case AiRelationType.grandparents:
        throw const FormatException(
          'هذا الاتجاه من البحث يحتاج تحديد الشخص الأساسي أولاً.',
        );
    }
  }

  Future<void> _runCloudAiRelation(SearchIntent intent) async {
    final relation = intent.relation!;

    if (intent.hasPersonCriteria) {
      final person = await _resolveCloudPerson(intent.toPersonQuery());
      if (person == null) {
        throw const FormatException(
          'لا يمكن تحديد الشخص الأساسي بشكل فريد من مصدر السحابة الحالي.',
        );
      }

      if (source != _SearchSource.cloudCache) {
        await CloudGraphCacheService(
          engine: _cloudEngine,
          cache: _cloudCache,
        ).discover(
          person,
          maxDepth: 1,
        );
      }

      final stored = await _cloudCache.relationshipsForPerson(person.id);
      final wantedType = relation.name;
      final wanted = stored
          .where((item) => item.relationType == wantedType)
          .map((item) => item.person)
          .toList();

      if (!mounted) return;
      setState(() {
        cloudRows = wanted;
        rows = [];
        aiStatus = 'تم العثور على القرابة من بيانات السحابة المحفوظة.';
      });
      return;
    }

    if (!intent.hasRelativeCriteria) {
      throw const FormatException('حدد الشخص أو القريب المطلوب.');
    }

    final target = await _resolveCloudPerson(intent.toRelativeQuery());
    if (target == null) {
      throw const FormatException(
        'لا يمكن تحديد القريب المحدد بشكل فريد من مصدر السحابة الحالي.',
      );
    }

    if (relation == AiRelationType.siblings) {
      if (source != _SearchSource.cloudCache) {
        await CloudGraphCacheService(
          engine: _cloudEngine,
          cache: _cloudCache,
        ).discover(
          target,
          maxDepth: 1,
        );
      }

      final stored = await _cloudCache.relationshipsForPerson(target.id);
      final wanted = stored
          .where((item) => item.relationType == 'siblings')
          .map((item) => item.person)
          .toList();

      if (!mounted) return;
      setState(() {
        cloudRows = wanted;
        rows = [];
        aiStatus = 'تم عكس علاقة الإخوة من سجل القريب المحدد.';
      });
      return;
    }

    final query = switch (relation) {
      AiRelationType.father => SearchQuery(
          father: target.name,
          grandfather: target.father,
          family: target.family,
        ),
      AiRelationType.mother => SearchQuery(
          mother: target.name,
        ),
      AiRelationType.children => SearchQuery(
          father: target.name,
          grandfather: target.father,
          family: target.family,
          mother: target.mother,
        ),
      AiRelationType.grandparents => SearchQuery(
          grandfather: target.name,
        ),
      AiRelationType.siblings => target.toString().isEmpty
          ? const SearchQuery()
          : const SearchQuery(),
    };

    if (query.isEmpty) {
      throw const FormatException('بيانات القريب لا تكفي لهذا البحث.');
    }

    final result = await _cloudSearchForCurrentSource(query);
    if (!mounted) return;
    setState(() {
      cloudRows = result;
      rows = [];
      aiStatus = 'تم تنفيذ البحث العكسي اعتماداً على حقول السجل الفعلية.';
    });
  }

  Future<CloudPerson?> _resolveCloudPerson(SearchQuery query) async {
    if (query.isEmpty) return null;

    if (source == _SearchSource.cloudCache) {
      final result = await _cloudCache.search(query, limit: 2);
      return result.results.length == 1 ? result.results.first : null;
    }

    if (source == _SearchSource.hybrid) {
      final result = await _hybridEngine.search(query, limit: 2);
      return result.results.length == 1 ? result.results.first : null;
    }

    final result = await _cloudEngine.search(query, limit: 2);
    return result.results.length == 1 ? result.results.first : null;
  }

  Future<List<CloudPerson>> _cloudSearchForCurrentSource(
    SearchQuery query,
  ) async {
    switch (source) {
      case _SearchSource.cloudCache:
        final result = await _cloudCache.search(query, limit: 100);
        return result.results;
      case _SearchSource.hybrid:
        final result = await _hybridEngine.search(query, limit: 100);
        return result.results;
      case _SearchSource.cloud:
        final result = await _cloudEngine.search(query, limit: 100);
        return result.results;
      case _SearchSource.civilLocal:
        return const [];
    }
  }

  String _value(Map<String, Object?> row, String key) {
    return row[key]?.toString().trim() ?? '';
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputAction action = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        textInputAction: action,
        onSubmitted: (_) {
          if (action == TextInputAction.search) _runAiSearch();
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<_LookupOption> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.code,
                child: Text(option.name),
              ),
            )
            .toList(),
        onChanged: loadingFilters ? null : onChanged,
      ),
    );
  }

  Widget _valueDropdown(
    String label,
    String? value,
    List<_ValueOption> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(option.value),
              ),
            )
            .toList(),
        onChanged: loadingFilters ? null : onChanged,
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      nameController.clear();
      fatherController.clear();
      grandfatherController.clear();
      familyController.clear();
      identityController.clear();
      motherController.clear();
      birthDateController.clear();
      districtController.clear();
      neighborhoodController.clear();
      birthplaceController.clear();
      workplaceController.clear();
      aiController.clear();
      selectedProvinceCode = null;
      selectedAreaCode = null;
      selectedGender = null;
      selectedMaritalStatus = null;
      rows = [];
      cloudRows = [];
      cloudHasMore = false;
      cloudOffset = 0;
      error = null;
      aiStatus = null;
    });
  }

  Widget _buildFilterOptions() {
    if (!filtersLoaded) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'خيارات الفلاتر',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'الفلاتر المحلية تُقرأ من قاعدة المواطنين عند الطلب فقط.',
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: loadingFilters ? null : _loadFilters,
                icon: loadingFilters
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.tune),
                label: Text(
                  loadingFilters
                      ? 'جارٍ تحميل خيارات الفلاتر...'
                      : 'تحميل خيارات الفلاتر',
                ),
              ),
              if (filterError != null) ...[
                const SizedBox(height: 8),
                Text(
                  filterError!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _dropdown(
          'المحافظة',
          selectedProvinceCode,
          provinces,
          (value) => setState(() => selectedProvinceCode = value),
        ),
        _dropdown(
          'المنطقة',
          selectedAreaCode,
          areas,
          (value) => setState(() => selectedAreaCode = value),
        ),
        _valueDropdown(
          'الجنس',
          selectedGender,
          genders,
          (value) => setState(() => selectedGender = value),
        ),
        _valueDropdown(
          'الحالة الاجتماعية',
          selectedMaritalStatus,
          maritalStatuses,
          (value) => setState(() => selectedMaritalStatus = value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = source == _SearchSource.civilLocal;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<_SearchSource>(
              initialValue: source,
              decoration: const InputDecoration(
                labelText: 'مصدر البحث',
                border: OutlineInputBorder(),
              ),
              items: _SearchSource.values
                  .map(
                    (value) => DropdownMenuItem<_SearchSource>(
                      value: value,
                      child: Text(_sourceTitle(value)),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        source = value;
                        rows = [];
                        cloudRows = [];
                        cloudHasMore = false;
                        cloudOffset = 0;
                        error = null;
                        aiStatus = null;
                      });
                    },
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'بحث بالذكاء الاصطناعي',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gemini يفهم السؤال فقط. التنفيذ والنتائج تأتي من قاعدة البيانات أو السحابة.',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: aiController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'مثال: مين أخو أحمد محمد؟',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: busy ? null : _runAiSearch,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('تنفيذ البحث بالـAI'),
                    ),
                    if (aiStatus != null) ...[
                      const SizedBox(height: 8),
                      Text(aiStatus!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _field(nameController, 'الاسم'),
            _field(fatherController, 'اسم الأب'),
            _field(grandfatherController, 'اسم الجد'),
            _field(familyController, 'العائلة'),
            _field(identityController, 'الهوية'),
            _field(motherController, 'اسم الأم'),
            _field(
              birthDateController,
              'تاريخ الميلاد',
              action: TextInputAction.search,
            ),
            _buildFilterOptions(),
            if (isLocal) ...[
              _field(districtController, 'الناحية'),
              _field(neighborhoodController, 'الحي'),
              _field(birthplaceController, 'مكان الميلاد'),
              _field(workplaceController, 'مكان العمل'),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : search,
                    icon: const Icon(Icons.search),
                    label: Text(
                      isLocal ? 'بحث في قاعدة المواطنين' : 'تنفيذ البحث',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: busy ? null : _clearFilters,
                  child: const Text('مسح'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            if (isLocal)
              _buildLocalResults(context)
            else
              _buildCloudResults(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalResults(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('لا توجد نتائج.'));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final row = rows[index];

        return ListTile(
          title: Text(
            [
              row['الاسم'],
              row['الاب'],
              row['العائلة'],
            ].where((value) => value != null).join(' '),
          ),
          subtitle: Text(
            'الهوية: ' +
                (row['الهوية']?.toString() ?? '') +
                '\nمكان الميلاد: ' +
                (row['مكان الميلاد']?.toString() ?? ''),
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_left),
          onTap: () async {
            final db = await DatabaseManager().open();
            if (!context.mounted) return;

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonDetailsPage(
                  db: db,
                  person: row,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCloudResults(BuildContext context) {
    if (cloudRows.isEmpty) {
      return const Center(child: Text('لا توجد نتائج.'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cloudRows.length + (cloudHasMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        if (index == cloudRows.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FilledButton(
              onPressed: busy ? null : _loadMoreCloud,
              child: const Text('تحميل المزيد'),
            ),
          );
        }

        final person = cloudRows[index];

        return ListTile(
          title: Text(
            person.displayName.isEmpty ? 'بدون اسم' : person.displayName,
          ),
          subtitle: Text(
            'الهوية: ' +
                person.id +
                '\nتاريخ الميلاد: ' +
                person.birth,
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CloudPersonDetailsPage(person: person),
            ),
          ),
        );
      },
    );
  }
}
