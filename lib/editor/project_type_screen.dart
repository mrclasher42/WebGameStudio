import 'package:flutter/material.dart';
import '../models/game_type.dart';

class ProjectTypeScreen extends StatelessWidget {
  final bool arabic;
  final void Function(GameType) onSelected;

  const ProjectTypeScreen({
    super.key,
    required this.arabic,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final types = GameType.values;

    return Scaffold(
      appBar: AppBar(
        title: Text(arabic ? 'نوع اللعبة' : 'Game Type'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 150,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: types.length,
        itemBuilder: (context, index) {
          final type = types[index];

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                onSelected(type);
                Navigator.pop(context);
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videogame_asset, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      arabic ? type.arabicTitle : type.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
