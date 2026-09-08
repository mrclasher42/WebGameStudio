import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Project> projects = [];

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('projects') ?? [];

    setState(() {
      projects = data
          .map((item) => Project.fromJson(jsonDecode(item)))
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Web Game Studio',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'HTML • CSS • JS',
                style: TextStyle(
                  color: Colors.white.withOpacity(.5),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  onPressed: createProject,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'New Project',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Projects',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: projects.isEmpty
                    ? Center(
                        child: Text(
                          'No projects yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.4),
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF11151E),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(.06),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 7,
                              ),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C5CFF)
                                      .withOpacity(.15),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.code,
                                  color: Color(0xFF9B83FF),
                                ),
                              ),
                              title: Text(
                                project.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text('HTML • CSS • JS'),
                              onTap: () => openProject(project),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => deleteProject(index),
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
    );
  }
}
