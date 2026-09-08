import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const GameStudioApp());
}

class GameStudioApp extends StatefulWidget {
  const GameStudioApp({super.key});

  @override
  State<GameStudioApp> createState() => _GameStudioAppState();
}

class _GameStudioAppState extends State<GameStudioApp> {
  Locale locale = const Locale('en');
  ThemeMode themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      locale = Locale(p.getString('language') ?? 'en');
      themeMode = p.getBool('dark') == false
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  Future<void> saveSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('language', locale.languageCode);
    await p.setBool('dark', themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6750A4),
        scaffoldBackgroundColor: const Color(0xFFF5F5F8),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8B7CFF),
        scaffoldBackgroundColor: const Color(0xFF090B10),
      ),
      home: Studio(
        locale: locale,
        themeMode: themeMode,
        onLanguage: (value) {
          setState(() => locale = value);
          saveSettings();
        },
        onTheme: (value) {
          setState(() => themeMode = value);
          saveSettings();
        },
      ),
    );
  }
}

class Studio extends StatefulWidget {
  final Locale locale;
  final ThemeMode themeMode;
  final ValueChanged<Locale> onLanguage;
  final ValueChanged<ThemeMode> onTheme;

  const Studio({
    super.key,
    required this.locale,
    required this.themeMode,
    required this.onLanguage,
    required this.onTheme,
  });

  @override
  State<Studio> createState() => _StudioState();
}

class _StudioState extends State<Studio> {
  final List<GameObject> objects = [];
  String? selected;
  bool playing = false;
  bool showSettings = false;
  bool showAssets = false;
  bool showProperties = false;

  late WebViewController web;

  bool get arabic => widget.locale.languageCode == 'ar';

  String text(String en, String ar) => arabic ? ar : en;

  @override
  void initState() {
    super.initState();

    web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);

