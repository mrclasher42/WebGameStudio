import 'dart:async';
import 'dart:convert';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/css.dart' as css;
import 'package:highlight/languages/javascript.dart' as javascript;
import 'package:highlight/languages/xml.dart' as xml;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/project.dart';

class EditorScreen extends StatefulWidget {
  final Project project;

  const EditorScreen({
    super.key,
    required this.project,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final CodeController htmlController;
  late final CodeController cssController;
  late final CodeController jsController;

  late final WebViewController webViewController;

  int selectedTab = 0;
  bool previewMode = false;
  Timer? previewTimer;

  @override
  void initState() {
    super.initState();

    htmlController = CodeController(
      text: widget.project.html,
      language: xml.xml,
    );

    cssController = CodeController(
      text: widget.project.css,
      language: css.css,
    );

    jsController = CodeController(
      text: widget.project.js,
      language: javascript.javascript,
    );

    htmlController.addListener(schedulePreview);
    cssController.addListener(schedulePreview);
    jsController.addListener(schedulePreview);

    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (!mounted || !previewMode) return;

            if (error.isForMainFrame == true) {
              showPreviewError(
                'تعذر تحميل محتوى المعاينة.\n${error.description}',
              );
            }
          },
        ),
      );
  }

  void schedulePreview() {
    if (!previewMode) return;

    previewTimer?.cancel();

    previewTimer = Timer(
      const Duration(milliseconds: 350),
      loadPreview,
    );
  }

  String buildPreviewDocument() {
    final html = htmlController.text;
    final cssCode = cssController.text;
    final jsCode = jsController.text;

    final safeJs = jsonEncode(jsCode);

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
html, body {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  overscroll-behavior: none;
  -webkit-user-select: none;
  user-select: none;
}

* {
  box-sizing: border-box;
}

$cssCode

#wgs-error {
  position: fixed;
  left: 14px;
  right: 14px;
  top: 14px;
  z-index: 999999;
  display: none;
  padding: 14px 16px;
  border-radius: 14px;
  background: rgba(20, 20, 24, 0.96);
  color: #ff6b6b;
  font-family: sans-serif;
  font-size: 13px;
  line-height: 1.5;
  box-shadow: 0 10px 30px rgba(0,0,0,.35);
  border: 1px solid rgba(255,107,107,.35);
  white-space: pre-wrap;
  word-break: break-word;
}
</style>
</head>
<body>

$html

<div id="wgs-error"></div>

<script>
(function () {
  const errorBox = document.getElementById('wgs-error');

  function showError(message) {
    if (!errorBox) return;

    errorBox.textContent = message;
    errorBox.style.display = 'block';
  }

  window.onerror = function(message, source, line, column, error) {
    showError(
      'JavaScript Error\\n' +
      String(message || 'Unknown error') +
      (line ? '\\nLine: ' + line : '')
    );
    return true;
  };

  window.addEventListener('unhandledrejection', function(event) {
    showError(
      'Promise Error\\n' +
      String(event.reason || 'Unknown promise error')
    );
  });

  const originalConsoleError = console.error;

  console.error = function() {
    try {
      showError(
        'Console Error\\n' +
        Array.from(arguments).map(String).join(' ')
      );
    } catch (_) {}

    originalConsoleError.apply(console, arguments);
  };

  try {
    new Function($safeJs)();
  } catch (error) {
    showError(
      'JavaScript Error\\n' +
      String(error && error.message ? error.message : error)
    );
  }
})();
</script>

</body>
</html>
''';
  }

  Future<void> loadPreview() async {
    if (!mounted) return;

    await webViewController.loadHtmlString(
      buildPreviewDocument(),
    );
  }

  void showPreviewError(String message) {
    if (!mounted) return;

    webViewController.runJavaScript('''
      (function() {
        var box = document.getElementById("wgs-error");
        if (!box) return;
        box.textContent = ${jsonEncode(message)};
        box.style.display = "block";
      })();
    ''');
  }

  Future<void> saveProject() async {
    final prefs = await SharedPreferences.getInstance();

    final projects = prefs.getStringList('projects') ?? [];

    final updatedProject = Project(
      name: widget.project.name,
      html: htmlController.text,
      css: cssController.text,
      js: jsController.text,
    );

    final encoded = jsonEncode(updatedProject.toJson());

    final index = projects.indexWhere((item) {
      try {
        final decoded = jsonDecode(item);

        return decoded is Map &&
            decoded['name'] == updatedProject.name;
      } catch (_) {
        return false;
      }
    });

    if (index >= 0) {
      projects[index] = encoded;
    } else {
      projects.add(encoded);
    }

    await prefs.setStringList('projects', projects);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ المشروع ✓'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> openPreview() async {
    setState(() {
      previewMode = true;
    });

    await loadPreview();
  }

  void closePreview() {
    previewTimer?.cancel();

    setState(() {
      previewMode = false;
    });
  }

  Widget buildCodeEditor() {
    late CodeController controller;

    if (selectedTab == 0) {
      controller = htmlController;
    } else if (selectedTab == 1) {
      controller = cssController;
    } else {
      controller = jsController;
    }

    return Expanded(
      child: CodeTheme(
        data: CodeThemeData(
          styles: monokaiSublimeTheme,
        ),
        child: CodeField(
          controller: controller,
          expands: true,
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            height: 1.5,
          ),
          background: const Color(0xFF15171C),
          padding: const EdgeInsets.all(16),
          cursorColor: Colors.white,
          keyboardType: TextInputType.multiline,
        ),
      ),
    );
  }

  Widget buildPreview() {
    return Stack(
      children: [
        Positioned.fill(
          child: WebViewWidget(
            controller: webViewController,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: closePreview,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (previewMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: buildPreview(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.project.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: openPreview,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            onPressed: saveProject,
            icon: const Icon(Icons.save_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                buildTab('HTML', 0),
                buildTab('CSS', 1),
                buildTab('JS', 2),
              ],
            ),
          ),
          buildCodeEditor(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openPreview,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Preview'),
      ),
    );
  }

  Widget buildTab(String title, int index) {
    final selected = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    previewTimer?.cancel();

    htmlController.dispose();
    cssController.dispose();
    jsController.dispose();

    super.dispose();
  }
}
