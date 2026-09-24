import 'package:flutter/material.dart';

import '../../search/cloud_relative_finder.dart';
import '../../search/cloud_search_engine.dart';

class CloudPersonDetailsPage extends StatefulWidget {
  final CloudPerson person;

  const CloudPersonDetailsPage({
    super.key,
    required this.person,
  });

  @override
  State<CloudPersonDetailsPage> createState() => _CloudPersonDetailsPageState();
}

class _CloudPersonDetailsPageState extends State<CloudPersonDetailsPage> {
  final CloudSearchEngine _engine = CloudSearchEngine();

  bool _loadingRelatives = true;
  String? _relativeError;
  List<CloudRelativeCandidate> _relatives = [];

  @override
  void initState() {
    super.initState();
    _loadRelatives();
  }

  @override
  void dispose() {
    _engine.close();
    super.dispose();
  }

  Future<void> _loadRelatives() async {
    try {
      final relatives =
          await CloudRelativeFinder(_engine).findForPerson(widget.person);
      if (!mounted) return;
      setState(() {
        _relatives = relatives;
        _loadingRelatives = false;
        _relativeError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRelatives = false;
        _relativeError = 'تعذر تحميل الأقارب من الخادم: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.person.displayName;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name.isEmpty ? 'تفاصيل الشخص' : name),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildIdentityHeader(context),
            const SizedBox(height: 12),
            _buildDataSection(context),
            const SizedBox(height: 12),
            _buildRelativesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityHeader(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.person.displayName.isEmpty
        ? 'بدون اسم'
        : widget.person.displayName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person_outline,
                color: theme.colorScheme.onPrimaryContainer,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.person.id.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'الهوية: ${widget.person.id}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection(BuildContext context) {
    final values = <String, String>{
      'الهوية': widget.person.id,
      'الاسم الكامل': widget.person.displayName,
      'الاسم': widget.person.name,
      'الأب': widget.person.father,
      'الجد': widget.person.grandfather,
      'العائلة': widget.person.family,
      'الجنس': widget.person.gender,
      'تاريخ الميلاد': widget.person.birth,
      'العائلة السابقة': widget.person.oldFamily,
      'اسم الأم': widget.person.mother,
      'عائلة الأم': widget.person.motherFamily,
      'الاسم بالإنجليزية': widget.person.englishName,
      'العنوان': widget.person.street,
    };

    final rows = values.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => _dataRow(entry.key, entry.value))
        .toList();

    return _sectionCard(
      context,
      title: 'بيانات الشخص',
      icon: Icons.badge_outlined,
      children: rows.isEmpty ? [const Text('لا توجد بيانات متاحة.')] : rows,
    );
  }

  Widget _buildRelativesSection(BuildContext context) {
    final groups = <CloudRelativeType, List<CloudRelativeCandidate>>{};
    for (final relative in _relatives) {
      (groups[relative.type] ??= []).add(relative);
    }

    final children = <Widget>[];

    if (_loadingRelatives) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (_relativeError != null) {
      children.add(
        Text(
          _relativeError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    } else if (_relatives.isEmpty) {
      children.add(
        const Text(
          'لم يتم العثور على روابط عائلية مؤكدة من بيانات البحث السحابي.',
        ),
      );
    } else {
      for (final type in CloudRelativeType.values) {
        final items = groups[type];
        if (items == null || items.isEmpty) continue;

        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text(
              _relativeTitle(type),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        );

        for (final relative in items) {
          children.add(
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                title: Text(
                  relative.person.displayName.isEmpty
                      ? 'بدون اسم'
                      : relative.person.displayName,
                ),
                subtitle: Text(
                  relative.person.id.isEmpty
                      ? 'لا توجد هوية معروضة'
                      : 'الهوية: ${relative.person.id}',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CloudPersonDetailsPage(person: relative.person),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return _sectionCard(
      context,
      title: 'الأقارب',
      icon: Icons.account_tree_outlined,
      children: children,
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
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
            width: 118,
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

  String _relativeTitle(CloudRelativeType type) {
    switch (type) {
      case CloudRelativeType.father:
        return 'الأب';
      case CloudRelativeType.mother:
        return 'الأم';
      case CloudRelativeType.children:
        return 'الأبناء';
      case CloudRelativeType.grandparents:
        return 'الأجداد';
    }
  }
}
