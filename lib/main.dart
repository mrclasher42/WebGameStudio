import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'editor/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(const WebGameStudioApp());
}

class WebGameStudioApp extends StatefulWidget {
  const WebGameStudioApp({super.key});

  @override
  State<WebGameStudioApp> createState() => _WebGameStudioAppState();
}

class _WebGameStudioAppState extends State<WebGameStudioApp>
    with SingleTickerProviderStateMixin {
  bool darkMode = true;
  bool loaded = false;
  bool showIntro = true;

  late final AnimationController introController;
  late final Animation<double> logoScale;
  late final Animation<double> logoOpacity;
  late final Animation<double> textOpacity;

  @override
  void initState() {
    super.initState();

    introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    logoScale = CurvedAnimation(
      parent: introController,
      curve: const Interval(
        0.0,
        0.65,
        curve: Curves.easeOutBack,
      ),
    );

    logoOpacity = CurvedAnimation(
      parent: introController,
      curve: const Interval(
        0.0,
        0.45,
        curve: Curves.easeOut,
      ),
    );

    textOpacity = CurvedAnimation(
      parent: introController,
      curve: const Interval(
        0.35,
        0.85,
        curve: Curves.easeOut,
      ),
    );

    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      darkMode = prefs.getBool('darkMode') ?? true;
      loaded = true;
    });

    introController.forward();

    Timer(const Duration(milliseconds: 1450), () {
      if (!mounted) return;

      setState(() {
        showIntro = false;
      });
    });
  }

  Future<void> changeTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('darkMode', value);

    if (!mounted) return;

    setState(() {
      darkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = darkMode ? darkTheme : lightTheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Stack(
        children: [
          if (loaded)
            HomeScreen(
              darkMode: darkMode,
              onThemeChanged: changeTheme,
            )
          else
            Scaffold(
              backgroundColor:
                  darkMode ? const Color(0xFF090B10) : const Color(0xFFF5F6FA),
            ),
          if (showIntro) buildIntro(),
        ],
      ),
    );
  }

  Widget buildIntro() {
    return Material(
      color: darkMode
          ? const Color(0xFF090B10)
          : const Color(0xFFF5F6FA),
      child: Center(
        child: AnimatedBuilder(
          animation: introController,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: logoOpacity.value,
                  child: Transform.scale(
                    scale: 0.72 + (logoScale.value * 0.28),
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF8B6CFF),
                            Color(0xFF5D3FD3),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x555D3FD3),
                            blurRadius: 35,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.code_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Opacity(
                  opacity: textOpacity.value,
                  child: const Text(
                    'Web Game Studio',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Opacity(
                  opacity: textOpacity.value,
                  child: Text(
                    'HTML  •  CSS  •  JavaScript',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: darkMode
                          ? Colors.white54
                          : Colors.black45,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C5CFF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF090B10),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF090B10),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6D4AFF),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F6FA),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    introController.dispose();
    super.dispose();
  }
}
