import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/xml.dart' as xml;
import 'package:highlight/languages/css.dart' as css;
import 'package:highlight/languages/javascript.dart' as javascript;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/project.dart';

class EditorScreen extends StatefulWidget {
  final Project project;
  final VoidCallback onSaved;

  const EditorScreen({
    super.key,
    required this.project,
    required this.onSaved,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late CodeController htmlController;
  late CodeController cssController;
  late CodeController jsController;
  late WebViewController webController;

  int selectedTab = 0;
  Timer? previewTimer;

  @override
  void initState() {
    super.initState();

    htmlController = CodeController(
      text: widget.project.html,
      language: xml.xml,
      theme: monokaiSublimeTheme,
    );

    cssController = CodeController(
      text: widget.project.css,
      language: css.css,
      theme: monokaiSublimeTheme,
    );

    jsController = CodeController(
      text: widget.project.js,
      language: javascript.javascript,
      theme: monokaiSublimeTheme,
    );

    htmlController.addListener(schedulePreview);
    cssController.addListener(schedulePreview);
    jsController.addListener(schedulePreview);

    webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    loadPreview();
  }

  @override
  void dispose() {
    previewTimer?.cancel();
    htmlController.dispose();
    cssController.dispose();
    jsController.dispose();
    super.dispose();
  }

  void schedulePreview() {
    previewTimer?.cancel();
    previewTimer = Timer(
      const Duration(milliseconds: 350),
      loadPreview,
    );
  }

  Future<void> loadPreview() async {
    final html = htmlController.text;
    final cssCode = cssController.text;
    final jsCode = jsController.text;

    final document = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
$cssCode
</style>
</head>
<body>
$html
<script>
try {
$jsCode
} catch (error) {
document.body.insertAdjacentHTML(
'beforeend',
'<pre style="color:red;padding:16px;">' + error + '</pre>'
);
}
</script>
</body>
</html>
''';

    await webController.loadHtmlString(document);
  }

  Future<void> saveProject() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('projects') ?? [];

    final updated = Project(
      name: widget.project.name,
      html: htmlController.text,
      css: cssController.text,
      js: jsController.text,
    );

    for (int i = 0; i < list.length; i++) {
      final data = jsonDecode(list[i]);
      final project = Project.fromJson(
        Map<String, dynamic>.from(data),
      );

      if (project.name == widget.project.name) {
        list[i] = jsonEncode(updated.toJson());
        await prefs.setStringList('projects', list);
        widget.onSaved();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project saved ✓'),
            duration: Duration(milliseconds: 900),
          ),
        );
        return;
      }
    }

    list.add(jsonEncode(updated.toJson()));
    await prefs.setStringList('projects', list);
    widget.onSaved();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Project saved ✓'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  Widget buildEditor() {
    final controller = selectedTab == 0
        ? htmlController
        : selectedTab == 1
            ? cssController
            : jsController;

    return CodeTheme(
      data: const CodeThemeData(
        styles: monokaiSublimeTheme,
      ),
      child: CodeField(
        controller: controller,
        background: const Color(0xFF0B0E14),
        cursorColor: const Color(0xFF9B83FF),
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.5,
        ),
        lineNumbers: true,
        wrap: false,
        expands: true,
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        title: Text(
          widget.project.name,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loadPreview,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: saveProject,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 48,
            color: const Color(0xFF0D1017),
            child: Row(
              children: [
                tabButton('HTML', 0),
                tabButton('CSS', 1),
                tabButton('JS', 2),
                tabButton('Preview', 3),
              ],
            ),
          ),
          Expanded(
            child: selectedTab == 3
                ? Container(
                    color: Colors.white,
                    child: WebViewWidget(controller: webController),
                  )
                : buildEditor(),
          ),
        ],
      ),
    );
  }

  Widget tabButton(String title, int index) {
    final active = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active
                    ? const Color(0xFF9B83FF)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
