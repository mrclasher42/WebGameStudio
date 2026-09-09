import 'dart:async';
import 'dart:convert';

import 'package:code_text_field/code_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/css.dart' as css;
import 'package:highlight/languages/javascript.dart' as javascript;
import 'package:highlight/languages/xml.dart' as xml;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/project.dart';
import '../services/lan_server.dart';

class EditorScreen extends StatefulWidget {
  final Project project;
  final VoidCallback? onSaved;

  const EditorScreen({
    super.key,
    required this.project,
    this.onSaved,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final Map<String, CodeController> controllers = {};

  late WebViewController webViewController;

  String currentFile = 'index.html';

  bool previewMode = false;
  bool singleFileMode = false;
  bool settingsLoaded = false;
  bool isSaving = false;
  bool hasChanges = false;

  bool lanRunning = false;
  String? lanUrl;

  Timer? autoSaveTimer;
  Timer? previewTimer;

  Map<String, String> files = {};
  List<String> folders = [];
  Map<String, ProjectAsset> assets = {};

  final List<Map<String, dynamic>> undoStack = [];
  final List<Map<String, dynamic>> redoStack = [];

  @override
  void initState() {
    super.initState();

    webViewController = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setBackgroundColor(
        Colors.black,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (!mounted || !previewMode) return;

            if (error.isForMainFrame == true) {
              showPreviewError(
                'تعذر تحميل المعاينة.\n${error.description}',
              );
            }
          },
        ),
      );

    loadEditor();
  }

  Future<void> loadEditor() async {
    final prefs =
        await SharedPreferences.getInstance();

    final enabled =
        prefs.getBool('singleFileMode') ?? false;

    final sourceFiles =
        Map<String, String>.from(
      widget.project.files,
    );

    if (sourceFiles.isEmpty) {
      sourceFiles['index.html'] =
          widget.project.html;
      sourceFiles['style.css'] =
          widget.project.css;
      sourceFiles['game.js'] =
          widget.project.js;
    }

    if (enabled) {
      final oldHtml =
          sourceFiles['index.html'] ??
              widget.project.html;

      sourceFiles
        ..clear()
        ..['index.html'] = oldHtml;
    }

    files = sourceFiles;
    folders = [...widget.project.folders];
    assets = {...widget.project.assets};

    if (!files.containsKey(currentFile)) {
      currentFile = files.keys.first;
    }

    for (final entry in files.entries) {
      createController(
        entry.key,
        entry.value,
      );
    }

    if (!files.containsKey('index.html')) {
      files['index.html'] = '';
      createController(
        'index.html',
        '',
      );
    }

    setState(() {
      singleFileMode = enabled;
      settingsLoaded = true;
    });
  }

  String languageFor(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.css')) {
      return 'css';
    }

    if (lower.endsWith('.js')) {
      return 'js';
    }

    if (lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.xml') ||
        lower.endsWith('.svg')) {
      return 'html';
    }

