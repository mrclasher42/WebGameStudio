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
  static List<EditorTool> forType(GameType type) {
    switch (type) {
      case GameType.platformer:
        return const [
          EditorTool(
            id: 'player',
            title: 'Player',
            titleAr: 'شخصية',
          ),
          EditorTool(
            id: 'platform',
            title: 'Platform',
            titleAr: 'منصة',
          ),
          EditorTool(
            id: 'coin',
            title: 'Coin',
            titleAr: 'عملة',
          ),
          EditorTool(
            id: 'enemy',
            title: 'Enemy',
            titleAr: 'عدو',
          ),
          EditorTool(
            id: 'box',
            title: 'Box',
            titleAr: 'صندوق',
          ),
        ];

      case GameType.ticTacToe:
        return const [
          EditorTool(
            id: 'grid',
            title: 'Grid',
            titleAr: 'شبكة',
          ),
          EditorTool(
            id: 'cell',
            title: 'Cell',
            titleAr: 'خلية',
          ),
          EditorTool(
            id: 'button',
            title: 'Button',
            titleAr: 'زر',
          ),
          EditorTool(
            id: 'text',
            title: 'Text',
            titleAr: 'نص',
          ),
          EditorTool(
            id: 'shape',
            title: 'Shape',
            titleAr: 'شكل',
          ),
        ];

      case GameType.quiz:
        return const [
          EditorTool(
            id: 'text',
            title: 'Text',
            titleAr: 'نص',
          ),
          EditorTool(
            id: 'button',
            title: 'Button',
            titleAr: 'زر',
          ),
          EditorTool(
            id: 'image',
            title: 'Image',
            titleAr: 'صورة',
          ),
          EditorTool(
            id: 'panel',
            title: 'Panel',
            titleAr: 'لوحة',
          ),
          EditorTool(
            id: 'progress',
            title: 'Progress',
            titleAr: 'تقدم',
          ),
          EditorTool(
            id: 'timer',
            title: 'Timer',
            titleAr: 'مؤقت',
          ),
          EditorTool(
            id: 'input',
            title: 'Input',
            titleAr: 'إدخال',
          ),
        ];

      case GameType.puzzle:
        return const [
          EditorTool(
            id: 'shape',
            title: 'Shape',
            titleAr: 'شكل',
          ),
          EditorTool(
            id: 'text',
            title: 'Text',
            titleAr: 'نص',
          ),
          EditorTool(
            id: 'image',
            title: 'Image',
            titleAr: 'صورة',
          ),
          EditorTool(
            id: 'button',
            title: 'Button',
            titleAr: 'زر',
          ),
        ];

      case GameType.card:
        return const [
          EditorTool(
            id: 'card',
            title: 'Card',
            titleAr: 'بطاقة',
          ),
          EditorTool(
            id: 'text',
            title: 'Text',
            titleAr: 'نص',
          ),
          EditorTool(
            id: 'image',
            title: 'Image',
            titleAr: 'صورة',
          ),
          EditorTool(
            id: 'button',
            title: 'Button',
            titleAr: 'زر',
          ),
        ];

      case GameType.clicker:
        return const [
          EditorTool(
            id: 'button',
            title: 'Button',
            titleAr: 'زر',
          ),
          EditorTool(
            id: 'text',
            title: 'Text',
            titleAr: 'نص',
          ),
          EditorTool(
            id: 'image',
            title: 'Image',
            titleAr: 'صورة',
          ),
          EditorTool(
            id: 'progress',
            title: 'Progress',
            titleAr: 'تقدم',
          ),
        ];

      case GameType.custom:
        return const [
          EditorTool(
            id: 'text',
            title: 'Text',
            titleAr: 'نص',
          ),
          EditorTool(
            id: 'button',
            title: 'Button',
            titleAr: 'زر',
          ),
          EditorTool(
            id: 'image',
            title: 'Image',
            titleAr: 'صورة',
          ),
          EditorTool(
            id: 'shape',
            title: 'Shape',
            titleAr: 'شكل',
          ),
          EditorTool(
            id: 'panel',
            title: 'Panel',
            titleAr: 'لوحة',
          ),
        ];
    }
  }
}
