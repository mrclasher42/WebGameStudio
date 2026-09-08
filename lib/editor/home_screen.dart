import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Project> projects = [];

  late AnimationController animationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutCubic,
    );

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    loadProjects();
    animationController.forward();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  Future<void> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('projects') ?? [];

    if (!mounted) return;

    setState(() {
      projects = data
          .map(
            (item) => Project.fromJson(
              Map<String, dynamic>.from(jsonDecode(item)),
            ),
          )
          .toList();
    });
  }

  Future<void> saveProjects() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'projects',
      projects.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> createProject() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Project'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Project name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name == null) return;

    final project = Project(
      name: name,
      html: '''<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
  <h1>Hello 👋</h1>
  <p>Start creating something.</p>
</body>
</html>''',
      css: '''body {
  margin: 0;
  padding: 30px;
  font-family: sans-serif;
  background: #111827;
  color: white;
}''',
      js: '''console.log("Hello from JavaScript");''',
    );

    projects.insert(0, project);
    await saveProjects();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          project: project,
          onSaved: loadProjects,
        ),
      ),
    );
  }

  void openProject(Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          project: project,
          onSaved: loadProjects,
        ),
      ),
    );
  }

  Future<void> deleteProject(int index) async {
    projects.removeAt(index);
    await saveProjects();

    if (!mounted) return;

    setState(() {});
  }

  Future<void> openSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final initialSingleFile = prefs.getBool('singleFileMode') ?? false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) {
        bool singleFileMode = initialSingleFile;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          widget.darkMode
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                        ),
                      ),
                      title: Text(
                        widget.darkMode ? 'Dark Theme' : 'Light Theme',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text('Choose app appearance'),
                      trailing: Switch(
                        value: widget.darkMode,
                        onChanged: (value) {
                          widget.onThemeChanged(value);
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.description_rounded),
                      ),
                      title: const Text(
                        'Single File Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Edit HTML, CSS and JavaScript in one file',
                      ),
                      trailing: Switch(
                        value: singleFileMode,
                        onChanged: (value) async {
                          setSheetState(() {
                            singleFileMode = value;
                          });

                          await prefs.setBool(
                            'singleFileMode',
                            value,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.darkMode;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Web Game Studio',
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF171923),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Create. Code. Preview.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: openSettings,
                        icon: const Icon(Icons.settings_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Projects',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF171923),
                          ),
                        ),
                      ),
                      Text(
                        '${projects.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: projects.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.code_rounded,
                                  size: 52,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No projects yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Create your first project',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: projects.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final project = projects[index];

                              return Dismissible(
                                key: ValueKey(
                                  '${project.name}_$index',
                                ),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => deleteProject(index),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding:
                                      const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(.12),
                                    borderRadius:
                                        BorderRadius.circular(18),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red,
                                  ),
                                ),
                                child: Card(
                                  elevation: 0,
                                  margin: EdgeInsets.zero,
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(.12),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.code_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    title: Text(
                                      project.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'HTML • CSS • JavaScript',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap: () => openProject(project),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createProject,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Project'),
      ),
    );
  }
}
