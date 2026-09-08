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
  bool propertiesVisible = true;

  @override
  void initState() {
    super.initState();
    project = GameProject();
  }

  GameObject? get selected {
    for (final object in project.objects) {
      if (object.id == selectedId) {
        return object;
      }
    }
    return null;
  }

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: deselectObject,
      child: InteractiveViewer(
        minScale: 0.2,
        maxScale: 3,
        boundaryMargin: const EdgeInsets.all(600),
        panEnabled: true,
        scaleEnabled: true,
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
              ...project.objects.map((object) {
                final isSelected = object.id == selectedId;

                return Positioned(
                  left: object.x,
                  top: object.y,
                  child: GestureDetector(
                    onTap: () {
                      selectObject(object.id);
                    },
                    onPanStart: (_) {
                      selectObject(object.id);
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
                          border: isSelected
                              ? Border.all(
                                  width: 3,
                                  color: Colors.white,
                                )
                              : null,
                          boxShadow: isSelected
                              ? const [
                                  BoxShadow(
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                    color: Colors.white30,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
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
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget propertyPanel() {
    final object = selected;

    if (object == null || !propertiesVisible) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 330,
        ),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(22),
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              offset: Offset(0, -4),
              color: Colors.black38,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune,
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          object.type,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: widget.arabic
                        ? 'إخفاء القائمة'
                        : 'Hide panel',
                    onPressed: () {
                      setState(() {
                        propertiesVisible = false;
                      });
                    },
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  IconButton(
                    tooltip: widget.arabic ? 'حذف' : 'Delete',
                    onPressed: deleteSelected,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const Divider(height: 8),
              _slider(
                label: 'X',
                value: object.x.clamp(
                  0,
                  project.worldWidth,
                ),
                min: 0,
                max: project.worldWidth,
                onChanged: (value) {
                  setState(() {
                    object.x = value;
                  });
                },
              ),
              _slider(
                label: 'Y',
                value: object.y.clamp(
                  0,
                  project.worldHeight,
                ),
                min: 0,
                max: project.worldHeight,
                onChanged: (value) {
                  setState(() {
                    object.y = value;
                  });
                },
              ),
              _slider(
                label: widget.arabic ? 'العرض' : 'Width',
                value: object.width.clamp(20, 500),
                min: 20,
                max: 500,
                onChanged: (value) {
                  setState(() {
                    object.width = value;
                  });
                },
              ),
              _slider(
                label: widget.arabic ? 'الارتفاع' : 'Height',
                value: object.height.clamp(20, 500),
                min: 20,
                max: 500,
                onChanged: (value) {
                  setState(() {
                    object.height = value;
                  });
                },
              ),
              _slider(
                label: widget.arabic ? 'الدوران' : 'Rotation',
                value: object.rotation,
                min: -180,
                max: 180,
                onChanged: (value) {
                  setState(() {
                    object.rotation = value;
                  });
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
          width: 65,
          child: Text(
            '$label ${value.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
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
        final items = [
          ['Player', Icons.person],
          ['Platform', Icons.view_agenda],
          ['Coin', Icons.monetization_on],
          ['Enemy', Icons.smart_toy],
          ['Box', Icons.inventory_2],
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Game Studio'),
        actions: [
          if (hasSelection && !propertiesVisible)
            IconButton(
              tooltip: widget.arabic
                  ? 'إظهار الخصائص'
                  : 'Show properties',
              onPressed: () {
                setState(() {
                  propertiesVisible = true;
                });
              },
              icon: const Icon(Icons.tune),
            ),
          IconButton(
            tooltip: widget.arabic ? 'فتح' : 'Open',
            onPressed: load,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: widget.arabic ? 'حفظ' : 'Save',
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: widget.arabic ? 'الإعدادات' : 'Settings',
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
            tooltip: widget.arabic ? 'تشغيل' : 'Play',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameRuntime(
                    project: project,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: buildCanvas(),
          ),
          if (selected != null && propertiesVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: propertyPanel(),
            ),
          Positioned(
            right: 16,
            bottom: selected != null && propertiesVisible
                ? 350
                : 16,
            child: FloatingActionButton(
              heroTag: 'add',
              onPressed: openAddMenu,
              child: const Icon(Icons.add),
            ),
          ),
          if (selected != null && propertiesVisible)
            Positioned(
              right: 16,
              bottom: 350 + 70,
              child: FloatingActionButton.small(
                heroTag: 'hide',
                onPressed: () {
                  setState(() {
                    propertiesVisible = false;
                  });
                },
                child: const Icon(Icons.keyboard_arrow_down),
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
