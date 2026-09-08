import '../models/game_type.dart';

class EditorTool {
  final String id;
  final String title;
  final String titleAr;

  const EditorTool({
    required this.id,
    required this.title,
    required this.titleAr,
  });
}

class EditorTools {
  static const common = [
    EditorTool(id: 'shape', title: 'Shape', titleAr: 'شكل'),
    EditorTool(id: 'text', title: 'Text', titleAr: 'نص'),
    EditorTool(id: 'button', title: 'Button', titleAr: 'زر'),
    EditorTool(id: 'image', title: 'Image', titleAr: 'صورة'),
    EditorTool(id: 'panel', title: 'Panel', titleAr: 'لوحة'),
  ];

  static List<EditorTool> forType(GameType type) {
    switch (type) {
      case GameType.platformer:
        return const [
          EditorTool(id: 'player', title: 'Character', titleAr: 'شخصية'),
          EditorTool(id: 'platform', title: 'Platform', titleAr: 'منصة'),
          EditorTool(id: 'coin', title: 'Coin', titleAr: 'عملة'),
          EditorTool(id: 'enemy', title: 'Enemy', titleAr: 'عدو'),
          EditorTool(id: 'box', title: 'Box', titleAr: 'صندوق'),
          ...common,
        ];
      case GameType.ticTacToe:
        return const [
          EditorTool(id: 'grid', title: 'Grid', titleAr: 'شبكة'),
          EditorTool(id: 'cell', title: 'Cell', titleAr: 'خلية'),
          ...common,
        ];
      case GameType.quiz:
        return const [
          EditorTool(id: 'question', title: 'Question', titleAr: 'سؤال'),
          EditorTool(id: 'progress', title: 'Progress', titleAr: 'تقدم'),
          EditorTool(id: 'timer', title: 'Timer', titleAr: 'مؤقت'),
          EditorTool(id: 'input', title: 'Input', titleAr: 'إدخال'),
          ...common,
        ];
      case GameType.puzzle:
        return const [
          ...common,
        ];
      case GameType.card:
        return const [
          EditorTool(id: 'card', title: 'Card', titleAr: 'بطاقة'),
          ...common,
        ];
      case GameType.clicker:
        return const [
          EditorTool(id: 'progress', title: 'Progress', titleAr: 'تقدم'),
          ...common,
        ];
      case GameType.custom:
        return common;
    }
  }
}
