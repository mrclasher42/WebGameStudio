import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_project.dart';

class ProjectStorage {
  static const String key = 'web_game_studio_project';

  static Future<void> save(GameProject project) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(project.toMap()));
  }

  static Future<GameProject?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);

    if (value == null) {
      return null;
    }

    return GameProject.fromMap(jsonDecode(value));
  }
}
