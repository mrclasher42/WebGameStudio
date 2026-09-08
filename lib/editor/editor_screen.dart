import 'package:flutter/material.dart';

import '../models/game_object.dart';
import '../models/game_project.dart';
import '../models/game_type.dart';
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

  void selectObject(String id) {
    setState(() {
      selectedId = id;
      propertiesVisible = true;
    });
  }

  void deselectObject() {
    setState(() {
      selectedId = null;
    });
  }

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

    final data = <String, dynamic>{};

    if (tool.id == 'text') {
      data['text'] = 'New Text';
    }

    if (tool.id == 'button') {
      data['text'] = 'Button';
    }

    if (tool.id == 'image') {
      data['source'] = '';
    }

    if (tool.id == 'input') {
      data['placeholder'] = 'Enter text';
    }

    if (tool.id == 'question') {
      data['question'] = '';
      data['answers'] = <String>['', '', '', ''];
      data['correct'] = 0;
      data['points'] = 1;
      data['correctSound'] = true;
      data['wrongSound'] = true;
    }

    return GameObject(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: tool.id,
      x: 120 + index * 20,
      y: 120 + index * 20,
      width: tool.id == 'platform' ? 180 : 180,
      height: tool.id == 'text' ? 60 : 80,
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
          widget.arabic ? 'تم حفظ المشروع ✅' : 'Project saved ✅',
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

  Color objectColor(GameObject object) {
    final custom = object.data['color']?.toString();

    if (custom != null) {
      final value = int.tryParse(custom);
      if (value != null) {
        return Color(value);
      }
    }

    switch (object.type) {
      case 'player':
        return Colors.lightBlue;
      case 'platform':
        return Colors.brown;
      case 'coin':
        return Colors.amber;
      case 'enemy':
        return Colors.red;
      case 'button':
        return Colors.blue;
      case 'text':
        return Colors.deepPurple;
      case 'image':
        return Colors.green;
      case 'card':
        return Colors.orange;
      case 'question':
        return Colors.indigo;
      case 'progress':
        return Colors.teal;
      case 'timer':
        return Colors.indigoAccent;
      case 'input':
        return Colors.cyan;
      case 'panel':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String objectLabel(GameObject object) {
    if (object.type == 'text') {
      return object.data['text']?.toString() ?? '';
    }

    if (object.type == 'button') {
      return object.data['text']?.toString() ?? 'Button';
    }

    if (object.type == 'input') {
      return object.data['placeholder']?.toString() ?? 'Input';
    }

    if (object.type == 'question') {
      final question = object.data['question']?.toString() ?? '';
      return question.isEmpty ? 'Quiz Question' : question;
    }

    if (object.type == 'image') {
      return 'Image';
    }

    return object.type;
  }

  Widget buildCanvas() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: deselectObject,
      child: InteractiveViewer(
        minScale: 0.2,
        maxScale: 3,
        boundaryMargin: const EdgeInsets.all(600),
        child: SizedBox(
          width: project.worldWidth,
          height: project.worldHeight,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(
                  project.worldWidth,
                  project.worldHeight,
                ),
                painter: GridPainter(),
              ),
              ...project.objects.map(
                (object) {
                  final isSelected = object.id == selectedId;

                  return Positioned(
                    left: object.x,
                    top: object.y,
                    child: GestureDetector(
                      onTap: () => selectObject(object.id),
                      onPanStart: (_) => selectObject(object.id),
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
                          decoration: BoxDecoration(
                            color: objectColor(object),
                            borderRadius: BorderRadius.circular(
                              object.type == 'button' ||
                                      object.type == 'question'
                                  ? 14
                                  : 8,
                            ),
                            border: isSelected
                                ? Border.all(
                                    width: 3,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8),
                          child: object.type == 'text'
                              ? Text(
                                  objectLabel(object),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : FittedBox(
                                  child: Text(
                                    objectLabel(object),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget textEditor(
    GameObject object, {
    required String keyName,
    required String label,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(
      text: object.data[keyName]?.toString() ?? '',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          object.data[keyName] = value;
          setState(() {});
        },
      ),
    );
  }

  Widget smartProperties(GameObject object) {
    switch (object.type) {
      case 'text':
        return textEditor(
          object,
          keyName: 'text',
          label: widget.arabic ? 'النص' : 'Text',
          maxLines: 3,
        );

      case 'button':
        return textEditor(
          object,
          keyName: 'text',
          label: widget.arabic ? 'نص الزر' : 'Button text',
        );

      case 'input':
        return textEditor(
          object,
          keyName: 'placeholder',
          label: widget.arabic ? 'النص التوضيحي' : 'Placeholder',
        );

      case 'image':
        return textEditor(
          object,
          keyName: 'source',
          label: widget.arabic ? 'مصدر الصورة' : 'Image source',
        );

      case 'question':
        return Column(
          children: [
            textEditor(
              object,
              keyName: 'question',
              label: widget.arabic ? 'السؤال' : 'Question',
              maxLines: 3,
            ),
            ...List.generate(4, (index) {
              final answers =
                  List<String>.from(object.data['answers'] ?? ['', '', '', '']);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: TextEditingController(
                    text: answers[index],
                  ),
                  decoration: InputDecoration(
                    labelText: widget.arabic
                        ? 'الإجابة ${index + 1}'
                        : 'Answer ${index + 1}',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    answers[index] = value;
                    object.data['answers'] = answers;
                    setState(() {});
                  },
                ),
              );
            }),
            DropdownButtonFormField<int>(
              value: (object.data['correct'] as num?)?.toInt() ?? 0,
              decoration: InputDecoration(
                labelText:
                    widget.arabic ? 'الإجابة الصحيحة' : 'Correct answer',
                border: const OutlineInputBorder(),
              ),
              items: List.generate(
                4,
                (index) => DropdownMenuItem(
                  value: index,
                  child: Text(
                    widget.arabic
                        ? 'الإجابة ${index + 1}'
                        : 'Answer ${index + 1}',
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

      default:
        return const SizedBox.shrink();
    }
  }

  Widget propertyPanel() {
    final object = selected;

    if (object == null || !propertiesVisible) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 470),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(22),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      object.type,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        propertiesVisible = false;
                      });
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
              _slider(
                label: 'X',
                value: object.x.clamp(0, project.worldWidth),
                min: 0,
                max: project.worldWidth,
                onChanged: (value) {
                  setState(() => object.x = value);
                },
              ),
              _slider(
                label: 'Y',
                value: object.y.clamp(0, project.worldHeight),
                min: 0,
                max: project.worldHeight,
                onChanged: (value) {
                  setState(() => object.y = value);
                },
              ),
              _slider(
                label: 'Width',
                value: object.width.clamp(20, 500),
                min: 20,
                max: 500,
                onChanged: (value) {
                  setState(() => object.width = value);
                },
              ),
              _slider(
                label: 'Height',
                value: object.height.clamp(20, 500),
                min: 20,
                max: 500,
                onChanged: (value) {
                  setState(() => object.height = value);
                },
              ),
              _slider(
                label: 'Rotation',
                value: object.rotation,
                min: -180,
                max: 180,
                onChanged: (value) {
                  setState(() => object.rotation = value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 75,
          child: Text(
            '$label ${value.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: tools.map((tool) {
              return ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(
                  widget.arabic ? tool.titleAr : tool.title,
                ),
                onTap: () {
                  Navigator.pop(context);
                  addTool(tool);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void openGameTypeMenu() {
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
    final hasSelection = selected != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          project.gameType == GameType.custom
              ? 'Web Game Studio'
              : '${project.gameType.titleEn} Editor',
        ),
        actions: [
          if (hasSelection && !propertiesVisible)
            IconButton(
              onPressed: () {
                setState(() => propertiesVisible = true);
              },
              icon: const Icon(Icons.tune),
            ),
          IconButton(
            onPressed: openGameTypeMenu,
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.folder_open),
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
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: buildCanvas()),
          if (selected != null && propertiesVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: propertyPanel(),
            ),
          Positioned(
            right: 16,
            bottom: selected != null && propertiesVisible ? 490 : 16,
            child: FloatingActionButton(
              heroTag: 'add',
              onPressed: openAddMenu,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;

    const grid = 40.0;

    for (double x = 0; x <= size.width; x += grid) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y <= size.height; y += grid) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
