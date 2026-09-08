import 'game_action.dart';

class GameEvent {
  String trigger;
  List<GameAction> actions;

  GameEvent({
    required this.trigger,
    List<GameAction>? actions,
  }) : actions = actions ?? [];

  Map<String, dynamic> toMap() {
    return {
      'trigger': trigger,
      'actions': actions.map((e) => e.toMap()).toList(),
    };
  }

  factory GameEvent.fromMap(Map<String, dynamic> map) {
    return GameEvent(
      trigger: map['trigger']?.toString() ?? 'onStart',
      actions: ((map['actions'] ?? []) as List)
          .map(
            (e) => GameAction.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}
