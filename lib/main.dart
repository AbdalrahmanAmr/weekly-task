import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'notifier.dart';
import 'task_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppNotifier.init();
  final store = TaskStore();
  await store.load();
  runApp(WeeklyTaskApp(store: store));
}

class WeeklyTaskApp extends StatelessWidget {
  const WeeklyTaskApp({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0284C7);
    return MaterialApp(
      title: 'Weekly Task',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: seed),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(store: store),
    );
  }
}
