import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/library_screen.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(
    ChangeNotifierProvider.value(value: settings, child: const AudiobookApp()),
  );
}

class AudiobookApp extends StatelessWidget {
  const AudiobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B4BDB);
    return MaterialApp(
      title: '有聲書圖書館',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}
