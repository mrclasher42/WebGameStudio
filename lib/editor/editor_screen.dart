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

    final safeJs = jsonEncode(jsCode);

    final document = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
html,
body {
  margin: 0;
  padding: 0;
  width: 100%;
  min-height: 100%;
  overflow: hidden;
  overscroll-behavior: none;
  -webkit-user-select: none;
  user-select: none;
  -webkit-touch-callout: none;
}

$cssCode

#wgs-error {
  position: fixed;
  z-index: 999999;
  inset: 0;
  display: none;
  align-items: center;
  justify-content: center;
  padding: 22px;
  background: rgba(5, 7, 12, 0.96);
  color: white;
  font-family: Arial, sans-serif;
}

#wgs-error-box {
  width: 100%;
  max-width: 430px;
  padding: 22px;
  border-radius: 20px;
  background: #151923;
  border: 1px solid #3a404d;
  box-shadow: 0 20px 60px rgba(0,0,0,.45);
}

#wgs-error-title {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
  font-size: 19px;
  font-weight: 700;
}

#wgs-error-icon {
  width: 34px;
  height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 10px;
  background: rgba(255, 70, 100, .14);
  color: #ff526f;
  font-size: 19px;
}

#wgs-error-message {
  margin: 0;
  padding: 14px;
  border-radius: 12px;
  background: #0b0e14;
  color: #ff8da0;
  font-family: monospace;
  font-size: 13px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}

#wgs-error-label {
  margin-top: 13px;
  color: #858b98;
  font-size: 12px;
}
</style>
</head>
<body>

$html

<div id="wgs-error">
  <div id="wgs-error-box">
    <div id="wgs-error-title">
      <div id="wgs-error-icon">!</div>
      JavaScript Error
    </div>
    <pre id="wgs-error-message"></pre>
    <div id="wgs-error-label">
      Fix the code and the preview will update automatically.
    </div>
  </div>
</div>

<script>
(function() {
  const errorBox = document.getElementById("wgs-error");
  const errorMessage = document.getElementById("wgs-error-message");

  function showError(message) {
    errorMessage.textContent = String(message);
    errorBox.style.display = "flex";
  }

  window.addEventListener("error", function(event) {
    if (event.error) {
      showError(event.error.stack || event.error.message || event.message);
    } else {
      showError(event.message);
    }
  });

  window.addEventListener("unhandledrejection", function(event) {
    showError(
      event.reason && event.reason.stack
        ? event.reason.stack
        : String(event.reason)
    );
  });

  const originalConsoleError = console.error;

  console.error = function() {
    const message = Array.from(arguments)
      .map(value => {
        try {
          return typeof value === "string"
            ? value
            : JSON.stringify(value);
        } catch (_) {
          return String(value);
        }
      })
      .join(" ");

    showError(message);
    originalConsoleError.apply(console, arguments);
  };

  try {
    const userCode = $safeJs;
    const runUserCode = new Function(userCode);
    runUserCode();
  } catch (error) {
    showError(error && error.stack ? error.stack : error);
  }
})();
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

  void openPreview() {
    setState(() {
      previewMode = true;
    });

    loadPreview();
  }

  void closePreview() {
    setState(() {
      previewMode = false;
    });
  }

  Widget buildEditor() {
    final controller = selectedTab == 0
        ? htmlController
        : selectedTab == 1
            ? cssController
            : jsController;

    return CodeTheme(
      data: CodeThemeData(
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

  Widget buildPreview() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.white,
            child: WebViewWidget(
              controller: webController,
            ),
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: closePreview,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(.14),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 18,
                        color: Colors.black38,
                      ),
                    ],
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
            onPressed: openPreview,
            tooltip: 'Preview',
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            onPressed: saveProject,
            tooltip: 'Save',
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            color: const Color(0xFF0D1017),
            child: Row(
              children: [
                tabButton('HTML', 0),
                tabButton('CSS', 1),
                tabButton('JS', 2),
              ],
            ),
          ),
          Expanded(
            child: buildEditor(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openPreview,
        backgroundColor: const Color(0xFF7C5CFF),
        child: const Icon(Icons.play_arrow_rounded),
      ),
    );
  }

  Widget tabButton(String title, int index) {
    final active = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
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
              fontWeight: active
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
