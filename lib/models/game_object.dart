import 'dart:convert';

class GameObject {
  String id;
  String type;
  double x;
  double y;
  double width;
  double height;
  double rotation;

  GameObject({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
    };
  }

  factory GameObject.fromMap(Map<String, dynamic> map) {
    return GameObject(
      id: map['id'],
      type: map['type'],
      x: (map['x'] ?? 0).toDouble(),
      y: (map['y'] ?? 0).toDouble(),
      width: (map['width'] ?? 60).toDouble(),
      height: (map['height'] ?? 60).toDouble(),
      rotation: (map['rotation'] ?? 0).toDouble(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GameObject.fromJson(String value) {
    return GameObject.fromMap(jsonDecode(value));
  }
}
