import 'package:flutter/material.dart';
import '../models/game_type.dart';

class EditorTool {
  final String id;
  final String title;
  final IconData icon;

  const EditorTool(this.id, this.title, this.icon);
}

class EditorTools {
  static const all = [
    EditorTool('shape', 'Shape', Icons.crop_square),
    EditorTool('text', 'Text', Icons.text_fields),
    EditorTool('button', 'Button', Icons.smart_button),
    EditorTool('image', 'Image', Icons.image),
    EditorTool('panel', 'Panel', Icons.web),
    EditorTool('character', 'Character', Icons.person),
    EditorTool('platform', 'Platform', Icons.horizontal_rule),
    EditorTool('enemy', 'Enemy', Icons.warning_amber),
    EditorTool('coin', 'Coin', Icons.circle),
    EditorTool('input', 'Input', Icons.input),
  ];

  static List<EditorTool> forType(GameType type) {
    return all;
  }
}
