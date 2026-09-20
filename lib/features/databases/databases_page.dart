import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../database/database_manager.dart';

class DatabasesPage extends StatefulWidget {
  const DatabasesPage({super.key});

  @override
  State<DatabasesPage> createState() => _DatabasesPageState();
}

class _DatabasesPageState extends State<DatabasesPage> {
  bool busy = false;
  String status = 'لا توجد عملية جارية';

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
      setState(() => status = 'حجم الملف يتجاوز الحد المدعوم حاليًا وهو 4 GB.');
      return;
    }

    if (!mounted) return;
    setState(() {
      busy = true;
      status = 'جارٍ فحص قاعدة SQLite واستيرادها...';
    });

    try {
      await DatabaseManager().replaceWith(file);
      if (!mounted) return;
      setState(() => status = 'تم اعتماد قاعدة SQLite بنجاح.');
    } catch (e) {
      if (mounted) setState(() => status = 'فشل استيراد SQLite: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('قواعد البيانات')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const Spacer(),
                const Text(AppConstants.signature, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}
