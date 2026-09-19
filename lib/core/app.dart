import 'package:flutter/material.dart';
import 'features/home/home_page.dart';

class CitizenRegistryApp extends StatelessWidget {
  const CitizenRegistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سجل المواطنين',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      home: const HomePage(),
    );
  }
}
