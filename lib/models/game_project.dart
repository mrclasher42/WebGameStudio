import 'game_object.dart';
import 'game_type.dart';
import 'game_variable.dart';

class GameProject {
  String name;
  GameType gameType;
  double worldWidth;
  double worldHeight;
  List<GameObject> objects;
  List<GameVariable> variables;

  GameProject({
    this.name = 'My Game',
    this.gameType = GameType.custom,
    this.worldWidth = 2400,
    this.worldHeight = 1400,
    List<GameObject>? objects,
    List<GameVariable>? variables,
  })  : objects = objects ?? [],
        variables = variables ?? [];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gameType': gameType.id,
      'worldWidth': worldWidth,
      'worldHeight': worldHeight,
      'objects': objects.map((e) => e.toMap()).toList(),
      'variables': variables.map((e) => e.toMap()).toList(),
    };
  }

  factory GameProject.fromMap(Map<String, dynamic> map) {
    return GameProject(
      name: map['name']?.toString() ?? 'My Game',
      gameType: GameTypeExtension.fromId(map['gameType']),
      worldWidth: (map['worldWidth'] as num?)?.toDouble() ?? 2400,
      worldHeight: (map['worldHeight'] as num?)?.toDouble() ?? 1400,
      objects: ((map['objects'] ?? []) as List)
          .map(
            (e) => GameObject.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      variables: ((map['variables'] ?? []) as List)
          .map(
            (e) => GameVariable.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}
