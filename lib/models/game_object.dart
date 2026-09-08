class GameObject {
  final String id;
  String name;
  String type;
  double x;
  double y;
  double width;
  double height;
  double rotation;
  String html;
  String css;
  String logic;
  String sound;
  Map<String, dynamic> data;

  GameObject({
    required this.id,
    this.name = 'Object',
    this.type = 'shape',
    this.x = 100,
    this.y = 100,
    this.width = 120,
    this.height = 80,
    this.rotation = 0,
    this.html = '<div></div>',
    this.css = '',
    this.logic = '',
    this.sound = '',
    Map<String, dynamic>? data,
  }) : data = data ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'html': html,
      'css': css,
      'logic': logic,
      'sound': sound,
      'data': data,
    };
  }

  factory GameObject.fromMap(Map<String, dynamic> map) {
    return GameObject(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Object',
      type: map['type']?.toString() ?? 'shape',
      x: (map['x'] as num?)?.toDouble() ?? 100,
      y: (map['y'] as num?)?.toDouble() ?? 100,
      width: (map['width'] as num?)?.toDouble() ?? 120,
      height: (map['height'] as num?)?.toDouble() ?? 80,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0,
      html: map['html']?.toString() ?? '<div></div>',
      css: map['css']?.toString() ?? '',
      logic: map['logic']?.toString() ?? '',
      sound: map['sound']?.toString() ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory GameObject.fromJson(Map<String, dynamic> json) {
    return GameObject.fromMap(json);
  }
}
