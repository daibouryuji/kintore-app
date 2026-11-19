import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/exercises_screen.dart';
import 'screens/menus_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/today_screen.dart';
import 'screens/weight_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const KintoreApp());
}

class KintoreApp extends StatelessWidget {
  const KintoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: b,
        );
    return MaterialApp(
      title: '筋トレ記録',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  static const pages = [
    TodayScreen(),
    ExercisesScreen(),
    MenusScreen(),
    WeightScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.fitness_center), label: '今日'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: '種目'),
          NavigationDestination(
              icon: Icon(Icons.calendar_view_week), label: 'メニュー'),
          NavigationDestination(
              icon: Icon(Icons.monitor_weight_outlined), label: '体重'),
          NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}
