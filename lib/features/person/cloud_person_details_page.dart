import 'package:flutter/material.dart';
import '../../search/cloud_search_engine.dart';

class CloudPersonDetailsPage extends StatelessWidget {
  final CloudPerson person;
  const CloudPersonDetailsPage({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final fields = <String, String>{
      'الهوية': person.id, 'الاسم الكامل': person.displayName,
      'الاسم': person.name, 'الأب': person.father, 'الجد': person.grandfather,
      'العائلة': person.family, 'الجنس': person.gender, 'تاريخ الميلاد': person.birth,
      'العائلة السابقة': person.oldFamily, 'اسم الأم': person.mother,
      'عائلة الأم': person.motherFamily, 'الاسم بالإنجليزية': person.englishName,
      'العنوان': person.street,
    };
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(person.displayName.isEmpty ? 'تفاصيل الشخص' : person.displayName)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              children: fields.entries.where((entry) => entry.value.isNotEmpty).map((entry) =>
                Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 125, child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(width: 12), Expanded(child: Text(entry.value)),
                  ],
                )),
              ).toList(),
            ))),
          ],
        ),
      ),
    );
  }
}