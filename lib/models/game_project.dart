import 'game_object.dart';

class GameProject {
  String name;
  double worldWidth;
  double worldHeight;
  List<GameObject> objects;

  GameProject({
    this.name = 'My Game',
    this.worldWidth = 2400,
    this.worldHeight = 1400,
    List<GameObject>? objects,
  }) : objects = objects ?? [];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'worldWidth': worldWidth,
      'worldHeight': worldHeight,
      'objects': objects.map((e) => e.toMap()).toList(),
    };
  }

  factory GameProject.fromMap(Map<String, dynamic> map) {
    return GameProject(
      name: map['name'] ?? 'My Game',
      worldWidth: (map['worldWidth'] ?? 2400).toDouble(),
      worldHeight: (map['worldHeight'] ?? 1400).toDouble(),
      objects: ((map['objects'] ?? []) as List)
          .map((e) => GameObject.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
