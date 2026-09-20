import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../database/database_manager.dart';
import '../../services/mdb_service.dart';

class DatabasesPage extends StatefulWidget {
  const DatabasesPage({super.key});
  @override State<DatabasesPage> createState() => _DatabasesPageState();
}

class _DatabasesPageState extends State<DatabasesPage> {
  bool busy = false;
  String status = 'لا توجد عملية جارية';

  Future<void> pickMdb() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mdb'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;

    final file = File(path);
    final size = await file.length();
    if (size > AppConstants.maxImportBytes) {
      setState(() => status = 'حجم الملف يتجاوز الحد المدعوم حاليًا وهو 4 GB.');
      return;
    }
    if (size > AppConstants.warningImportBytes && mounted) {
      setState(() => status = 'تحذير: ملف أكبر من 2 GB. الاستيراد قد يستغرق وقتًا ومساحة مؤقتة كبيرة.');
    }
    if (!mounted) return;

    setState(() {
      busy = true;
      status = 'جارٍ تحويل MDB إلى SQLite...';
    });

    try {
      final dir = await getTemporaryDirectory();
      final output = p.join(
        dir.path,
        'citizen_import_${DateTime.now().millisecondsSinceEpoch}.sqlite',
      );
      final result = await MdbService().importMdb(
        sourcePath: path,
        outputPath: output,
      );

      await DatabaseManager().replaceWith(File(output));
      if (await File(output).exists()) {
        await File(output).delete();
      }
      if (!mounted) return;
      setState(() => status = 'تم استيراد ${result['rows'] ?? 0} سجل من ${result['tables'] ?? 0} جدول، وأصبحت SQLite قاعدة التطبيق النشطة.');
    } catch (e) {
      if (mounted) setState(() => status = 'فشل الاستيراد: $e');
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
              onPressed: busy ? null : pickMdb,
              icon: const Icon(Icons.file_open),
              label: const Text('استيراد MDB إلى SQLite'),
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
