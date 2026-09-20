import 'package:flutter/material.dart';

import '../../database/database_manager.dart';
import '../../search/search_engine.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  bool busy = false;
  String? error;
  List<Map<String, Object?>> rows = [];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final query = controller.text.trim();
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
              TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => search(),
                decoration: InputDecoration(
                  labelText: 'الهوية أو الاسم',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: busy ? null : search,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('لا توجد نتائج.'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, index) {
                          final row = rows[index];
                          return ListTile(
                            title: Text('${row['الاسم'] ?? ''} ${row['الاب'] ?? ''} ${row['العائلة'] ?? ''}'),
                            subtitle: Text('الهوية: ${row['الهوية'] ?? ''}\nمكان الميلاد: ${row['مكان الميلاد'] ?? ''}'),
                            isThreeLine: true,
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
