import 'package:flutter/material.dart';

import '../../database/database_manager.dart';
import '../../search/search_engine.dart';
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

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final nameController = TextEditingController();
  final fatherController = TextEditingController();
  final grandfatherController = TextEditingController();
  final familyController = TextEditingController();
  final identityController = TextEditingController();

  bool busy = false;
  bool loadingFilters = true;
  String? error;
  String? filterError;
  String? selectedProvinceCode;
  String? selectedAreaCode;
  String? selectedGender;
  String? selectedMaritalStatus;
  String? selectedDistrict;
  String? selectedNeighborhood;
  String? selectedBirthplace;
  String? selectedWorkplace;

  List<_LookupOption> provinces = [];
  List<_LookupOption> areas = [];
  List<_ValueOption> genders = [];
  List<_ValueOption> maritalStatuses = [];
  List<_ValueOption> districts = [];
  List<_ValueOption> neighborhoods = [];
  List<_ValueOption> birthplaces = [];
  List<_ValueOption> workplaces = [];
  List<Map<String, Object?>> rows = [];

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void dispose() {
    nameController.dispose();
    fatherController.dispose();
    grandfatherController.dispose();
    familyController.dispose();
    identityController.dispose();
    super.dispose();
  }

  Future<List<_ValueOption>> _loadValues(
    dynamic db,
    String table,
    String column,
  ) async {
    final result = await db.rawQuery(
      'SELECT DISTINCT "$column" AS value FROM "$table" '
      'WHERE "$column" IS NOT NULL AND TRIM(CAST("$column" AS TEXT)) <> "" '
      'ORDER BY "$column"',
    );

    return result
        .map(
          (row) => _ValueOption(row['value']?.toString().trim() ?? ''),
        )
        .where((option) => option.value.isNotEmpty)
        .toList();
  }

  Future<void> _loadFilters() async {
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

      final loadedGenders = await _loadValues(db, 'قائمة_الموظفين', 'الجنس');
      final loadedMaritalStatuses =
          await _loadValues(db, 'قائمة_الموظفين', 'الحالة الجتماعية');
      final loadedDistricts = await _loadValues(db, 'Sgaza', 'الناحية');
      final loadedNeighborhoods = await _loadValues(db, 'Sgaza', 'الحي');
      final loadedBirthplaces = await _loadValues(db, 'Sgaza', 'مكان الميلاد');
      final loadedWorkplaces =
          await _loadValues(db, 'قائمة_الموظفين', 'مكان العمل');

      if (!mounted) return;
      setState(() {
        provinces = loadedProvinces;
        areas = loadedAreas;
        genders = loadedGenders;
        maritalStatuses = loadedMaritalStatuses;
        districts = loadedDistricts;
        neighborhoods = loadedNeighborhoods;
        birthplaces = loadedBirthplaces;
        workplaces = loadedWorkplaces;
        loadingFilters = false;
        filterError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingFilters = false;
        filterError = 'تعذر تحميل الفلاتر من قاعدة البيانات: $e';
      });
    }
  }

  Future<void> search() async {
    final query = SearchQuery(
      name: nameController.text,
      father: fatherController.text,
      grandfather: grandfatherController.text,
      family: familyController.text,
      identity: identityController.text,
      provinceCode: selectedProvinceCode,
      areaCode: selectedAreaCode,
      gender: selectedGender,
      maritalStatus: selectedMaritalStatus,
      district: selectedDistrict,
      neighborhood: selectedNeighborhood,
      birthplace: selectedBirthplace,
      workplace: selectedWorkplace,
    );

    if (query.isEmpty) return;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final db = await DatabaseManager().open();
      final result = await SearchEngine(db).search(query);
      if (!mounted) return;
      setState(() => rows = result);
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر البحث: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
          if (action == TextInputAction.search) search();
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
      selectedProvinceCode = null;
      selectedAreaCode = null;
      selectedGender = null;
      selectedMaritalStatus = null;
      selectedDistrict = null;
      selectedNeighborhood = null;
      selectedBirthplace = null;
      selectedWorkplace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _field(nameController, 'الاسم'),
              _field(fatherController, 'اسم الأب'),
              _field(grandfatherController, 'اسم الجد'),
              _field(familyController, 'العائلة'),
              _field(
                identityController,
                'الهوية',
                action: TextInputAction.search,
              ),
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
              _valueDropdown(
                'الناحية',
                selectedDistrict,
                districts,
                (value) => setState(() => selectedDistrict = value),
              ),
              _valueDropdown(
                'الحي',
                selectedNeighborhood,
                neighborhoods,
                (value) => setState(() => selectedNeighborhood = value),
              ),
              _valueDropdown(
                'مكان الميلاد',
                selectedBirthplace,
                birthplaces,
                (value) => setState(() => selectedBirthplace = value),
              ),
              _valueDropdown(
                'مكان العمل',
                selectedWorkplace,
                workplaces,
                (value) => setState(() => selectedWorkplace = value),
              ),
              if (filterError != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    filterError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : search,
                      icon: const Icon(Icons.search),
                      label: const Text('بحث'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: busy ? null : _clearFilters,
                    child: const Text('مسح الفلاتر'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (busy || loadingFilters) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('لا توجد نتائج.'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return ListTile(
                            title: Text(
                              '${row['الاسم'] ?? ''} ${row['الاب'] ?? ''} ${row['العائلة'] ?? ''}',
                            ),
                            subtitle: Text(
                              'الهوية: ${row['الهوية'] ?? ''}\n'
                              'مكان الميلاد: ${row['مكان الميلاد'] ?? ''}',
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}