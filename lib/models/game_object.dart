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
    this.height = 100,
    this.rotation = 0,
    Map<String, dynamic>? data,
  }) : data = data ?? {};

  Map<String, dynamic> toJson() {
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

  factory GameObject.fromJson(Map<String, dynamic> json) {
    return GameObject(
      id: json['id'] as String,
      type: json['type'] as String,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 100,
      height: (json['height'] as num?)?.toDouble() ?? 100,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}
