import 'game_object.dart';
import 'game_type.dart';

class GameProject {
  String name;
  GameType gameType;
  double worldWidth;
  double worldHeight;
  List<GameObject> objects;

  GameProject({
    this.name = 'My Game',
    this.gameType = GameType.custom,
    this.worldWidth = 2400,
    this.worldHeight = 1400,
    List<GameObject>? objects,
  }) : objects = objects ?? [];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gameType': gameType.id,
      'worldWidth': worldWidth,
      'worldHeight': worldHeight,
      'objects': objects.map((e) => e.toMap()).toList(),
    };
  }

  factory GameProject.fromMap(Map<String, dynamic> map) {
    return GameProject(
      name: map['name'] ?? 'My Game',
      gameType: GameTypeExtension.fromId(map['gameType']),
      worldWidth: (map['worldWidth'] ?? 2400).toDouble(),
      worldHeight: (map['worldHeight'] ?? 1400).toDouble(),
      objects: ((map['objects'] ?? []) as List)
          .map(
            (e) => GameObject.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}
