import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../search/relative_finder.dart';

class PersonDetailsPage extends StatefulWidget {
  final Database db;
  final Map<String, Object?> person;

  const PersonDetailsPage({
    super.key,
    required this.db,
    required this.person,
  });

  @override
  State<PersonDetailsPage> createState() => _PersonDetailsPageState();
}

class _PersonDetailsPageState extends State<PersonDetailsPage> {
  bool busy = true;
  String? error;
  List<RelativeCandidate> relatives = [];
  Map<String, Object?>? employee;
  String? provinceName;
  String? areaName;

  static const _personFields = <String, String>{
    'الهوية': 'الهوية',
    'الاسم': 'الاسم',
    'الاب': 'الأب',
    'الجد': 'الجد',
    'العائلة': 'العائلة',
    'اسم الام': 'اسم الأم',
    'تاريخ الميلاد': 'تاريخ الميلاد',
    'مكان الميلاد': 'مكان الميلاد',
    'الحي': 'الحي',
    'الناحية': 'الناحية',
    'المحافظة': 'المحافظة',
    'المنطقة': 'المنطقة',
    'رقم الحي': 'رقم الحي',
    'رقم المنزل': 'رقم المنزل',
  };

  static const _employeeFields = <String, String>{
    'الرقم الوظيفي': 'الرقم الوظيفي',
    'الحالة الجتماعية': 'الحالة الاجتماعية',
    'عدد الاولاد': 'عدد الأولاد',
    'اسم الزوجة': 'اسم الزوجة',
    'العنوان': 'العنوان',
    'العمل': 'العمل',
    'الدرجة': 'الدرجة',
    'تاريخ بداية العمل': 'تاريخ بداية العمل',
    'مكان العمل': 'مكان العمل',
  };

  @override
  void initState() {
    super.initState();
    _loadRelatedData();
  }

  Future<void> _loadRelatedData() async {
    try {
      final foundRelatives =
          await RelativeFinder(widget.db).findForPerson(widget.person);

      Map<String, Object?>? foundEmployee;
      String? foundProvinceName;
      String? foundAreaName;

      final provinceCode = _value(widget.person, 'رمز المحافظة');
      if (provinceCode.isNotEmpty) {
        final rows = await widget.db.rawQuery(
          'SELECT "اسم المحافظة" FROM "المحافظات" '
          'WHERE CAST("رقم المحافظة" AS TEXT) = ? LIMIT 1',
          [provinceCode],
        );
        if (rows.isNotEmpty) {
          foundProvinceName = rows.first['اسم المحافظة']?.toString().trim();
        }
      }

      final areaCode = _value(widget.person, 'رمز المنطقة');
      if (areaCode.isNotEmpty) {
        final rows = await widget.db.rawQuery(
          'SELECT "اسم النطقة" FROM "المناطق" '
          'WHERE CAST("رمز المنطقة" AS TEXT) = ? LIMIT 1',
          [areaCode],
        );
        if (rows.isNotEmpty) {
          foundAreaName = rows.first['اسم النطقة']?.toString().trim();
        }
      }

      final identity = _value(widget.person, 'الهوية');
      if (identity.isNotEmpty) {
        final rows = await widget.db.rawQuery(
          'SELECT * FROM "قائمة_الموظفين" WHERE CAST("الهوية" AS TEXT) = ? LIMIT 1',
          [identity],
        );
        if (rows.isNotEmpty) {
          foundEmployee = rows.first;
        }
      }

      if (!mounted) return;
      setState(() {
        relatives = foundRelatives;
        employee = foundEmployee;
        provinceName = foundProvinceName;
        areaName = foundAreaName;
        busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'تعذر تحميل بيانات الشخص: $e';
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName(widget.person);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(name.isEmpty ? 'تفاصيل الشخص' : name)),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPersonSection(context),
                      if (employee != null) ...[
                        const SizedBox(height: 12),
                        _buildEmployeeSection(context),
                      ],
                      const SizedBox(height: 12),
                      _buildRelativesSection(context),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPersonSection(BuildContext context) {
    final rows = <Widget>[];

    for (final entry in _personFields.entries) {
      var value = _value(widget.person, entry.key);
      if (entry.key == 'المحافظة') {
        value = provinceName ?? _value(widget.person, 'رمز المحافظة');
      } else if (entry.key == 'المنطقة') {
        value = areaName ?? _value(widget.person, 'رمز المنطقة');
      }
      if (value.isEmpty) continue;
      rows.add(_dataRow(entry.value, value));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات الشخص',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text('لا توجد بيانات متاحة.')
            else
              ..._withDividers(rows),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeSection(BuildContext context) {
    final rows = <Widget>[];

    for (final entry in _employeeFields.entries) {
      final value = _value(employee!, entry.key);
      if (value.isEmpty) continue;
      rows.add(_dataRow(entry.value, value));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات العمل',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ..._withDividers(rows),
          ],
        ),
      ),
    );
  }

  Widget _buildRelativesSection(BuildContext context) {
    final groups = <RelativeType, List<RelativeCandidate>>{};
    for (final relative in relatives) {
      (groups[relative.type] ??= []).add(relative);
    }

    final children = <Widget>[
      Text(
        'الأقارب',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
    ];

    if (relatives.isEmpty) {
      children.add(
        const Text('لم يتم العثور على روابط عائلية مؤكدة من البيانات المتاحة.'),
      );
    } else {
      for (final type in RelativeType.values) {
        final items = groups[type];
        if (items == null || items.isEmpty) continue;

        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              _relativeTitle(type),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );

        for (final relative in items) {
          children.add(
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(_displayName(relative.person)),
                subtitle: Text(
                  'الهوية: ${_value(relative.person, 'الهوية')}',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonDetailsPage(
                      db: widget.db,
                      person: relative.person,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> rows) {
    final result = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      result.add(rows[i]);
      if (i != rows.length - 1) {
        result.add(const Divider(height: 1));
      }
    }
    return result;
  }

  String _relativeTitle(RelativeType type) {
    switch (type) {
      case RelativeType.father:
        return 'الأب';
      case RelativeType.grandfather:
        return 'الجد';
      case RelativeType.children:
        return 'الأبناء';
      case RelativeType.siblings:
        return 'الإخوة';
      case RelativeType.extendedFamily:
        return 'أفراد من العائلة الممتدة';
    }
  }

  String _displayName(Map<String, Object?> row) {
    final parts = [
      _value(row, 'الاسم'),
      _value(row, 'الاب'),
      _value(row, 'الجد'),
      _value(row, 'العائلة'),
    ].where((value) => value.isNotEmpty).toList();
    return parts.join(' ');
  }

  String _value(Map<String, Object?> row, String key) {
    return row[key]?.toString().trim() ?? '';
  }
}
