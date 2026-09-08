import 'package:flutter/material.dart';

import '../models/game_action.dart';
import '../models/game_event.dart';
import '../models/game_object.dart';
import '../models/game_project.dart';
import '../models/game_type.dart';
import '../models/game_variable.dart';
import '../runtime/game_runtime.dart';
import '../services/project_storage.dart';
import '../screens/settings_screen.dart';
import 'editor_tools.dart';
import 'project_type_screen.dart';

class EditorScreen extends StatefulWidget {
  final bool arabic;
  final bool darkMode;
  final ValueChanged<bool> onLanguageChanged;
  final ValueChanged<bool> onThemeChanged;

  const EditorScreen({
    super.key,
    required this.arabic,
    required this.darkMode,
    required this.onLanguageChanged,
    required this.onThemeChanged,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late GameProject project;
  String? selectedId;
  bool propertiesVisible = true;

  @override
  void initState() {
    super.initState();
    project = GameProject();
  }

  GameObject? get selected {
    for (final object in project.objects) {
      if (object.id == selectedId) return object;
    }
    return null;
  }

  List<EditorTool> get tools => EditorTools.forType(project.gameType);

  void createProject(GameType type) {
    setState(() {
      project = GameProject(
        name: 'My Game',
        gameType: type,
      );
      selectedId = null;
      propertiesVisible = true;
    });
  }

  GameObject makeObject(EditorTool tool) {
    final index = project.objects.length;
    final data = <String, dynamic>{
      'color': 0xff4f46e5,
    };

    if (tool.id == 'text') data['text'] = 'Text';
    if (tool.id == 'button') data['text'] = 'Button';
    if (tool.id == 'input') data['placeholder'] = 'Enter text';
    if (tool.id == 'image') data['source'] = '';
    if (tool.id == 'question') {
      data['question'] = 'Question';
      data['answers'] = ['', '', '', ''];
      data['correct'] = 0;
    }
    if (tool.id == 'progress') data['value'] = 50;
    if (tool.id == 'timer') data['seconds'] = 60;

    return GameObject(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: tool.id,
      x: 120 + index * 24,
      y: 120 + index * 24,
      width: tool.id == 'text' ? 220 : 180,
      height: tool.id == 'text' ? 60 : 90,
      data: data,
    );
  }

  void addTool(EditorTool tool) {
    final object = makeObject(tool);
    setState(() {
      project.objects.add(object);
      selectedId = object.id;
      propertiesVisible = true;
    });
  }

  Future<void> save() async {
    await ProjectStorage.save(project);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.arabic ? 'تم حفظ المشروع' : 'Project saved',
        ),
      ),
    );
  }

  Future<void> load() async {
    final loaded = await ProjectStorage.load();
    if (loaded == null) return;
    setState(() {
      project = loaded;
      selectedId = null;
      propertiesVisible = true;
    });
  }

  void deleteSelected() {
    if (selectedId == null) return;
    setState(() {
      project.objects.removeWhere((o) => o.id == selectedId);
      selectedId = null;
    });
  }

  Color colorFor(GameObject object) {
    final value = object.data['color'];
    if (value is int) return Color(value);
    return const Color(0xff4f46e5);
  }

  Widget objectVisual(GameObject object) {
    final color = colorFor(object);

    switch (object.type) {
      case 'text':
        return Text(
          object.data['text']?.toString() ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        );
      case 'button':
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            object.data['text']?.toString() ?? 'Button',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case 'player':
        return CustomPaint(painter: CharacterPainter(color));
      case 'platform':
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xff334155),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      case 'coin':
        return CustomPaint(painter: CoinPainter());
      case 'enemy':
        return CustomPaint(painter: EnemyPainter(color));
      case 'box':
        return CustomPaint(painter: BoxPainter());
      case 'grid':
        return CustomPaint(painter: GridObjectPainter());
      case 'cell':
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xff64748b), width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case 'card':
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 4),
                color: Color(0x33000000),
              ),
            ],
          ),
        );
      case 'progress':
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(color: const Color(0xff263241)),
              FractionallySizedBox(
                widthFactor:
                    ((object.data['value'] as num?)?.toDouble() ?? 50) / 100,
                child: Container(color: color),
              ),
            ],
          ),
        );
      case 'timer':
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xff1e293b),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            '${object.data['seconds'] ?? 60}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case 'input':
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            object.data['placeholder']?.toString() ?? '',
            style: const TextStyle(color: Colors.grey),
          ),
        );
      case 'image':
        return CustomPaint(painter: ImagePlaceholderPainter());
      case 'panel':
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xff1e293b),
            borderRadius: BorderRadius.circular(14),
          ),
        );
      case 'question':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xff172554),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            object.data['question']?.toString() ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      default:
        return Container(color: color);
    }
  }

  Widget buildCanvas() {
    return InteractiveViewer(
      minScale: .2,
      maxScale: 3,
      boundaryMargin: const EdgeInsets.all(600),
      child: SizedBox(
        width: project.worldWidth,
        height: project.worldHeight,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(project.worldWidth, project.worldHeight),
              painter: GridPainter(),
            ),
            ...project.objects.map(
              (object) {
                final selectedObject = object.id == selectedId;

                return Positioned(
                  left: object.x,
                  top: object.y,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedId = object.id;
                        propertiesVisible = true;
                      });
                    },
                    onPanStart: (_) {
                      setState(() {
                        selectedId = object.id;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        object.x += details.delta.dx;
                        object.y += details.delta.dy;
                      });
                    },
                    child: Transform.rotate(
                      angle: object.rotation * 3.1415926535 / 180,
                      child: Container(
                        width: object.width,
                        height: object.height,
                        decoration: selectedObject
                            ? BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xff60a5fa),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                        child: objectVisual(object),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget field(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: TextEditingController(text: value),
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget smartProperties(GameObject object) {
    if (object.type == 'text') {
      return field(
        widget.arabic ? 'النص' : 'Text',
        object.data['text']?.toString() ?? '',
        (value) {
          object.data['text'] = value;
          setState(() {});
        },
        maxLines: 3,
      );
    }

    if (object.type == 'button') {
      return field(
        widget.arabic ? 'نص الزر' : 'Button text',
        object.data['text']?.toString() ?? '',
        (value) {
          object.data['text'] = value;
          setState(() {});
        },
      );
    }

    if (object.type == 'input') {
      return field(
        widget.arabic ? 'النص التوضيحي' : 'Placeholder',
        object.data['placeholder']?.toString() ?? '',
        (value) {
          object.data['placeholder'] = value;
          setState(() {});
        },
      );
    }

    if (object.type == 'question') {
      final answers = List<String>.from(
        object.data['answers'] ?? ['', '', '', ''],
      );

      return Column(
        children: [
          field(
            widget.arabic ? 'السؤال' : 'Question',
            object.data['question']?.toString() ?? '',
            (value) {
              object.data['question'] = value;
              setState(() {});
            },
            maxLines: 3,
          ),
          ...List.generate(
            4,
            (index) => field(
              '${widget.arabic ? 'الإجابة' : 'Answer'} ${index + 1}',
              answers[index],
              (value) {
                answers[index] = value;
                object.data['answers'] = answers;
                setState(() {});
              },
            ),
          ),
          DropdownButtonFormField<int>(
            value: (object.data['correct'] as num?)?.toInt() ?? 0,
            decoration: InputDecoration(
              labelText: widget.arabic
                  ? 'الإجابة الصحيحة'
                  : 'Correct answer',
              border: const OutlineInputBorder(),
            ),
            items: List.generate(
              4,
              (index) => DropdownMenuItem(
                value: index,
                child: Text(
                  '${widget.arabic ? 'الإجابة' : 'Answer'} ${index + 1}',
                ),
              ),
            ),
            onChanged: (value) {
              object.data['correct'] = value ?? 0;
              setState(() {});
            },
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String eventName(String trigger) {
    switch (trigger) {
      case 'onTap':
        return widget.arabic ? 'عند الضغط' : 'On Tap';
      case 'onPress':
        return widget.arabic ? 'عند الضغط المستمر' : 'On Press';
      case 'onKey':
        return widget.arabic ? 'عند ضغط زر الكيبورد' : 'On Key';
      case 'onStart':
        return widget.arabic ? 'عند بدء اللعبة' : 'On Start';
      case 'onCollision':
        return widget.arabic ? 'عند الاصطدام' : 'On Collision';
      default:
        return trigger;
    }
  }

  String actionName(String type) {
    switch (type) {
      case 'move':
        return widget.arabic ? 'تحريك عنصر' : 'Move Object';
      case 'setText':
        return widget.arabic ? 'تغيير النص' : 'Set Text';
      case 'changeVariable':
        return widget.arabic ? 'تغيير متغير' : 'Change Variable';
      case 'show':
        return widget.arabic ? 'إظهار عنصر' : 'Show Object';
      case 'hide':
        return widget.arabic ? 'إخفاء عنصر' : 'Hide Object';
      case 'destroy':
        return widget.arabic ? 'حذف عنصر' : 'Destroy Object';
      default:
        return type;
    }
  }

  List<String> availableActions() {
    return [
      'move',
      'setText',
      'changeVariable',
      'show',
      'hide',
      'destroy',
    ];
  }

  void addEvent() {
    final object = selected;
    if (object == null) return;

    setState(() {
      object.events.add(
        GameEvent(
          trigger: 'onTap',
          actions: [
            GameAction(
              type: 'move',
              targetId: object.id,
              data: {
                'dx': 50,
                'dy': 0,
              },
            ),
          ],
        ),
      );
    });
  }

  void addAction(GameEvent event) {
    setState(() {
      event.actions.add(
        GameAction(
          type: 'move',
          targetId: selected?.id ?? '',
          data: {
            'dx': 50,
            'dy': 0,
          },
        ),
      );
    });
  }

  Widget logicPanel(GameObject object) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.arabic ? 'المنطق والسلوك' : 'Logic & Behavior',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: addEvent,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: widget.arabic ? 'إضافة حدث' : 'Add event',
            ),
          ],
        ),
        if (object.events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              widget.arabic
                  ? 'هذا العنصر لا يملك أي سلوك بعد.'
                  : 'This object has no behavior yet.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ...object.events.asMap().entries.map(
          (entry) {
            final eventIndex = entry.key;
            final event = entry.value;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: event.trigger,
                            decoration: InputDecoration(
                              labelText:
                                  widget.arabic ? 'الحدث' : 'Event',
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              'onTap',
                              'onPress',
                              'onKey',
                              'onStart',
                              'onCollision',
                            ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(eventName(value)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => event.trigger = value);
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              object.events.removeAt(eventIndex);
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...event.actions.asMap().entries.map(
                      (actionEntry) {
                        final actionIndex = actionEntry.key;
                        final action = actionEntry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: availableActions()
                                                  .contains(action.type)
                                              ? action.type
                                              : 'move',
                                          decoration: InputDecoration(
                                            labelText: widget.arabic
                                                ? 'الإجراء'
                                                : 'Action',
                                            border:
                                                const OutlineInputBorder(),
                                          ),
                                          items: availableActions()
                                              .map(
                                                (value) =>
                                                    DropdownMenuItem(
                                                  value: value,
                                                  child: Text(
                                                    actionName(value),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setState(() {
                                              action.type = value;
                                            });
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            event.actions
                                                .removeAt(actionIndex);
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.close,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (action.type == 'move')
                                    Row(
                                      children: [
                                        Expanded(
                                          child: field(
                                            'DX',
                                            '${action.data['dx'] ?? 50}',
                                            (value) {
                                              action.data['dx'] =
                                                  double.tryParse(value) ?? 0;
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: field(
                                            'DY',
                                            '${action.data['dy'] ?? 0}',
                                            (value) {
                                              action.data['dy'] =
                                                  double.tryParse(value) ?? 0;
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (action.type == 'setText')
                                    field(
                                      widget.arabic
                                          ? 'النص الجديد'
                                          : 'New text',
                                      action.data['text']?.toString() ?? '',
                                      (value) {
                                        action.data['text'] = value;
                                        setState(() {});
                                      },
                                    ),
                                  if (action.type == 'changeVariable')
                                    Column(
                                      children: [
                                        DropdownButtonFormField<String>(
                                          value: project.variables.isEmpty
                                              ? null
                                              : action.data['variable']
                                                      ?.toString() ??
                                                  project
                                                      .variables.first.name,
                                          decoration: InputDecoration(
                                            labelText: widget.arabic
                                                ? 'المتغير'
                                                : 'Variable',
                                            border:
                                                const OutlineInputBorder(),
                                          ),
                                          items: project.variables
                                              .map(
                                                (variable) =>
                                                    DropdownMenuItem(
                                                  value: variable.name,
                                                  child:
                                                      Text(variable.name),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            action.data['variable'] = value;
                                            setState(() {});
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        field(
                                          widget.arabic
                                              ? 'القيمة'
                                              : 'Amount',
                                          '${action.data['amount'] ?? 1}',
                                          (value) {
                                            action.data['amount'] =
                                                double.tryParse(value) ?? 0;
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  if (action.type == 'move' ||
                                      action.type == 'setText' ||
                                      action.type == 'show' ||
                                      action.type == 'hide' ||
                                      action.type == 'destroy')
                                    DropdownButtonFormField<String>(
                                      value: project.objects.any(
                                              (o) =>
                                                  o.id ==
                                                  action.targetId)
                                          ? action.targetId
                                          : object.id,
                                      decoration: InputDecoration(
                                        labelText: widget.arabic
                                            ? 'العنصر المستهدف'
                                            : 'Target object',
                                        border:
                                            const OutlineInputBorder(),
                                      ),
                                      items: project.objects
                                          .map(
                                            (target) =>
                                                DropdownMenuItem(
                                              value: target.id,
                                              child: Text(
                                                target.type,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        action.targetId =
                                            value ?? object.id;
                                        setState(() {});
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    TextButton.icon(
                      onPressed: () => addAction(event),
                      icon: const Icon(Icons.add),
                      label: Text(
                        widget.arabic ? 'إضافة إجراء' : 'Add action',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () {
            setState(() {
              project.variables.add(
                GameVariable(
                  name: 'Score${project.variables.length + 1}',
                  type: 'number',
                  value: 0,
                ),
              );
            });
          },
          icon: const Icon(Icons.data_object),
          label: Text(
            widget.arabic ? 'إضافة متغير' : 'Add variable',
          ),
        ),
      ],
    );
  }

  Widget propertiesPanel() {
    final object = selected;
    if (object == null || !propertiesVisible) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      object.type,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => propertiesVisible = false);
                    },
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  IconButton(
                    onPressed: deleteSelected,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              smartProperties(object),
              const SizedBox(height: 8),
              _slider(
                'X',
                object.x,
                0,
                project.worldWidth,
                (v) => setState(() => object.x = v),
              ),
              _slider(
                'Y',
                object.y,
                0,
                project.worldHeight,
                (v) => setState(() => object.y = v),
              ),
              _slider(
                'Width',
                object.width,
                20,
                600,
                (v) => setState(() => object.width = v),
              ),
              _slider(
                'Height',
                object.height,
                20,
                600,
                (v) => setState(() => object.height = v),
              ),
              _slider(
                'Rotation',
                object.rotation,
                -180,
                180,
                (v) => setState(() => object.rotation = v),
              ),
              logicPanel(object),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '$label ${value.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void openAddMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: tools.map(
              (tool) {
                return ListTile(
                  leading: Icon(iconForTool(tool.id)),
                  title: Text(
                    widget.arabic ? tool.titleAr : tool.title,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    addTool(tool);
                  },
                );
              },
            ).toList(),
          ),
        );
      },
    );
  }

  IconData iconForTool(String id) {
    switch (id) {
      case 'player':
        return Icons.person_outline;
      case 'platform':
        return Icons.horizontal_rule;
      case 'coin':
        return Icons.circle_outlined;
      case 'enemy':
        return Icons.smart_toy_outlined;
      case 'box':
        return Icons.crop_square;
      case 'grid':
        return Icons.grid_4x4;
      case 'cell':
        return Icons.check_box_outline_blank;
      case 'question':
        return Icons.help_outline;
      case 'image':
        return Icons.image_outlined;
      case 'button':
        return Icons.smart_button_outlined;
      case 'text':
        return Icons.text_fields;
      case 'input':
        return Icons.input;
      case 'card':
        return Icons.credit_card;
      case 'progress':
        return Icons.linear_scale;
      case 'timer':
        return Icons.timer_outlined;
      case 'panel':
        return Icons.dashboard_outlined;
      default:
        return Icons.crop_square;
    }
  }

  void openType() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectTypeScreen(
          arabic: widget.arabic,
          onSelected: createProject,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            onPressed: openType,
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    arabic: widget.arabic,
                    darkMode: widget.darkMode,
                    onLanguageChanged: widget.onLanguageChanged,
                    onThemeChanged: widget.onThemeChanged,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameRuntime(project: project),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: buildCanvas()),
          propertiesPanel(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff27303b)
      ..strokeWidth = 1;

    const step = 50.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CharacterPainter extends CustomPainter {
  final Color color;

  CharacterPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = Offset(size.width / 2, size.height * .28);
    canvas.drawCircle(center, size.width * .16, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .25,
          size.height * .38,
          size.width * .5,
          size.height * .42,
        ),
        const Radius.circular(10),
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .25,
        size.height * .78,
        size.width * .18,
        size.height * .18,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .57,
        size.height * .78,
        size.width * .18,
        size.height * .18,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CharacterPainter oldDelegate) => false;
}

class CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xffffc107);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .38;
    canvas.drawCircle(center, radius, paint);
    final inner = Paint()
      ..color = const Color(0xff8a5a00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius * .68, inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EnemyPainter extends CustomPainter {
  final Color color;

  EnemyPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .75)
      ..lineTo(size.width * .2, size.height * .22)
      ..lineTo(size.width * .38, size.height * .38)
      ..lineTo(size.width * .5, size.height * .18)
      ..lineTo(size.width * .62, size.height * .38)
      ..lineTo(size.width * .8, size.height * .22)
      ..lineTo(size.width * .88, size.height * .75)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffa16207)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .08,
        size.height * .08,
        size.width * .84,
        size.height * .84,
      ),
      paint,
    );
    final line = Paint()
      ..color = const Color(0xfffacc15)
      ..strokeWidth = 5;
    canvas.drawLine(
      Offset(size.width * .2, size.height * .2),
      Offset(size.width * .8, size.height * .8),
      line,
    );
    canvas.drawLine(
      Offset(size.width * .8, size.height * .2),
      Offset(size.width * .2, size.height * .8),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GridObjectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff64748b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cellW = size.width / 3;
    final cellH = size.height / 3;

    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(cellW * i, 0),
        Offset(cellW * i, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, cellH * i),
        Offset(size.width, cellH * i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ImagePlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff334155);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      paint,
    );

    final mountain = Path()
      ..moveTo(size.width * .1, size.height * .8)
      ..lineTo(size.width * .4, size.height * .42)
      ..lineTo(size.width * .58, size.height * .65)
      ..lineTo(size.width * .7, size.height * .48)
      ..lineTo(size.width * .92, size.height * .8)
      ..close();

    canvas.drawPath(
      mountain,
      Paint()..color = const Color(0xff64748b),
    );

    canvas.drawCircle(
      Offset(size.width * .75, size.height * .28),
      size.shortestSide * .08,
      Paint()..color = const Color(0xff94a3b8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
