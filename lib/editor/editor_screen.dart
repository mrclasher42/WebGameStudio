import 'package:flutter/material.dart';
import '../models/game_object.dart';
import '../models/game_project.dart';
import '../runtime/game_runtime.dart';
import '../services/project_storage.dart';
import '../screens/settings_screen.dart';

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

  void addObject(String type) {
    final object = GameObject(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      x: 120 + project.objects.length * 20,
      y: 150,
      width: type == 'Platform' ? 180 : 60,
      height: type == 'Platform' ? 40 : 60,
    );

    setState(() {
      project.objects.add(object);
      selectedId = object.id;
    });
  }

  Future<void> save() async {
    await ProjectStorage.save(project);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.arabic ? 'تم الحفظ ✅' : 'Project saved ✅'),
      ),
    );
  }

  Future<void> load() async {
    final loaded = await ProjectStorage.load();

    if (loaded == null) return;

    setState(() {
      project = loaded;
      selectedId = null;
    });
  }

  void deleteSelected() {
    if (selectedId == null) return;

    setState(() {
      project.objects.removeWhere((o) => o.id == selectedId);
      selectedId = null;
    });
  }

  Color objectColor(String type) {
    switch (type) {
      case 'Player':
        return Colors.lightBlue;
      case 'Platform':
        return Colors.brown;
      case 'Coin':
        return Colors.amber;
      case 'Enemy':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget buildCanvas() {
    return InteractiveViewer(
      minScale: 0.25,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(500),
      child: SizedBox(
        width: project.worldWidth,
        height: project.worldHeight,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(project.worldWidth, project.worldHeight),
              painter: GridPainter(),
            ),
            ...project.objects.map((object) {
              final selected = object.id == selectedId;

              return Positioned(
                left: object.x,
                top: object.y,
                child: GestureDetector(
                  onTap: () {
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
                      decoration: BoxDecoration(
                        color: objectColor(object.type),
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(width: 3, color: Colors.white)
                            : null,
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  color: Colors.white24,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        object.type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget propertyPanel() {
    final object = selected;

    if (object == null) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            object.type,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text('X: ${object.x.toStringAsFixed(0)}'),
          Slider(
            value: object.x.clamp(0, project.worldWidth),
            min: 0,
            max: project.worldWidth,
            onChanged: (value) {
              setState(() {
                object.x = value;
              });
            },
          ),
          Text('Y: ${object.y.toStringAsFixed(0)}'),
          Slider(
            value: object.y.clamp(0, project.worldHeight),
            min: 0,
            max: project.worldHeight,
            onChanged: (value) {
              setState(() {
                object.y = value;
              });
            },
          ),
          Text('Width: ${object.width.toStringAsFixed(0)}'),
          Slider(
            value: object.width.clamp(20, 500),
            min: 20,
            max: 500,
            onChanged: (value) {
              setState(() {
                object.width = value;
              });
            },
          ),
          Text('Height: ${object.height.toStringAsFixed(0)}'),
          Slider(
            value: object.height.clamp(20, 500),
            min: 20,
            max: 500,
            onChanged: (value) {
              setState(() {
                object.height = value;
              });
            },
          ),
          Text('Rotation: ${object.rotation.toStringAsFixed(0)}°'),
          Slider(
            value: object.rotation,
            min: -180,
            max: 180,
            onChanged: (value) {
              setState(() {
                object.rotation = value;
              });
            },
          ),
          FilledButton.tonalIcon(
            onPressed: deleteSelected,
            icon: const Icon(Icons.delete),
            label: Text(widget.arabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
  }

  void openAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final items = [
          ['Player', Icons.person],
          ['Platform', Icons.view_agenda],
          ['Coin', Icons.monetization_on],
          ['Enemy', Icons.smart_toy],
          ['Box', Icons.inventory_2],
        ];

        return SafeArea(
          child: Wrap(
            children: items.map((item) {
              return ListTile(
                leading: Icon(item[1] as IconData),
                title: Text(item[0] as String),
                onTap: () {
                  Navigator.pop(context);
                  addObject(item[0] as String);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Game Studio'),
        actions: [
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            onPressed: save,
            icon: const Icon(Icons.save),
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
            icon: const Icon(Icons.settings),
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
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(10),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: buildCanvas(),
            ),
          ),
          propertyPanel(),
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
