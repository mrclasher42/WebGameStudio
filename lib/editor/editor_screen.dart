import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/game_object.dart';
import '../models/game_project.dart';
import '../models/game_type.dart';
import '../runtime/game_runtime.dart';
import '../services/project_storage.dart';
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
  GameProject project = GameProject();
  int sceneIndex = 0;
  String? selectedId;
  String codeTab = 'HTML';

  GameScene get scene => project.scenes[sceneIndex];

  GameObject? get selected {
    for (final object in scene.objects) {
      if (object.id == selectedId) return object;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await ProjectStorage.load();
    if (!mounted) return;

    if (saved != null) {
      setState(() {
        project = saved;
      });
    }
  }

  void _newProject(GameType type) {
    setState(() {
      project = GameProject(
        name: 'My Game',
        gameType: type,
      );
      sceneIndex = 0;
      selectedId = null;
    });
  }

  void _addObject(String type) {
    final id = '${type}_${DateTime.now().millisecondsSinceEpoch}';

    final object = GameObject(
      id: id,
      name: type,
      type: type,
      x: 100 + scene.objects.length * 15.0,
      y: 100 + scene.objects.length * 15.0,
      html: _defaultHtml(type),
      css: _defaultCss(type),
    );

    setState(() {
      scene.objects.add(object);
      selectedId = id;
    });
  }

  String _defaultHtml(String type) {
    switch (type) {
      case 'text':
        return '<span>Text</span>';
      case 'button':
        return '<button class="wgs-button">Button</button>';
      case 'character':
        return '<div class="character-body"></div>';
      case 'platform':
        return '<div class="platform-body"></div>';
      case 'enemy':
        return '<div class="enemy-body"></div>';
      case 'coin':
        return '<div class="coin-body"></div>';
      case 'input':
        return '<input placeholder="Type here">';
      case 'panel':
        return '<div class="panel-body"></div>';
      case 'image':
        return '<div>Image</div>';
      default:
        return '<div></div>';
    }
  }

  String _defaultCss(String type) {
    switch (type) {
      case 'text':
        return 'font-size:28px;color:white;';
      case 'button':
        return 'background:#4f7cff;color:white;border:0;border-radius:12px;padding:14px 25px;font-size:18px;';
      case 'character':
        return 'width:100%;height:100%;background:#ff5252;border-radius:12px;';
      case 'platform':
        return 'width:100%;height:100%;background:#555;border-radius:8px;';
      case 'enemy':
        return 'width:100%;height:100%;background:#9c27b0;border-radius:14px;';
      case 'coin':
        return 'width:60%;height:60%;margin:20%;background:#ffd54f;border-radius:50%;';
      case 'input':
        return 'width:100%;height:100%;box-sizing:border-box;font-size:18px;padding:10px;';
      case 'panel':
        return 'width:100%;height:100%;background:rgba(255,255,255,.08);border-radius:16px;';
      default:
        return 'width:100%;height:100%;background:#2d3442;border-radius:12px;';
    }
  }

  void _deleteSelected() {
    if (selectedId == null) return;

    setState(() {
      scene.objects.removeWhere((e) => e.id == selectedId);
      selectedId = null;
    });
  }

  Future<void> _pickSound() async {
    final object = selected;
    if (object == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final extension = file.extension ?? 'mp3';
    final mime = extension == 'wav' ? 'audio/wav' : 'audio/mpeg';

    setState(() {
      object.sound = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  void _showCodeEditor() {
    final object = selected;
    if (object == null) return;

    final controller = TextEditingController(
      text: codeTab == 'HTML'
          ? object.html
          : codeTab == 'CSS'
              ? object.css
              : object.logic,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * .85,
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Text(
                        object.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'HTML', label: Text('HTML')),
                        ButtonSegment(value: 'CSS', label: Text('CSS')),
                        ButtonSegment(value: 'Logic', label: Text('Logic')),
                      ],
                      selected: {codeTab},
                      onSelectionChanged: (value) {
                        setSheetState(() {
                          codeTab = value.first;
                          controller.text = codeTab == 'HTML'
                              ? object.html
                              : codeTab == 'CSS'
                                  ? object.css
                                  : object.logic;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (codeTab == 'Logic')
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'onKey("ArrowRight", player => player.moveX(5));\nonTap(player => player.moveY(-20));\nonUpdate(player => player.moveX(1));\nonStart(player => player.show());',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: controller,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (codeTab == 'HTML') {
                              object.html = value;
                            } else if (codeTab == 'CSS') {
                              object.css = value;
                            } else {
                              object.logic = value;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInspector() {
    final object = selected;
    if (object == null) return;

    final name = TextEditingController(text: object.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inspector',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        object.name = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    _numberField(
                      'X',
                      object.x,
                      (value) => setState(() => object.x = value),
                    ),
                    _numberField(
                      'Y',
                      object.y,
                      (value) => setState(() => object.y = value),
                    ),
                    _numberField(
                      'Width',
                      object.width,
                      (value) => setState(() => object.width = value),
                    ),
                    _numberField(
                      'Height',
                      object.height,
                      (value) => setState(() => object.height = value),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _showCodeEditor,
                      icon: const Icon(Icons.code),
                      label: const Text('HTML / CSS / Logic'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickSound,
                      icon: const Icon(Icons.music_note),
                      label: Text(
                        object.sound.isEmpty
                            ? 'Add Sound'
                            : 'Sound Added',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteSelected();
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _numberField(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        keyboardType: TextInputType.number,
        controller: TextEditingController(text: value.toStringAsFixed(0)),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) {
          final parsed = double.tryParse(text);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }

  Widget _canvas() {
    return InteractiveViewer(
      minScale: .25,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(500),
      child: Container(
        width: project.width,
        height: project.height,
        decoration: BoxDecoration(
          color: const Color(0xff151923),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),
            ...scene.objects.map(_canvasObject),
          ],
        ),
      ),
    );
  }

  Widget _canvasObject(GameObject object) {
    final isSelected = object.id == selectedId;

    return Positioned(
      left: object.x,
      top: object.y,
      width: object.width,
      height: object.height,
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
          angle: object.rotation * 0.0174533,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.blueAccent : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    object.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isSelected)
                  const Positioned(
                    right: 2,
                    top: 2,
                    child: Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: Colors.blueAccent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = EditorTools.forType(project.gameType);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            tooltip: 'New',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectTypeScreen(
                    arabic: widget.arabic,
                    onSelected: _newProject,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: () async {
              await ProjectStorage.save(project);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Project saved')),
              );
            },
            icon: const Icon(Icons.save),
          ),
          IconButton(
            tooltip: 'Preview',
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
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: tools.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tool = tools[index];

                return FilledButton.tonalIcon(
                  onPressed: () => _addObject(tool.id),
                  icon: Icon(tool.icon),
                  label: Text(tool.title),
                );
              },
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _canvas()),
                Container(
                  width: 270,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: selected == null
                      ? const Center(
                          child: Text(
                            'Select an object',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView(
                          children: [
                            Text(
                              selected!.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall,
                            ),
                            const SizedBox(height: 15),
                            FilledButton.icon(
                              onPressed: _showInspector,
                              icon: const Icon(Icons.tune),
                              label: const Text('Inspector'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _showCodeEditor,
                              icon: const Icon(Icons.code),
                              label: const Text('Edit Code'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _pickSound,
                              icon: const Icon(Icons.volume_up),
                              label: const Text('Sound'),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Type: ${selected!.type}',
                              style: const TextStyle(color: Colors.white60),
                            ),
                            Text(
                              'X: ${selected!.x.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.white60),
                            ),
                            Text(
                              'Y: ${selected!.y.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: selected == null
          ? null
          : FloatingActionButton(
              onPressed: _deleteSelected,
              child: const Icon(Icons.delete),
            ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.035)
      ..strokeWidth = 1;

    const step = 40.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