    loadProject();
  }

  Future<void> loadProject() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('project');

    if (raw == null) return;

    final data = jsonDecode(raw);

    setState(() {
      objects.clear();

      for (final item in data) {
        objects.add(GameObject.fromJson(item));
      }
    });
  }

  Future<void> saveProject() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'project',
      jsonEncode(
        objects.map((object) => object.toJson()).toList(),
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text('Project saved', 'تم حفظ المشروع'),
        ),
      ),
    );
  }

  void addObject(String type) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final random = Random();

    final object = GameObject(
      id: id,
      type: type,
      x: 100 + random.nextInt(160),
      y: 120 + random.nextInt(180),
      width: type == 'platform' ? 190 : 72,
      height: type == 'platform' ? 48 : 72,
      rotation: 0,
    );

    setState(() {
      objects.add(object);
      selected = id;
      showAssets = false;
      showProperties = true;
    });
  }

  void deleteSelected() {
    if (selected == null) return;

    setState(() {
      objects.removeWhere(
        (object) => object.id == selected,
      );

      selected = null;
      showProperties = false;
    });
  }

  void runGame() {
    web.loadHtmlString(generateGame());

    setState(() {
      playing = true;
    });
  }

  String generateGame() {
    final data = jsonEncode(
      objects.map((object) => object.toJson()).toList(),
    );

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<style>
*{box-sizing:border-box}
html,body{margin:0;width:100%;height:100%;overflow:hidden}
body{background:#101522}
#game{position:relative;width:100%;height:100%;overflow:hidden;background:linear-gradient(#182238,#0d111b)}
.object{position:absolute;display:flex;align-items:center;justify-content:center;border-radius:14px;font-family:Arial;font-weight:800;color:white}
.player{background:#5e8cff}
.platform{background:#38d996}
.enemy{background:#ff5d73}
.coin{background:#ffd34d;color:#222;border-radius:50%}
.box{background:#9b72ff}
</style>
</head>
<body>
<div id="game"></div>
<script>
const objects=$data;
const game=document.getElementById("game");

objects.forEach(o=>{
 const element=document.createElement("div");
 element.className="object "+o.type;
 element.style.left=o.x+"px";
 element.style.top=o.y+"px";
 element.style.width=o.width+"px";
 element.style.height=o.height+"px";
 element.style.transform="rotate("+o.rotation+"deg)";
 element.textContent=o.type;
 game.appendChild(element);
});
</script>
</body>
</html>
'''.replaceFirst('\$data', data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: playing ? buildGamePreview() : buildStudio(),
      ),
    );
  }

  Widget buildStudio() {
    return Stack(
      children: [
        Column(
          children: [
            buildHeader(),
            Expanded(
              child: buildEditor(),
            ),
            buildBottomBar(),
          ],
        ),
        if (showAssets) buildAssetsPanel(),
        if (showProperties) buildPropertiesPanel(),
        if (showSettings) buildSettingsPanel(),
      ],
    );
  }

  Widget buildHeader() {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.videogame_asset_rounded,
            color: Color(0xFF8B7CFF),
            size: 30,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text('My Game', 'لعبتي'),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: saveProject,
            icon: const Icon(Icons.save_rounded),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                showSettings = true;
              });
            },
            icon: const Icon(Icons.settings_rounded),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: runGame,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(text('Play', 'تشغيل')),
          ),
        ],
      ),
    );
  }

  Widget buildEditor() {
    return Container(
      margin: const EdgeInsets.all(10),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: widget.themeMode == ThemeMode.dark
            ? const Color(0xFF11151E)
            : const Color(0xFFE9EAF0),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                dark: widget.themeMode == ThemeMode.dark,
              ),
            ),
          ),
          ...objects.map(buildObject),
          if (objects.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 55,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(.35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text(
                      'Tap + to add your first object',
                      'اضغط + لإضافة أول عنصر',
                    ),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(.45),
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  showAssets = true;
                });
              },
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildObject(GameObject object) {
    final active = selected == object.id;

    return Positioned(
      left: object.x,
      top: object.y,
      child: GestureDetector(
        onTap: () {
          setState(() {
            selected = object.id;
            showProperties = true;
          });
        },
        onPanStart: (_) {
          setState(() {
            selected = object.id;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            object.x += details.delta.dx;
            object.y += details.delta.dy;
          });
        },
        child: Transform.rotate(
          angle: object.rotation * pi / 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: object.width,
                height: object.height,
                decoration: BoxDecoration(
                  color: object.color,
                  borderRadius: BorderRadius.circular(
                    object.type == 'coin' ? 100 : 14,
                  ),
                  border: active
                      ? Border.all(
                          color: Colors.white,
                          width: 3,
                        )
                      : null,
                  boxShadow: active
                      ? [
                          const BoxShadow(
                            blurRadius: 18,
                            spreadRadius: 3,
                            color: Color(0x668B7CFF),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  object.icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              if (active)
                Positioned(
                  right: -16,
                  bottom: -16,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        object.width = max(
                          40,
                          object.width + details.delta.dx,
                        );

                        object.height = max(
                          40,
                          object.height + details.delta.dy,
                        );
                      });
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6750A4),
                          width: 4,
                        ),
                      ),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        size: 16,
                        color: Color(0xFF6750A4),
                      ),
                    ),
                  ),
                ),
              if (active)
                Positioned(
                  left: -16,
                  top: -16,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        object.rotation +=
                            details.delta.dx * .8;
                      });
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6750A4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.rotate_right_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBottomBar() {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          bottomItem(
            Icons.layers_rounded,
            text('Objects', 'العناصر'),
            () {
              setState(() {
                showAssets = true;
              });
            },
          ),
          bottomItem(
            Icons.tune_rounded,
            text('Properties', 'الخصائص'),
            () {
              if (selected != null) {
                setState(() {
                  showProperties = true;
                });
              }
            },
          ),
          bottomItem(
            Icons.save_rounded,
            text('Save', 'حفظ'),
            saveProject,
          ),
          bottomItem(
            Icons.play_circle_rounded,
            text('Play', 'تشغيل'),
            runGame,
          ),
        ],
      ),
    );
  }

  Widget bottomItem(
    IconData icon,
    String title,
    VoidCallback action,
  ) {
    return Expanded(
      child: InkWell(
        onTap: action,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAssetsPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: panel(
        title: text('Add Object', 'إضافة عنصر'),
        close: () {
          setState(() {
            showAssets = false;
          });
        },
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            assetButton(
              Icons.person_rounded,
              text('Player', 'لاعب'),
              'player',
            ),
            assetButton(
              Icons.crop_square_rounded,
              text('Platform', 'منصة'),
              'platform',
            ),
            assetButton(
              Icons.monetization_on_rounded,
              text('Coin', 'عملة'),
              'coin',
            ),
            assetButton(
              Icons.warning_rounded,
              text('Enemy', 'عدو'),
              'enemy',
            ),
            assetButton(
              Icons.inventory_2_rounded,
              text('Box', 'صندوق'),
              'box',
            ),
          ],
        ),
      ),
    );
  }

  Widget assetButton(
    IconData icon,
    String title,
    String type,
  ) {
    return SizedBox(
      width: 95,
      height: 90,
      child: FilledButton.tonal(
        onPressed: () => addObject(type),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 6),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget buildPropertiesPanel() {
    if (selected == null) {
      return const SizedBox();
    }

    final object = objects.firstWhere(
      (item) => item.id == selected,
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: panel(
        title: text('Properties', 'الخصائص'),
        close: () {
          setState(() {
            showProperties = false;
          });
        },
        child: Column(
          children: [
            Row(
              children: [
                Icon(object.icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    object.type.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: deleteSelected,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: property(
                    text('X', 'س'),
                    object.x,
                    (v) {
                      setState(() {
                        object.x = v;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: property(
                    text('Y', 'ص'),
                    object.y,
                    (v) {
                      setState(() {
                        object.y = v;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: property(
                    text('Width', 'العرض'),
                    object.width,
                    (v) {
                      setState(() {
                        object.width = max(20, v);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: property(
                    text('Height', 'الارتفاع'),
                    object.height,
                    (v) {
                      setState(() {
                        object.height = max(20, v);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget property(
    String label,
    double value,
    ValueChanged<double> change,
  ) {
    final controller = TextEditingController(
      text: value.round().toString(),
    );

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (value) {
        final number = double.tryParse(value);

        if (number != null) {
          change(number);
        }
      },
    );
  }

  Widget buildSettingsPanel() {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: min(
        MediaQuery.of(context).size.width * .88,
        380,
      ),
      child: Material(
        elevation: 20,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text('Settings', 'الإعدادات'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          showSettings = false;
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Text(
                  text('Language', 'اللغة'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'en',
                      label: Text('English'),
                    ),
                    ButtonSegment(
                      value: 'ar',
                      label: Text('العربية'),
                    ),
                  ],
                  selected: {
                    widget.locale.languageCode,
                  },
                  onSelectionChanged: (value) {
                    widget.onLanguage(
                      Locale(value.first),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  text('Appearance', 'المظهر'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {
                    widget.themeMode,
                  },
                  onSelectionChanged: (value) {
                    widget.onTheme(value.first);
                  },
                ),
                const SizedBox(height: 28),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(
                    text('Web Game Studio', 'استوديو ألعاب الويب'),
                  ),
                  subtitle: const Text('Version 1.0.0'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget panel({
    required String title,
    required VoidCallback close,
    required Widget child,
  }) {
    return Material(
      elevation: 30,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget buildGamePreview() {
    return Stack(
      children: [
        Positioned.fill(
          child: WebViewWidget(
            controller: web,
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: FloatingActionButton.small(
            onPressed: () {
              setState(() {
                playing = false;
              });
            },
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ],
    );
  }
}

class GameObject {
  String id;
  String type;
  double x;
  double y;
  double width;
  double height;
  double rotation;

  GameObject({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
  });

  Color get color {
    switch (type) {
      case 'player':
        return const Color(0xFF5E8CFF);
      case 'platform':
        return const Color(0xFF38D996);
      case 'enemy':
        return const Color(0xFFFF5D73);
      case 'coin':
        return const Color(0xFFFFD34D);
      default:
        return const Color(0xFF9B72FF);
    }
  }

  IconData get icon {
    switch (type) {
      case 'player':
        return Icons.person_rounded;
      case 'platform':
        return Icons.crop_square_rounded;
      case 'enemy':
        return Icons.warning_rounded;
      case 'coin':
        return Icons.monetization_on_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
    };
  }

  factory GameObject.fromJson(Map<String, dynamic> json) {
    return GameObject(
      id: json['id'],
      type: json['type'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num).toDouble(),
    );
  }
}

class GridPainter extends CustomPainter {
  final bool dark;

  GridPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dark
          ? Colors.white.withOpacity(.035)
          : Colors.black.withOpacity(.055)
      ..strokeWidth = 1;

    const step = 32.0;

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
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}
