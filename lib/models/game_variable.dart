class GameVariable {
  String name;
  String type;
  dynamic value;

  GameVariable({
    required this.name,
    this.type = 'number',
    this.value = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'value': value,
    };
  }

  factory GameVariable.fromMap(Map<String, dynamic> map) {
    return GameVariable(
      name: map['name']?.toString() ?? 'Variable',
      type: map['type']?.toString() ?? 'number',
      value: map['value'],
    );
  }
}
