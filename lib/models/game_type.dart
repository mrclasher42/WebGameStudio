enum GameType {
  platformer,
  ticTacToe,
  quiz,
  puzzle,
  card,
  clicker,
  custom,
}

extension GameTypeExtension on GameType {
  String get id {
    switch (this) {
      case GameType.platformer:
        return 'platformer';
      case GameType.ticTacToe:
        return 'tictactoe';
      case GameType.quiz:
        return 'quiz';
      case GameType.puzzle:
        return 'puzzle';
      case GameType.card:
        return 'card';
      case GameType.clicker:
        return 'clicker';
      case GameType.custom:
        return 'custom';
    }
  }

  String get titleAr {
    switch (this) {
      case GameType.platformer:
        return 'Platformer';
      case GameType.ticTacToe:
        return 'Tic-Tac-Toe';
      case GameType.quiz:
        return 'Quiz';
      case GameType.puzzle:
        return 'Puzzle';
      case GameType.card:
        return 'Card Game';
      case GameType.clicker:
        return 'Clicker';
      case GameType.custom:
        return 'Custom';
    }
  }

  String get titleEn {
    switch (this) {
      case GameType.platformer:
        return 'Platformer';
      case GameType.ticTacToe:
        return 'Tic-Tac-Toe';
      case GameType.quiz:
        return 'Quiz';
      case GameType.puzzle:
        return 'Puzzle';
      case GameType.card:
        return 'Card Game';
      case GameType.clicker:
        return 'Clicker';
      case GameType.custom:
        return 'Custom';
    }
  }

  String get descriptionAr {
    switch (this) {
      case GameType.platformer:
        return 'ألعاب الشخصية والحركة';
      case GameType.ticTacToe:
        return 'ألعاب الخلايا والأدوار';
      case GameType.quiz:
        return 'أسئلة وإجابات واختبارات';
      case GameType.puzzle:
        return 'ألعاب الألغاز والمنطق';
      case GameType.card:
        return 'ألعاب البطاقات';
      case GameType.clicker:
        return 'ألعاب الضغط والتجميع';
      case GameType.custom:
        return 'ابدأ من أدوات عامة';
    }
  }

  String get descriptionEn {
    switch (this) {
      case GameType.platformer:
        return 'Character and movement games';
      case GameType.ticTacToe:
        return 'Grid and turn-based games';
      case GameType.quiz:
        return 'Questions, answers and quizzes';
      case GameType.puzzle:
        return 'Puzzle and logic games';
      case GameType.card:
        return 'Card games';
      case GameType.clicker:
        return 'Click and collection games';
      case GameType.custom:
        return 'Start with general tools';
    }
  }

  static GameType fromId(String? value) {
    switch (value) {
      case 'platformer':
        return GameType.platformer;
      case 'tictactoe':
        return GameType.ticTacToe;
      case 'quiz':
        return GameType.quiz;
      case 'puzzle':
        return GameType.puzzle;
      case 'card':
        return GameType.card;
      case 'clicker':
        return GameType.clicker;
      default:
        return GameType.custom;
    }
  }
}
