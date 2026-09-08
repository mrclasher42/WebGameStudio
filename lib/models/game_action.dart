class GameAction {
  String type;
  String targetId;
  Map<String, dynamic> data;

  GameAction({
    required this.type,
    this.targetId = '',
    Map<String, dynamic>? data,
  }) : data = data ?? {};

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'targetId': targetId,
      'data': data,
    };
  }

  factory GameAction.fromMap(Map<String, dynamic> map) {
    return GameAction(
      type: map['type']?.toString() ?? 'none',
      targetId: map['targetId']?.toString() ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
    );
  }
}
