import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  @override void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('البحث')),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: controller, textInputAction: TextInputAction.search, decoration: const InputDecoration(labelText: 'الهوية أو الاسم', prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
        const SizedBox(height: 16),
        const Expanded(child: Center(child: Text('استورد قاعدة بيانات محلية لبدء البحث.'))),
      ])),
    ));
  }
}
