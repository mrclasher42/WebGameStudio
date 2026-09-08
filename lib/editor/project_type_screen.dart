import 'package:flutter/material.dart';
import '../models/game_type.dart';

class ProjectTypeScreen extends StatelessWidget {
  final bool arabic;
  final ValueChanged<GameType> onSelected;

  const ProjectTypeScreen({
    super.key,
    required this.arabic,
    required this.onSelected,
  });

  IconData iconFor(GameType type) {
    switch (type) {
      case GameType.platformer:
        return Icons.directions_run;
      case GameType.ticTacToe:
        return Icons.grid_3x3;
      case GameType.quiz:
        return Icons.quiz_outlined;
      case GameType.puzzle:
        return Icons.extension_outlined;
      case GameType.card:
        return Icons.style_outlined;
      case GameType.clicker:
        return Icons.touch_app_outlined;
      case GameType.custom:
        return Icons.auto_awesome_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = GameType.values;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          arabic ? 'نوع اللعبة' : 'Game Type',
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: types.length,
        itemBuilder: (context, index) {
          final type = types[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                onSelected(type);
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        iconFor(type),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            arabic
                                ? type.titleAr
                                : type.titleEn,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            arabic
                                ? type.descriptionAr
                                : type.descriptionEn,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
