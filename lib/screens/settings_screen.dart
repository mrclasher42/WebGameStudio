import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final bool arabic;
  final bool darkMode;
  final ValueChanged<bool> onLanguageChanged;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.arabic,
    required this.darkMode,
    required this.onLanguageChanged,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(arabic ? 'الإعدادات' : 'Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(arabic ? 'العربية' : 'Arabic'),
            subtitle: Text(
              arabic ? 'لغة المحرك العربية' : 'Use Arabic interface',
            ),
            value: arabic,
            onChanged: onLanguageChanged,
          ),
          SwitchListTile(
            title: Text(arabic ? 'الوضع الداكن' : 'Dark mode'),
            value: darkMode,
            onChanged: onThemeChanged,
          ),
        ],
      ),
    );
  }
}
