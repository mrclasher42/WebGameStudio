import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'editor/editor_screen.dart';

void main() {
  runApp(const WebGameStudio());
}

class WebGameStudio extends StatefulWidget {
  const WebGameStudio({super.key});

  @override
  State<WebGameStudio> createState() => _WebGameStudioState();
}

class _WebGameStudioState extends State<WebGameStudio> {
  bool arabic = true;
  bool darkMode = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      arabic = prefs.getBool('arabic') ?? true;
      darkMode = prefs.getBool('darkMode') ?? true;
    });
  }

  Future<void> setLanguage(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('arabic', value);

    setState(() {
      arabic = value;
    });
  }

  Future<void> setTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);

    setState(() {
      darkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Web Game Studio',
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark(useMaterial3: true),
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: EditorScreen(
        arabic: arabic,
        darkMode: darkMode,
        onLanguageChanged: setLanguage,
        onThemeChanged: setTheme,
      ),
    );
  }
}