    return 'text';
  }

  void createController(
    String path,
    String text,
  ) {
    if (controllers.containsKey(path)) {
      return;
    }

    final language = languageFor(path);

    CodeController controller;

    if (language == 'css') {
      controller = CodeController(
        text: text,
        language: css.css,
      );
    } else if (language == 'js') {
      controller = CodeController(
        text: text,
        language: javascript.javascript,
      );
    } else if (language == 'html') {
      controller = CodeController(
        text: text,
        language: xml.xml,
      );
    } else {
      controller = CodeController(
        text: text,
      );
    }

    controller.addListener(() {
      if (controllers[path] != controller) {
        return;
      }

      files[path] = controller.text;

      hasChanges = true;
      scheduleAutoSave();
      schedulePreview();

      if (lanRunning) {
        updateLan();
      }
    });

    controllers[path] = controller;
  }

  CodeController? get currentController {
    return controllers[currentFile];
  }

  void pushUndo() {
    undoStack.add(
      snapshot(),
    );

    if (undoStack.length > 50) {
      undoStack.removeAt(0);
    }

    redoStack.clear();
  }

  Map<String, dynamic> snapshot() {
    return {
      'files': Map<String, String>.from(files),
      'folders': [...folders],
      'assets': assets.map(
        (key, value) =>
            MapEntry(key, value.toJson()),
      ),
      'currentFile': currentFile,
    };
  }

  void restoreSnapshot(
    Map<String, dynamic> state,
  ) {
    for (final controller in controllers.values) {
      controller.dispose();
    }

    controllers.clear();

    files = Map<String, String>.from(
      state['files'] as Map,
    );

    folders = List<String>.from(
      state['folders'] as List,
    );

    final rawAssets =
        state['assets'] as Map;

    assets = {};

    rawAssets.forEach((key, value) {
      assets[key.toString()] =
          ProjectAsset.fromJson(
        Map<String, dynamic>.from(value),
      );
    });

    currentFile =
        state['currentFile']?.toString() ??
            'index.html';

    for (final entry in files.entries) {
      createController(
        entry.key,
        entry.value,
      );
    }

    if (!files.containsKey(currentFile) &&
        files.isNotEmpty) {
      currentFile = files.keys.first;
    }

    hasChanges = true;

    setState(() {});
    scheduleAutoSave();
  }

  void undo() {
    if (undoStack.isEmpty) {
      return;
    }

    redoStack.add(
      snapshot(),
    );

    final state = undoStack.removeLast();

    restoreSnapshot(state);
  }

  void redo() {
    if (redoStack.isEmpty) {
      return;
    }

    undoStack.add(
      snapshot(),
    );

    final state = redoStack.removeLast();

    restoreSnapshot(state);
  }

  Future<void> saveProject({
    bool showMessage = false,
  }) async {
    if (isSaving) {
      return;
    }

    isSaving = true;

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final html =
          files['index.html'] ?? '';

      final cssCode =
          files['style.css'] ?? '';

      final jsCode =
          files['game.js'] ?? '';

      final project = Project(
        name: widget.project.name,
        html: html,
        css: cssCode,
        js: jsCode,
        files: Map<String, String>.from(files),
        folders: [...folders],
        assets: Map<String, ProjectAsset>.from(
          assets,
        ),
      );

      final projects =
          prefs.getStringList('projects') ?? [];

      final encoded =
          jsonEncode(project.toJson());

      int index = -1;

      for (var i = 0;
          i < projects.length;
          i++) {
        try {
          final decoded =
              jsonDecode(projects[i]);

          if (decoded is Map &&
              decoded['name']?.toString() ==
                  widget.project.name) {
            index = i;
            break;
          }
        } catch (_) {}
      }

      if (index >= 0) {
        projects[index] = encoded;
      } else {
        projects.insert(0, encoded);
      }

      await prefs.setStringList(
        'projects',
        projects,
      );

      hasChanges = false;

      widget.onSaved?.call();

      if (showMessage && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ ✓'),
            behavior:
                SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      isSaving = false;
    }
  }

  void scheduleAutoSave() {
    autoSaveTimer?.cancel();

    autoSaveTimer = Timer(
      const Duration(milliseconds: 700),
      () {
        saveProject(
          showMessage: false,
        );
      },
    );
  }

  void schedulePreview() {
    if (!previewMode) {
      return;
    }

    previewTimer?.cancel();

    previewTimer = Timer(
      const Duration(milliseconds: 350),
      loadPreview,
    );
  }

  String getCurrentHtml() {
    return files['index.html'] ?? '';
  }

  String getCurrentCss() {
    return files['style.css'] ?? '';
  }

  String getCurrentJs() {
    return files['game.js'] ?? '';
  }

  Map<String, String> buildServerFiles() {
    final result =
        Map<String, String>.from(files);

    result['index.html'] =
        buildPreviewDocument();

    return result;
  }

  Map<String, String> buildAssetData() {
    final result = <String, String>{};

    for (final asset in assets.entries) {
      result[asset.key] =
          asset.value.base64Data;
    }

    return result;
  }

  Map<String, String> buildAssetMime() {
    final result = <String, String>{};

    for (final asset in assets.entries) {
      result[asset.key] =
          asset.value.mimeType;
    }

    return result;
  }

  Future<void> updateLan() async {
    if (!lanRunning) {
      return;
    }

    await LanServerService.instance.update(
      html: getCurrentHtml(),
      css: getCurrentCss(),
      js: getCurrentJs(),
      singleFile: singleFileMode,
      files: buildServerFiles(),
      assetData: buildAssetData(),
      assetMime: buildAssetMime(),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> startLan() async {
    try {
      await saveProject();

      final url =
          await LanServerService.instance.start(
        projectId: widget.project.name,
        html: getCurrentHtml(),
        css: getCurrentCss(),
        js: getCurrentJs(),
        singleFile: singleFileMode,
        files: buildServerFiles(),
        assetData: buildAssetData(),
        assetMime: buildAssetMime(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        lanRunning = true;
        lanUrl = url;
      });

      await showLanPanel();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('فشل تشغيل السيرفر: $e'),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> stopLan() async {
    await LanServerService.instance.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      lanRunning = false;
      lanUrl = null;
    });
  }

  Future<void> showLanPanel() async {
    if (!lanRunning ||
        lanUrl == null) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor:
          Theme.of(context)
              .scaffoldBackgroundColor,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  28,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              BoxDecoration(
                            color: Colors.green
                                .withOpacity(.12),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .wifi_tethering_rounded,
                            color:
                                Colors.green,
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'LAN Server',
                                style:
                                    TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                              SizedBox(
                                height: 3,
                              ),
                              Text(
                                'السيرفر يعمل الآن',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.green,
                                  fontWeight:
                                      FontWeight
                                          .700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration:
                              const BoxDecoration(
                            color:
                                Colors.green,
                            shape:
                                BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius:
                            BorderRadius
                                .circular(
                          18,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'رابط اللعبة',
                            style:
                                TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          SelectableText(
                            lanUrl!,
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child:
                              OutlinedButton
                                  .icon(
                            onPressed:
                                () async {
                              await Clipboard
                                  .setData(
                                ClipboardData(
                                  text:
                                      lanUrl!,
                                ),
                              );

                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger
                                  .of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم نسخ الرابط 📋',
                                  ),
                                  behavior:
                                      SnackBarBehavior
                                          .floating,
                                ),
                              );
                            },
                            icon:
                                const Icon(
                              Icons
                                  .content_copy_rounded,
                            ),
                            label:
                                const Text(
                              'نسخ الرابط',
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child:
                              FilledButton.icon(
                            style:
                                FilledButton
                                    .styleFrom(
                              backgroundColor:
                                  Colors.red,
                            ),
                            onPressed:
                                () async {
                              Navigator.of(
                                sheetContext,
                              ).pop();

                              await stopLan();
                            },
                            icon:
                                const Icon(
                              Icons
                                  .stop_rounded,
                            ),
                            label:
                                const Text(
                              'إيقاف السيرفر',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'افتح الرابط من أي جهاز متصل بنفس شبكة Wi-Fi.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 12,
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

  Future<void> openPreview() async {
    await saveProject();

    if (!mounted) {
      return;
    }

    setState(() {
      previewMode = true;
    });

    await loadPreview();
  }

  String buildPreviewDocument() {
    var html =
        files['index.html'] ?? '';

    final cssCode =
        files['style.css'] ?? '';

    final jsCode =
        files['game.js'] ?? '';

    if (!singleFileMode) {
      final style = cssCode.trim().isEmpty
          ? ''
          : '<style>\n$cssCode\n</style>';

      final script = jsCode.trim().isEmpty
          ? ''
          : '<script>\n$jsCode\n</script>';

      final hasHtml = RegExp(
        r'<html[\s>]',
        caseSensitive: false,
      ).hasMatch(html);

      if (!hasHtml) {
        html = '''<!doctype html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
$style
</head>
<body>
$html
$script
</body>
</html>''';
      } else {
        if (style.isNotEmpty) {
          html = html.replaceFirst(
            RegExp(
              r'</head>',
              caseSensitive: false,
            ),
            '$style\n</head>',
          );
        }

        if (script.isNotEmpty) {
          html = html.replaceFirst(
            RegExp(
              r'</body>',
              caseSensitive: false,
            ),
            '$script\n</body>',
          );
        }
      }
    }

    html = replaceAssetPaths(html);

    return html;
  }

  String replaceAssetPaths(String html) {
    var result = html;

    for (final entry in assets.entries) {
      final asset = entry.value;

      final dataUri =
          'data:${asset.mimeType};base64,${asset.base64Data}';

      result = result.replaceAll(
        entry.key,
        dataUri,
      );

      result = result.replaceAll(
        './${entry.key}',
        dataUri,
      );

      result = result.replaceAll(
        '/${entry.key}',
        dataUri,
      );
    }

    return result;
  }

  Future<void> loadPreview() async {
    if (!mounted) {
      return;
    }

    await webViewController.loadHtmlString(
      buildPreviewDocument(),
    );
  }

  void showPreviewError(String message) {
    if (!mounted) {
      return;
    }

    webViewController.runJavaScript('''
      (function() {
        var box = document.getElementById("wgs-error");

        if (!box) return;

        box.textContent = ${jsonEncode(message)};
        box.style.display = "block";
      })();
    ''');
  }

  void closePreview() {
    previewTimer?.cancel();

    setState(() {
      previewMode = false;
    });
  }

  Widget buildCodeEditor() {
    final controller =
        currentController;

    if (controller == null) {
      return const Expanded(
        child: Center(
          child: Text(
            'اختر ملفاً للبدء',
          ),
        ),
      );
    }

    final dark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Expanded(
      child: CodeTheme(
        data: CodeThemeData(
          styles: dark
              ? monokaiSublimeTheme
              : githubTheme,
        ),
        child: Container(
          color: dark
              ? const Color(0xFF15171C)
              : const Color(0xFFFAFAFC),
          child: CodeField(
            controller: controller,
            expands: true,
            textStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              height: 1.55,
              letterSpacing: .15,
              color: dark
                  ? Colors.white
                  : const Color(
                      0xFF20222B,
                    ),
            ),
            background: dark
                ? const Color(0xFF15171C)
                : const Color(0xFFFAFAFC),
            padding:
                const EdgeInsets.all(16),
            lineNumberStyle:
                const LineNumberStyle(
              width: 60,
              margin: 8,
              textAlign:
                  TextAlign.right,
            ),
            cursorColor:
                Theme.of(context)
                    .colorScheme
                    .primary,
            keyboardType:
                TextInputType.multiline,
          ),
        ),
      ),
    );
  }

  IconData fileIcon(String path) {
    final lower =
        path.toLowerCase();

    if (lower.endsWith('.html') ||
        lower.endsWith('.htm')) {
      return Icons.language_rounded;
    }

    if (lower.endsWith('.css')) {
      return Icons.style_rounded;
    }

    if (lower.endsWith('.js')) {
      return Icons.javascript_rounded;
    }

    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg')) {
      return Icons.image_rounded;
    }

    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg')) {
      return Icons.audiotrack_rounded;
    }

    return Icons.insert_drive_file_rounded;
  }

  Future<String?> askName({
    required String title,
    String initial = '',
    String hint = '',
  }) async {
    final controller =
        TextEditingController(
      text: initial,
    );

    final value =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                InputDecoration(
              hintText: hint,
            ),
            onSubmitted: (value) {
              final text =
                  value.trim();

              if (text.isNotEmpty) {
                Navigator.pop(
                  context,
                  text,
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child:
                  const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final text =
                    controller.text
                        .trim();

                if (text.isNotEmpty) {
                  Navigator.pop(
                    context,
                    text,
                  );
                }
              },
              child:
                  const Text('إنشاء'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return value;
  }

  Future<void> createFile() async {
    final name = await askName(
      title: 'ملف جديد',
      hint: 'scripts/player.js',
    );

    if (name == null) {
      return;
    }

    final path =
        name.trim().replaceAll(
              '\\',
              '/',
            );

    if (path.isEmpty ||
        files.containsKey(path) ||
        assets.containsKey(path)) {
      return;
    }

    pushUndo();

    final parent =
        path.contains('/')
            ? path.substring(
                0,
                path.lastIndexOf('/'),
              )
            : '';

    if (parent.isNotEmpty &&
        !folders.contains(parent)) {
      folders.add(parent);
    }

    files[path] = '';

    createController(
      path,
      '',
    );

    setState(() {
      currentFile = path;
      hasChanges = true;
    });

    scheduleAutoSave();
  }

  Future<void> createFolder() async {
    final name = await askName(
      title: 'مجلد جديد',
      hint: 'scripts',
    );

    if (name == null) {
      return;
    }

    final path =
        name.trim().replaceAll(
              '\\',
              '/',
            );

    if (path.isEmpty ||
        folders.contains(path)) {
      return;
    }

    pushUndo();

    folders.add(path);

    setState(() {
      hasChanges = true;
    });

    scheduleAutoSave();
  }

  Future<void> renameCurrent() async {
    if (!files.containsKey(currentFile)) {
      return;
    }

    final newName = await askName(
      title: 'إعادة تسمية',
      initial: currentFile,
    );

    if (newName == null) {
      return;
    }

    final path =
        newName.replaceAll(
      '\\',
      '/',
    );

    if (path.isEmpty ||
        path == currentFile ||
        files.containsKey(path)) {
      return;
    }

    pushUndo();

    final content =
        files.remove(currentFile)!;

    final controller =
        controllers.remove(
      currentFile,
    );

    controller?.dispose();

    files[path] = content;

    createController(
      path,
      content,
    );

    setState(() {
      currentFile = path;
      hasChanges = true;
    });

    scheduleAutoSave();
  }

  Future<void> deleteCurrent() async {
    if (!files.containsKey(currentFile)) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('حذف الملف؟'),
          content: Text(
            'سيتم حذف "$currentFile".',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('إلغاء'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    pushUndo();

    files.remove(currentFile);

    controllers[currentFile]?.dispose();
    controllers.remove(currentFile);

    if (files.isEmpty) {
      files['index.html'] = '';
      createController(
        'index.html',
        '',
      );
    }

    setState(() {
      currentFile =
          files.keys.first;
      hasChanges = true;
    });

    scheduleAutoSave();
  }

  Future<void> addAssets() async {
    final result =
        await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );

    if (result == null) {
      return;
    }

    pushUndo();

    for (final file
        in result.files) {
      final bytes = file.bytes;

      if (bytes == null) {
        continue;
      }

      final name =
          file.name.trim();

      if (name.isEmpty) {
        continue;
      }

      final path =
          'assets/$name';

      final mime =
          guessMimeType(name);

      assets[path] =
          ProjectAsset(
        path: path,
        mimeType: mime,
        base64Data:
            base64Encode(bytes),
      );
    }

    setState(() {
      hasChanges = true;
    });

    scheduleAutoSave();
  }

  String guessMimeType(
    String name,
  ) {
    final lower =
        name.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.svg')) {
      return 'image/svg+xml';
    }

    if (lower.endsWith('.mp3')) {
      return 'audio/mpeg';
    }

    if (lower.endsWith('.wav')) {
      return 'audio/wav';
    }

    if (lower.endsWith('.ogg')) {
      return 'audio/ogg';
    }

    if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    }

    if (lower.endsWith('.webm')) {
      return 'video/webm';
    }

    return 'application/octet-stream';
  }

  Future<void> deleteAsset(
    String path,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('حذف Asset؟'),
          content: Text(
            'سيتم حذف "$path".',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('إلغاء'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    pushUndo();

    assets.remove(path);

    setState(() {
      hasChanges = true;
    });

    scheduleAutoSave();
  }

  Widget buildExplorerItem(
    String path,
  ) {
    final selected =
        currentFile == path;

    return ListTile(
      dense: true,
      selected: selected,
      leading: Icon(
        fileIcon(path),
        size: 19,
      ),
      title: Text(
        path,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
      ),
      onTap: () {
        setState(() {
          currentFile = path;
        });

        Navigator.pop(context);
      },
    );
  }

  Future<void> openFileExplorer() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor:
          Theme.of(context)
              .scaffoldBackgroundColor,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: .88,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    4,
                    18,
                    10,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Project Files',
                          style:
                              TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip:
                            'ملف جديد',
                        onPressed:
                            createFile,
                        icon: const Icon(
                          Icons
                              .note_add_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip:
                            'مجلد جديد',
                        onPressed:
                            createFolder,
                        icon: const Icon(
                          Icons
                              .create_new_folder_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip:
                            'إضافة Assets',
                        onPressed:
                            addAssets,
                        icon: const Icon(
                          Icons
                              .perm_media_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      ListView(
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          6,
                        ),
                        child: Text(
                          'FILES',
                          style:
                              TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ),
                      for (final path
                          in files.keys)
                        buildExplorerItem(
                          path,
                        ),
                      if (folders.isNotEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.fromLTRB(
                            20,
                            14,
                            20,
                            6,
                          ),
                          child: Text(
                            'FOLDERS',
                            style:
                                TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                      for (final folder
                          in folders)
                        ListTile(
                          dense: true,
                          leading:
                              const Icon(
                            Icons
                                .folder_rounded,
                          ),
                          title:
                              Text(folder),
                        ),
                      if (assets.isNotEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.fromLTRB(
                            20,
                            14,
                            20,
                            6,
                          ),
                          child: Text(
                            'ASSETS',
                            style:
                                TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                      for (final asset
                          in assets.keys)
                        ListTile(
                          dense: true,
                          leading:
                              Icon(
                            fileIcon(
                              asset,
                            ),
                          ),
                          title:
                              Text(asset),
                          trailing:
                              IconButton(
                            onPressed:
                                () =>
                                    deleteAsset(
                                  asset,
                                ),
                            icon:
                                const Icon(
                              Icons
                                  .delete_outline_rounded,
                              color:
                                  Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTopBar() {
    final primary =
        Theme.of(context)
            .colorScheme
            .primary;

    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.fromLTRB(
            8,
            6,
            8,
            6,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  autoSaveTimer?.cancel();
                  await saveProject();

                  if (!mounted) {
                    return;
                  }

                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons
                      .arrow_back_rounded,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      widget.project.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    Text(
                      currentFile,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Undo',
                onPressed:
                    undoStack.isEmpty
                        ? null
                        : undo,
                icon: const Icon(
                  Icons.undo_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed:
                    redoStack.isEmpty
                        ? null
                        : redo,
                icon: const Icon(
                  Icons.redo_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Files',
                onPressed:
                    openFileExplorer,
                icon: const Icon(
                  Icons
                      .folder_copy_rounded,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin:
              const EdgeInsets.fromLTRB(
            12,
            2,
            12,
            8,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration:
              BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: Row(
            children: [
              Icon(
                fileIcon(currentFile),
                size: 19,
                color: primary,
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  currentFile,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                visualDensity:
                    VisualDensity.compact,
                tooltip:
                    'إعادة تسمية',
                onPressed:
                    renameCurrent,
                icon: const Icon(
                  Icons
                      .drive_file_rename_outline_rounded,
                  size: 19,
                ),
              ),
              IconButton(
                visualDensity:
                    VisualDensity.compact,
                tooltip: 'حذف',
                onPressed:
                    deleteCurrent,
                icon: const Icon(
                  Icons
                      .delete_outline_rounded,
                  size: 19,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildLanButton() {
    if (!lanRunning) {
      return Container(
        margin:
            const EdgeInsets.fromLTRB(
          12,
          2,
          12,
          8,
        ),
        child: Material(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          child: InkWell(
            onTap: startLan,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(
                14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                        BoxDecoration(
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .primary
                          .withOpacity(.12),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .wifi_tethering_rounded,
                      color:
                          Theme.of(
                        context,
                      )
                              .colorScheme
                              .primary,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'LAN SERVER',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .w900,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          height: 3,
                        ),
                        Text(
                          'شارك لعبتك مع الأجهزة على نفس الشبكة',
                          style:
                              TextStyle(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: startLan,
                    icon: const Icon(
                      Icons
                          .play_arrow_rounded,
                    ),
                    label:
                        const Text(
                      'تشغيل',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        12,
        2,
        12,
        8,
      ),
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: Colors.green
              .withOpacity(.28),
        ),
        color: Colors.green
            .withOpacity(.07),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: Colors.green
                      .withOpacity(.12),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .wifi_tethering_rounded,
                  color:
                      Colors.green,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'LAN SERVER',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    SizedBox(
                      height: 2,
                    ),
                    Text(
                      '● يعمل الآن',
                      style:
                          TextStyle(
                        color:
                            Colors.green,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    stopLan,
                style:
                    OutlinedButton
                        .styleFrom(
                  foregroundColor:
                      Colors.red,
                  side:
                      const BorderSide(
                    color:
                        Colors.red,
                  ),
                ),
                icon:
                    const Icon(
                  Icons
                      .stop_rounded,
                  size: 18,
                ),
                label:
                    const Text(
                  'إيقاف',
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          InkWell(
            onTap: showLanPanel,
            borderRadius:
                BorderRadius.circular(
              12,
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                11,
              ),
              decoration:
                  BoxDecoration(
                color: Theme.of(
                  context,
                )
                    .colorScheme
                    .surface
                    .withOpacity(.65),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Text(
                      lanUrl ?? '',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons
                        .open_in_new_rounded,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (!settingsLoaded) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (previewMode) {
      return Scaffold(
        backgroundColor:
            Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(
                controller:
                    webViewController,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: Material(
                  color:
                      Colors.transparent,
                  child: InkWell(
                    onTap:
                        closePreview,
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                    child:
                        Container(
                      width: 42,
                      height: 42,
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .black
                            .withOpacity(
                          .65,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .close_rounded,
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (didPop, result) async {
        if (didPop) {
          return;
        }

        autoSaveTimer?.cancel();

        await saveProject();

        if (!mounted) {
          return;
        }

        Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Editor',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          actions: [
            Padding(
              padding:
                  const EdgeInsets.only(
                right: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    hasChanges
                        ? Icons
                            .cloud_upload_outlined
                        : Icons
                            .cloud_done_rounded,
                    size: 17,
                    color: hasChanges
                        ? Theme.of(
                            context,
                          )
                            .colorScheme
                            .onSurfaceVariant
                        : Theme.of(
                            context,
                          )
                            .colorScheme
                            .primary,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    hasChanges
                        ? 'Saving'
                        : 'Saved',
                    style:
                        const TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip:
                  'Preview',
              onPressed:
                  openPreview,
              icon:
                  const Icon(
                Icons
                    .play_arrow_rounded,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            buildTopBar(),
            buildLanButton(),
            buildCodeEditor(),
          ],
        ),
        floatingActionButton:
            FloatingActionButton.extended(
          onPressed:
              openPreview,
          icon:
              const Icon(
            Icons
                .play_arrow_rounded,
          ),
          label:
              const Text(
            'Preview',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    autoSaveTimer?.cancel();
    previewTimer?.cancel();

    for (final controller
        in controllers.values) {
      controller.dispose();
    }

    if (lanRunning) {
      LanServerService.instance
          .stop();
    }

    super.dispose();
  }
}
