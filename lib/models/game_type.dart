enum GameType {
  platformer,
  quiz,
  puzzle,
  card,
  clicker,
  ticTacToe,
  custom,
}

extension GameTypeInfo on GameType {
  String get id => name;

  String get title {
    switch (this) {
      case GameType.platformer:
        return 'Platformer';
      case GameType.quiz:
        return 'Quiz';
      case GameType.puzzle:
        return 'Puzzle';
      case GameType.card:
        return 'Card';
      case GameType.clicker:
        return 'Clicker';
      case GameType.ticTacToe:
        return 'Tic Tac Toe';
      case GameType.custom:
        return 'Custom';
    }
  }

  String get arabicTitle {
    switch (this) {
      case GameType.platformer:
        return 'منصات';
      case GameType.quiz:
        return 'أسئلة';
      case GameType.puzzle:
        return 'ألغاز';
      case GameType.card:
        return 'بطاقات';
      case GameType.clicker:
        return 'نقر';
      case GameType.ticTacToe:
        return 'إكس أو';
      case GameType.custom:
        return 'مخصص';
    }
  }

  static GameType fromId(dynamic value) {
    return GameType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GameType.custom,
    );
  }
}
