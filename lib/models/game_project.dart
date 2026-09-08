import 'game_object.dart';
import 'game_type.dart';

class GameScene {
  String name;
  List<GameObject> objects;

  GameScene({
    this.name = 'Scene',
    List<GameObject>? objects,
  }) : objects = objects ?? [];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'objects': objects.map((e) => e.toMap()).toList(),
    };
  }

  factory GameScene.fromMap(Map<String, dynamic> map) {
    return GameScene(
      name: map['name']?.toString() ?? 'Scene',
      objects: ((map['objects'] ?? []) as List)
          .map((e) => GameObject.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class GameProject {
  String name;
  GameType gameType;
  double width;
  double height;
  String globalCss;
  String globalLogic;
  String music;
  List<GameScene> scenes;

  GameProject({
    this.name = 'My Game',
    this.gameType = GameType.custom,
    this.width = 1280,
    this.height = 720,
    this.globalCss = '',
    this.globalLogic = '',
    this.music = '',
    List<GameScene>? scenes,
  }) : scenes = scenes ?? [GameScene(name: 'Main')];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gameType': gameType.id,
      'width': width,
      'height': height,
      'globalCss': globalCss,
      'globalLogic': globalLogic,
      'music': music,
      'scenes': scenes.map((e) => e.toMap()).toList(),
    };
  }

  factory GameProject.fromMap(Map<String, dynamic> map) {
    final rawScenes = (map['scenes'] ?? []) as List;

    return GameProject(
      name: map['name']?.toString() ?? 'My Game',
      gameType: GameTypeInfo.fromId(map['gameType']),
      width: (map['width'] as num?)?.toDouble() ?? 1280,
      height: (map['height'] as num?)?.toDouble() ?? 720,
      globalCss: map['globalCss']?.toString() ?? '',
      globalLogic: map['globalLogic']?.toString() ?? '',
      music: map['music']?.toString() ?? '',
      scenes: rawScenes
          .map((e) => GameScene.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
