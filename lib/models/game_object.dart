class GameObject {
  final String id;
  String type;
  double x;
  double y;
  double width;
  double height;
  double rotation;
  Map<String, dynamic> data;

  GameObject({
    required this.id,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 100,
    this.height = 70,
    this.rotation = 0,
    Map<String, dynamic>? data,
  }) : data = data ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'data': data,
    };
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  factory GameObject.fromMap(Map<String, dynamic> map) {
    return GameObject(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'shape',
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      width: (map['width'] as num?)?.toDouble() ?? 100,
      height: (map['height'] as num?)?.toDouble() ?? 70,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0,
      data: Map<String, dynamic>.from(map['data'] ?? {}),
    );
  }

  factory GameObject.fromJson(Map<String, dynamic> json) {
    return GameObject.fromMap(json);
  }
}
