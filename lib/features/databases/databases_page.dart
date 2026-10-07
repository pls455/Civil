import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../database/database_manager.dart';
import '../../search/cloud_cache_store.dart';

class DatabasesPage extends StatefulWidget {
  const DatabasesPage({super.key});

  @override
  State<DatabasesPage> createState() => _DatabasesPageState();
}

class _DatabasesPageState extends State<DatabasesPage> {
  bool busy = false;
  bool loadingInfo = true;
  String status = 'لا توجد عملية جارية';
  InstalledDatabaseStats? _installed;
  CloudCacheStats? _cloudCache;
  String? _cloudDatabasePath;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final installed = await DatabaseManager().stats();
      final cloudStore = CloudCacheStore();
      final cloudCache = await cloudStore.stats();
      final cloudPath = await cloudStore.databasePath();

      if (!mounted) return;
      setState(() {
        _installed = installed;
        _cloudCache = cloudCache;
        _cloudDatabasePath = cloudPath;
        loadingInfo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingInfo = false;
        status = 'تعذر قراءة حالة قواعد البيانات: $e';
      });
    }
  }

  Future<void> pickSqlite() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db', 'sqlite3'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;

    final file = File(path);
    if (!await file.exists()) return;

    final size = await file.length();
    if (size > AppConstants.maxImportBytes) {
      setState(
        () => status = 'حجم الملف يتجاوز الحد المدعوم حاليًا وهو 4 GB.',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      busy = true;
      status = 'جارٍ فحص قاعدة SQLite واستيرادها...';
    });

    try {
      await DatabaseManager().replaceWith(file);
      await _loadInfo();
      if (!mounted) return;
      setState(() => status = 'تم اعتماد قاعدة SQLite بنجاح.');
    } catch (e) {
      if (mounted) setState(() => status = 'فشل استيراد SQLite: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _chooseCloudDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد حفظ قاعدة السحابة',
    );
    if (path == null || path.trim().isEmpty) return;

    setState(() {
      busy = true;
      status = 'جارٍ اعتماد مجلد حفظ قاعدة السحابة...';
    });

    try {
      await CloudCacheStore().setDatabaseDirectory(path);
      await _loadInfo();
      if (!mounted) return;
      setState(() {
        status = 'تم اعتماد مجلد حفظ قاعدة السحابة.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          status = 'فشل تغيير مكان حفظ قاعدة السحابة: $e';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _clearCloudCache() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح قاعدة السحابة المحلية'),
        content: const Text(
          'سيتم حذف الأشخاص والعلاقات المحفوظة محلياً من السحابة. '
          'لن تتأثر قاعدة المواطنين المستوردة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    setState(() {
      busy = true;
      status = 'جارٍ مسح قاعدة السحابة المحلية...';
    });

    try {
      await CloudCacheStore().clear();
      await _loadInfo();
      if (!mounted) return;
      setState(() => status = 'تم مسح قاعدة السحابة المحلية.');
    } catch (e) {
      if (mounted) {
        setState(() => status = 'فشل مسح قاعدة السحابة المحلية: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('قواعد البيانات')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: busy ? null : pickSqlite,
              icon: const Icon(Icons.file_open),
              label: const Text('استيراد قاعدة SQLite'),
            ),
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(status),
            const SizedBox(height: 16),
            if (loadingInfo)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildInstalledCard(context),
              const SizedBox(height: 12),
              _buildCloudCacheCard(context),
            ],
            const SizedBox(height: 24),
            const Text(
              'قاعدة السحابة المحلية مستقلة عن قاعدة المواطنين المستوردة. '
              'مسحها لا يغيّر الملف المستورد.',
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                AppConstants.signature,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalledCard(BuildContext context) {
    final info = _installed;
    if (info == null || !info.exists) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.storage_outlined),
          title: Text('قاعدة المواطنين'),
          subtitle: Text('لا توجد قاعدة SQLite مستوردة حالياً.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'قاعدة المواطنين',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text('الحجم: ${_size(info.sizeBytes)}'),
            Text('عدد الجداول: ${info.tableCount}'),
            if (info.tables.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('الجداول: ${info.tables.join('، ')}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCloudCacheCard(BuildContext context) {
    final info = _cloudCache;
    if (info == null || !info.exists) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'السحابة المحلية',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                'لم تُنشأ قاعدة سحابية محلية بعد. أول بحث سحابي سينشئ الملف في المسار المحدد أدناه.',
              ),
              if (_cloudDatabasePath != null) ...[
                const SizedBox(height: 10),
                const Text(
                  'مسار الملف:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SelectableText(_cloudDatabasePath!),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : _chooseCloudDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('اختيار مجلد حفظ السحابة'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'السحابة المحلية',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text('الأشخاص المحفوظون: ${info.peopleCount}'),
            Text('العلاقات المحفوظة: ${info.relationshipCount}'),
            Text('حجم القاعدة: ${_size(info.sizeBytes)}'),
            if (_cloudDatabasePath != null) ...[
              const SizedBox(height: 10),
              const Text(
                'مسار الملف:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SelectableText(_cloudDatabasePath!),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : _chooseCloudDirectory,
              icon: const Icon(Icons.folder_open),
              label: const Text('تغيير مجلد حفظ السحابة'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _clearCloudCache,
              icon: const Icon(Icons.delete_outline),
              label: const Text('مسح بيانات السحابة المحلية'),
            ),
          ],
        ),
      ),
    );
  }
}
