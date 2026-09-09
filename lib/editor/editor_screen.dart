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

class _EditorSnapshot {
  final Map<String, String> files;
  final List<String> folders;
  final Map<String, ProjectAsset> assets;
  final String currentFile;

  _EditorSnapshot({
    required this.files,
    required this.folders,
    required this.assets,
    required this.currentFile,
  });

  _EditorSnapshot copy() {
    return _EditorSnapshot(
      files: Map<String, String>.from(files),
      folders: List<String>.from(folders),
      assets: Map<String, ProjectAsset>.from(assets),
      currentFile: currentFile,
    );
  }
}

class _EditorScreenState extends State<EditorScreen> {
  final Map<String, CodeController> controllers = {};

  late WebViewController webViewController;

  Map<String, String> files = {};
  List<String> folders = [];
  Map<String, ProjectAsset> assets = {};

  String currentFile = 'index.html';

  bool previewMode = false;
  bool singleFileMode = false;
  bool settingsLoaded = false;
  bool isSaving = false;
  bool hasChanges = false;
  bool lanRunning = false;
  bool restoring = false;

  String? lanUrl;

  Timer? autoSaveTimer;
  Timer? previewTimer;
  Timer? historyTimer;

  final List<_EditorSnapshot> undoStack = [];
  final List<_EditorSnapshot> redoStack = [];

  _EditorSnapshot? lastCommittedSnapshot;
  bool historyBatchActive = false;

  @override
  void initState() {
    super.initState();

    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (!mounted || !previewMode) {
              return;
            }

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
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('singleFileMode') ?? false;

    final sourceFiles = Map<String, String>.from(widget.project.files);

    if (sourceFiles.isEmpty) {
      sourceFiles['index.html'] = widget.project.html;
      sourceFiles['style.css'] = widget.project.css;
      sourceFiles['game.js'] = widget.project.js;
    }

    if (enabled) {
      final html = sourceFiles['index.html'] ?? widget.project.html;

      sourceFiles
        ..clear()
        ..['index.html'] = html;
    }

    files = sourceFiles;
    folders = List<String>.from(widget.project.folders);
    assets = Map<String, ProjectAsset>.from(widget.project.assets);

    ensureProjectFolders();

    if (!files.containsKey('index.html')) {
      files['index.html'] = '';
    }

    if (!files.containsKey(currentFile)) {
      currentFile = files.keys.first;
    }

    rebuildControllers();

    lastCommittedSnapshot = snapshot();

    if (!mounted) {
      return;
    }

    setState(() {
      singleFileMode = enabled;
      settingsLoaded = true;
    });
  }

  void ensureProjectFolders() {
    final all = <String>{...folders};

    for (final path in [
      ...files.keys,
      ...assets.keys,
    ]) {
      final parts = normalizePath(path).split('/');

      if (parts.length < 2) {
        continue;
      }

      for (var i = 1; i < parts.length; i++) {
        all.add(parts.sublist(0, i).join('/'));
      }
    }

    folders = all.toList()..sort();
  }

  String normalizePath(String path) {
    var value = path.trim().replaceAll('\\', '/');

    while (value.startsWith('/')) {
      value = value.substring(1);
    }

    while (value.contains('//')) {
      value = value.replaceAll('//', '/');
    }

    final parts = <String>[];

    for (final part in value.split('/')) {
      if (part.isEmpty || part == '.') {
        continue;
      }

      if (part == '..') {
        if (parts.isNotEmpty) {
          parts.removeLast();
        }
        continue;
      }

      parts.add(part);
    }

    return parts.join('/');
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

  CodeController createCodeController(
    String path,
    String text,
  ) {
    final language = languageFor(path);

    if (language == 'css') {
      return CodeController(
        text: text,
        language: css.css,
      );
    }

    if (language == 'js') {
      return CodeController(
        text: text,
        language: javascript.javascript,
      );
    }

    if (language == 'html') {
      return CodeController(
        text: text,
        language: xml.xml,
      );
    }

    return CodeController(text: text);
  }

  void rebuildControllers() {
    for (final controller in controllers.values) {
      controller.dispose();
    }

    controllers.clear();

    for (final entry in files.entries) {
      final path = entry.key;
      final controller = createCodeController(
        path,
        entry.value,
      );

      controller.addListener(() {
        if (restoring || controllers[path] != controller) {
          return;
        }

        final oldValue = files[path];

        if (oldValue == controller.text) {
          return;
        }

        if (!historyBatchActive) {
          historyBatchActive = true;

          if (lastCommittedSnapshot != null) {
            undoStack.add(lastCommittedSnapshot!.copy());

            if (undoStack.length > 100) {
              undoStack.removeAt(0);
            }

            redoStack.clear();
          }
        }

        files[path] = controller.text;
        hasChanges = true;

        historyTimer?.cancel();

        historyTimer = Timer(
          const Duration(milliseconds: 650),
          () {
            historyBatchActive = false;
            lastCommittedSnapshot = snapshot();
          },
        );

        scheduleAutoSave();
        schedulePreview();

        if (lanRunning) {
          updateLan();
        }

        if (mounted) {
          setState(() {});
        }
      });

      controllers[path] = controller;
    }
  }

  _EditorSnapshot snapshot() {
    return _EditorSnapshot(
      files: Map<String, String>.from(files),
      folders: List<String>.from(folders),
      assets: Map<String, ProjectAsset>.from(assets),
      currentFile: currentFile,
    );
  }

  void finishHistoryBatch() {
    historyTimer?.cancel();

    if (historyBatchActive) {
      historyBatchActive = false;
      lastCommittedSnapshot = snapshot();
    }
  }

  void pushStructuralHistory() {
    finishHistoryBatch();

    if (lastCommittedSnapshot != null) {
      undoStack.add(lastCommittedSnapshot!.copy());

      if (undoStack.length > 100) {
        undoStack.removeAt(0);
      }
    }

    redoStack.clear();
  }

  void restoreSnapshot(_EditorSnapshot state) {
    restoring = true;

    for (final controller in controllers.values) {
      controller.dispose();
    }

    controllers.clear();

    files = Map<String, String>.from(state.files);
    folders = List<String>.from(state.folders);
    assets = Map<String, ProjectAsset>.from(state.assets);
    currentFile = state.currentFile;

    ensureProjectFolders();

    if (files.isEmpty) {
      files['index.html'] = '';
    }

    if (!files.containsKey(currentFile)) {
      currentFile = files.keys.first;
    }

    rebuildControllers();

    restoring = false;
    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    if (mounted) {
      setState(() {});
    }

    scheduleAutoSave();

    if (lanRunning) {
      updateLan();
    }
  }

  void undo() {
    finishHistoryBatch();

    if (undoStack.isEmpty) {
      return;
    }

    redoStack.add(snapshot());

    final target = undoStack.removeLast();

    restoreSnapshot(target);
  }

  void redo() {
    finishHistoryBatch();

    if (redoStack.isEmpty) {
      return;
    }

    undoStack.add(snapshot());

    final target = redoStack.removeLast();

    restoreSnapshot(target);
  }

  Future<void> saveProject({
    bool showMessage = false,
  }) async {
    if (isSaving) {
      return;
    }

    isSaving = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      final project = Project(
        name: widget.project.name,
        html: files['index.html'] ?? '',
        css: files['style.css'] ?? '',
        js: files['game.js'] ?? '',
        files: Map<String, String>.from(files),
        folders: List<String>.from(folders),
        assets: Map<String, ProjectAsset>.from(assets),
      );

      final projects = prefs.getStringList('projects') ?? [];
      final encoded = jsonEncode(project.toJson());

      var index = -1;

      for (var i = 0; i < projects.length; i++) {
        try {
          final decoded = jsonDecode(projects[i]);

          if (decoded is Map &&
              decoded['name']?.toString() == widget.project.name) {
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

      await prefs.setStringList('projects', projects);

      hasChanges = false;
      lastCommittedSnapshot = snapshot();

      widget.onSaved?.call();

      if (mounted) {
        setState(() {});
      }

      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ ✓'),
            behavior: SnackBarBehavior.floating,
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
      const Duration(milliseconds: 800),
      () => saveProject(),
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

  String get currentCode {
    return files[currentFile] ?? '';
  }

  String buildPreviewDocument() {
    var html = files['index.html'] ?? '';
    final cssCode = files['style.css'] ?? '';
    final jsCode = files['game.js'] ?? '';

    final referencedCss = <String>{};
    final referencedJs = <String>{};

    final linkRegex = RegExp(
      r'<link[^>]+href=["']([^"']+)["'][^>]*>',
      caseSensitive: false,
    );

    for (final match in linkRegex.allMatches(html)) {
      final path = normalizeReference(match.group(1)!);

      if (files.containsKey(path) &&
          path.toLowerCase().endsWith('.css')) {
        referencedCss.add(path);

        html = html.replaceFirst(
          match.group(0)!,
          '<style>\n${files[path]}\n</style>',
        );
      }
    }

    final scriptRegex = RegExp(
      r'<script[^>]+src=["\']([^"\']+)["\'][^>]*>\s*</script>',
      caseSensitive: false,
    );

    for (final match in scriptRegex.allMatches(html)) {
      final path = normalizeReference(match.group(1)!);

      if (files.containsKey(path) &&
          path.toLowerCase().endsWith('.js')) {
        referencedJs.add(path);

        html = html.replaceFirst(
          match.group(0)!,
          '<script>\n${files[path]}\n</script>',
        );
      }
    }

    final hasHtml = RegExp(
      r'<html[\s>]',
      caseSensitive: false,
    ).hasMatch(html);

    if (!singleFileMode) {
      if (!referencedCss.contains('style.css') &&
          cssCode.trim().isNotEmpty) {
        html = injectBefore(
          html,
          '</head>',
          '<style>\n$cssCode\n</style>',
        );
      }

      if (!referencedJs.contains('game.js') &&
          jsCode.trim().isNotEmpty) {
        html = injectBefore(
          html,
          '</body>',
          '<script>\n$jsCode\n</script>',
        );
      }
    }

    if (!hasHtml) {
      html = '''<!doctype html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
</head>
<body>
$html
</body>
</html>''';
    }

    html = replaceAssetPaths(html);

    return html;
  }

  String injectBefore(
    String html,
    String marker,
    String content,
  ) {
    final regex = RegExp(
      marker,
      caseSensitive: false,
    );

    if (regex.hasMatch(html)) {
      return html.replaceFirst(
        regex,
        '$content\n$marker',
      );
    }

    return '$html\n$content';
  }

  String normalizeReference(String value) {
    var path = value.trim();

    path = path.split('?').first;
    path = path.split('#').first;

    return normalizePath(path);
  }

  String replaceAssetPaths(String html) {
    var result = html;

    for (final entry in assets.entries) {
      final asset = entry.value;

      final uri =
          'data:${asset.mimeType};base64,${asset.base64Data}';

      final path = entry.key;

      result = result.replaceAll(path, uri);
      result = result.replaceAll('./$path', uri);
      result = result.replaceAll('/$path', uri);
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

        if (!box) {
          box = document.createElement("pre");
          box.id = "wgs-error";
          box.style.position = "fixed";
          box.style.left = "10px";
          box.style.right = "10px";
          box.style.bottom = "10px";
          box.style.zIndex = "999999";
          box.style.padding = "12px";
          box.style.background = "#8b0000";
          box.style.color = "#fff";
          box.style.borderRadius = "12px";
          document.body.appendChild(box);
        }

        box.textContent = ${jsonEncode(message)};
      })();
    ''');
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

  void closePreview() {
    previewTimer?.cancel();

    setState(() {
      previewMode = false;
    });
  }

  Map<String, String> buildServerFiles() {
    final result = Map<String, String>.from(files);
    result['index.html'] = buildPreviewDocument();
    return result;
  }

  Map<String, String> buildAssetData() {
    return {
      for (final entry in assets.entries)
        entry.key: entry.value.base64Data,
    };
  }

  Map<String, String> buildAssetMime() {
    return {
      for (final entry in assets.entries)
        entry.key: entry.value.mimeType,
    };
  }

  Future<void> updateLan() async {
    if (!lanRunning) {
      return;
    }

    await LanServerService.instance.update(
      html: files['index.html'] ?? '',
      css: files['style.css'] ?? '',
      js: files['game.js'] ?? '',
      singleFile: singleFileMode,
      files: buildServerFiles(),
      assetData: buildAssetData(),
      assetMime: buildAssetMime(),
    );
  }

  Future<void> startLan() async {
    try {
      await saveProject();

      final url = await LanServerService.instance.start(
        projectId: widget.project.name,
        html: files['index.html'] ?? '',
        css: files['style.css'] ?? '',
        js: files['game.js'] ?? '',
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
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تشغيل السيرفر: $e'),
          behavior: SnackBarBehavior.floating,
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

  Future<String?> askText({
    required String title,
    String initial = '',
    String hint = '',
    String action = 'حفظ',
  }) async {
    final controller = TextEditingController(text: initial);

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(
                  context,
                  value.trim(),
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              child: Text(action),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return value;
  }

  void ensureParentFolders(String path) {
    final normalized = normalizePath(path);
    final parts = normalized.split('/');

    if (parts.length < 2) {
      return;
    }

    for (var i = 1; i < parts.length; i++) {
      final folder = parts.sublist(0, i).join('/');

      if (!folders.contains(folder)) {
        folders.add(folder);
      }
    }

    folders.sort();
  }

  Future<void> createFile() async {
    final value = await askText(
      title: 'ملف جديد',
      hint: 'scripts/player.js',
      action: 'إنشاء',
    );

    if (value == null) {
      return;
    }

    final path = normalizePath(value);

    if (path.isEmpty ||
        files.containsKey(path) ||
        assets.containsKey(path)) {
      return;
    }

    pushStructuralHistory();

    ensureParentFolders(path);

    files[path] = '';

    controllers[path] = createCodeController(
      path,
      '',
    );

    final controller = controllers[path]!;

    controller.addListener(() {
      if (restoring || controllers[path] != controller) {
        return;
      }

      if (files[path] == controller.text) {
        return;
      }

      if (!historyBatchActive) {
        historyBatchActive = true;

        if (lastCommittedSnapshot != null) {
          undoStack.add(lastCommittedSnapshot!.copy());
          redoStack.clear();
        }
      }

      files[path] = controller.text;
      hasChanges = true;

      historyTimer?.cancel();

      historyTimer = Timer(
        const Duration(milliseconds: 650),
        () {
          historyBatchActive = false;
          lastCommittedSnapshot = snapshot();
        },
      );

      scheduleAutoSave();
      schedulePreview();
    });

    currentFile = path;
    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<void> createFolder() async {
    final value = await askText(
      title: 'مجلد جديد',
      hint: 'scripts',
      action: 'إنشاء',
    );

    if (value == null) {
      return;
    }

    final path = normalizePath(value);

    if (path.isEmpty || folders.contains(path)) {
      return;
    }

    pushStructuralHistory();

    folders.add(path);
    folders.sort();

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<void> renameFile(String oldPath) async {
    if (!files.containsKey(oldPath)) {
      return;
    }

    final value = await askText(
      title: 'إعادة تسمية الملف',
      initial: oldPath,
      hint: 'scripts/player.js',
      action: 'تغيير',
    );

    if (value == null) {
      return;
    }

    final newPath = normalizePath(value);

    if (newPath.isEmpty ||
        newPath == oldPath ||
        files.containsKey(newPath) ||
        assets.containsKey(newPath)) {
      return;
    }

    pushStructuralHistory();

    final content = files.remove(oldPath)!;

    controllers[oldPath]?.dispose();
    controllers.remove(oldPath);

    files[newPath] = content;
    ensureParentFolders(newPath);

    rebuildControllers();

    if (currentFile == oldPath) {
      currentFile = newPath;
    }

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<void> renameAsset(String oldPath) async {
    final asset = assets[oldPath];

    if (asset == null) {
      return;
    }

    final value = await askText(
      title: 'إعادة تسمية Asset',
      initial: oldPath,
      hint: 'assets/player.png',
      action: 'تغيير',
    );

    if (value == null) {
      return;
    }

    final newPath = normalizePath(value);

    if (newPath.isEmpty ||
        newPath == oldPath ||
        assets.containsKey(newPath) ||
        files.containsKey(newPath)) {
      return;
    }

    pushStructuralHistory();

    assets.remove(oldPath);

    assets[newPath] = ProjectAsset(
      path: newPath,
      mimeType: asset.mimeType,
      base64Data: asset.base64Data,
    );

    ensureParentFolders(newPath);

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<void> moveAsset(String oldPath) async {
    final asset = assets[oldPath];

    if (asset == null) {
      return;
    }

    final folder = await askText(
      title: 'نقل Asset إلى مجلد',
      initial: oldPath.contains('/')
          ? oldPath.substring(
              0,
              oldPath.lastIndexOf('/'),
            )
          : 'assets',
      hint: 'assets/images',
      action: 'نقل',
    );

    if (folder == null) {
      return;
    }

    final targetFolder = normalizePath(folder);

    final fileName = oldPath.split('/').last;

    final newPath = targetFolder.isEmpty
        ? fileName
        : '$targetFolder/$fileName';

    if (newPath == oldPath || assets.containsKey(newPath)) {
      return;
    }

    pushStructuralHistory();

    assets.remove(oldPath);

    assets[newPath] = ProjectAsset(
      path: newPath,
      mimeType: asset.mimeType,
      base64Data: asset.base64Data,
    );

    ensureParentFolders(newPath);

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<void> moveFile(String oldPath) async {
    if (!files.containsKey(oldPath)) {
      return;
    }

    final folder = await askText(
      title: 'نقل الملف إلى مجلد',
      initial: oldPath.contains('/')
          ? oldPath.substring(
              0,
              oldPath.lastIndexOf('/'),
            )
          : '',
      hint: 'scripts',
      action: 'نقل',
    );

    if (folder == null) {
      return;
    }

    final targetFolder = normalizePath(folder);
    final fileName = oldPath.split('/').last;

    final newPath = targetFolder.isEmpty
        ? fileName
        : '$targetFolder/$fileName';

    if (newPath == oldPath ||
        files.containsKey(newPath) ||
        assets.containsKey(newPath)) {
      return;
    }

    pushStructuralHistory();

    final content = files.remove(oldPath)!;

    files[newPath] = content;

    controllers[oldPath]?.dispose();
    controllers.remove(oldPath);

    ensureParentFolders(newPath);
    rebuildControllers();

    if (currentFile == oldPath) {
      currentFile = newPath;
    }

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<void> deleteFile(String path) async {
    if (!files.containsKey(path)) {
      return;
    }

    final confirmed = await confirmDelete(
      'حذف الملف؟',
      'سيتم حذف $path',
    );

    if (!confirmed) {
      return;
    }

    pushStructuralHistory();

    files.remove(path);

    controllers[path]?.dispose();
    controllers.remove(path);

    if (files.isEmpty) {
      files['index.html'] = '';
      rebuildControllers();
    }

    if (!files.containsKey(currentFile)) {
      currentFile = files.keys.first;
    }

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<void> deleteAsset(String path) async {
    if (!assets.containsKey(path)) {
      return;
    }

    final confirmed = await confirmDelete(
      'حذف Asset؟',
      'سيتم حذف $path',
    );

    if (!confirmed) {
      return;
    }

    pushStructuralHistory();

    assets.remove(path);

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<void> renameFolder(String oldPath) async {
    if (!folders.contains(oldPath)) {
      return;
    }

    final value = await askText(
      title: 'إعادة تسمية المجلد',
      initial: oldPath,
      hint: 'scripts',
      action: 'تغيير',
    );

    if (value == null) {
      return;
    }

    final newPath = normalizePath(value);

    if (newPath.isEmpty ||
        newPath == oldPath ||
        folders.contains(newPath)) {
      return;
    }

    pushStructuralHistory();

    final updatedFolders = <String>{};

    for (final folder in folders) {
      if (folder == oldPath ||
          folder.startsWith('$oldPath/')) {
        updatedFolders.add(
          newPath + folder.substring(oldPath.length),
        );
      } else {
        updatedFolders.add(folder);
      }
    }

    final updatedFiles = <String, String>{};

    for (final entry in files.entries) {
      final path = entry.key;

      if (path == oldPath ||
          path.startsWith('$oldPath/')) {
        updatedFiles[
          newPath + path.substring(oldPath.length)
        ] = entry.value;
      } else {
        updatedFiles[path] = entry.value;
      }
    }

    final updatedAssets = <String, ProjectAsset>{};

    for (final entry in assets.entries) {
      final path = entry.key;

      if (path == oldPath ||
          path.startsWith('$oldPath/')) {
        final movedPath =
            newPath + path.substring(oldPath.length);

        final asset = entry.value;

        updatedAssets[movedPath] = ProjectAsset(
          path: movedPath,
          mimeType: asset.mimeType,
          base64Data: asset.base64Data,
        );
      } else {
        updatedAssets[path] = entry.value;
      }
    }

    files = updatedFiles;
    assets = updatedAssets;
    folders = updatedFolders.toList()..sort();

    if (currentFile == oldPath ||
        currentFile.startsWith('$oldPath/')) {
      currentFile =
          newPath + currentFile.substring(oldPath.length);
    }

    rebuildControllers();

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<void> deleteFolder(String path) async {
    final confirmed = await confirmDelete(
      'حذف المجلد؟',
      'سيتم حذف كل ما بداخله:\n$path',
    );

    if (!confirmed) {
      return;
    }

    pushStructuralHistory();

    files.removeWhere(
      (key, _) =>
          key == path || key.startsWith('$path/'),
    );

    assets.removeWhere(
      (key, _) =>
          key == path || key.startsWith('$path/'),
    );

    folders.removeWhere(
      (folder) =>
          folder == path || folder.startsWith('$path/'),
    );

    if (files.isEmpty) {
      files['index.html'] = '';
    }

    rebuildControllers();

    if (!files.containsKey(currentFile)) {
      currentFile = files.keys.first;
    }

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();
  }

  Future<bool> confirmDelete(
    String title,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> addAssets() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );

    if (result == null) {
      return;
    }

    final selected = result.files.where(
      (file) => file.bytes != null && file.name.trim().isNotEmpty,
    );

    if (selected.isEmpty) {
      return;
    }

    pushStructuralHistory();

    for (final file in selected) {
      final bytes = file.bytes!;

      var name = file.name.trim();
      var path = normalizePath('assets/$name');

      var counter = 2;

      while (assets.containsKey(path) ||
          files.containsKey(path)) {
        final dot = name.lastIndexOf('.');

        if (dot > 0) {
          path = normalizePath(
            'assets/${name.substring(0, dot)}_$counter${name.substring(dot)}',
          );
        } else {
          path = normalizePath(
            'assets/${name}_$counter',
          );
        }

        counter++;
      }

      assets[path] = ProjectAsset(
        path: path,
        mimeType: guessMimeType(name),
        base64Data: base64Encode(bytes),
      );

      ensureParentFolders(path);
    }

    hasChanges = true;
    lastCommittedSnapshot = snapshot();

    setState(() {});
    scheduleAutoSave();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة ${selected.length} Asset ✓',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String guessMimeType(String name) {
    final lower = name.toLowerCase();

    const types = <String, String>{
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.bmp': 'image/bmp',
      '.svg': 'image/svg+xml',
      '.ico': 'image/x-icon',
      '.mp3': 'audio/mpeg',
      '.ogg': 'audio/ogg',
      '.oga': 'audio/ogg',
      '.wav': 'audio/wav',
      '.m4a': 'audio/mp4',
      '.aac': 'audio/aac',
      '.flac': 'audio/flac',
      '.opus': 'audio/opus',
      '.weba': 'audio/webm',
      '.mp4': 'video/mp4',
      '.webm': 'video/webm',
      '.mov': 'video/quicktime',
      '.json': 'application/json',
      '.txt': 'text/plain',
      '.pdf': 'application/pdf',
    };

    for (final entry in types.entries) {
      if (lower.endsWith(entry.key)) {
        return entry.value;
      }
    }

    return 'application/octet-stream';
  }

  bool isImage(String path) {
    return guessMimeType(path).startsWith('image/');
  }

  bool isAudio(String path) {
    return guessMimeType(path).startsWith('audio/');
  }

  bool isVideo(String path) {
    return guessMimeType(path).startsWith('video/');
  }

  IconData fileIcon(String path) {
    final lower = path.toLowerCase();

    if (isImage(path)) {
      return Icons.image_rounded;
    }

    if (isAudio(path)) {
      return Icons.audiotrack_rounded;
    }

    if (isVideo(path)) {
      return Icons.movie_rounded;
    }

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

    if (lower.endsWith('.json')) {
      return Icons.data_object_rounded;
    }

    return Icons.insert_drive_file_rounded;
  }

  Future<void> previewAsset(String path) async {
    final asset = assets[path];

    if (asset == null) {
      return;
    }

    if (isImage(path)) {
      await showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: InteractiveViewer(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.memory(
                  base64Decode(asset.base64Data),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      );

      return;
    }

    if (isAudio(path) || isVideo(path)) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted);

      final tag = isAudio(path) ? 'audio' : 'video';

      final controls = isAudio(path)
          ? 'controls autoplay'
          : 'controls autoplay playsinline';

      await controller.loadHtmlString('''
<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body {
  margin: 0;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #111;
}
$tag {
  width: 90%;
}
</style>
</head>
<body>
<$tag $controls src="data:${asset.mimeType};base64,${asset.base64Data}"></$tag>
</body>
</html>
''');

      if (!mounted) {
        return;
      }

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(path.split('/').last),
            content: SizedBox(
              width: double.maxFinite,
              height: 100,
              child: WebViewWidget(
                controller: controller,
              ),
            ),
          );
        },
      );

      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(path.split('/').last),
            content: const Text(
              'لا توجد معاينة لهذا النوع من الملفات.',
            ),
          );
        },
      );
    }
  }

  List<String> explorerEntries() {
    final entries = <String>{
      ...folders,
      ...files.keys,
      ...assets.keys,
    };

    final list = entries.toList();

    list.sort((a, b) {
      final ad = a.split('/').length;
      final bd = b.split('/').length;

      if (ad != bd) {
        return ad.compareTo(bd);
      }

      return a.toLowerCase().compareTo(
            b.toLowerCase(),
          );
    });

    return list;
  }

  bool isFolder(String path) {
    return folders.contains(path);
  }

  bool isAsset(String path) {
    return assets.containsKey(path);
  }

  int pathDepth(String path) {
    return path.split('/').length - 1;
  }

  Future<String?> showEntryMenu(
    String path,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final folder = isFolder(path);
        final asset = isAsset(path);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  folder
                      ? Icons.folder_rounded
                      : fileIcon(path),
                ),
                title: Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              if (asset && (isImage(path) || isAudio(path) || isVideo(path)))
                ListTile(
                  leading: const Icon(
                    Icons.visibility_rounded,
                  ),
                  title: const Text('معاينة'),
                  onTap: () => Navigator.pop(
                    context,
                    'preview',
                  ),
                ),
              if (!folder)
                ListTile(
                  leading: const Icon(
                    Icons.drive_file_rename_outline_rounded,
                  ),
                  title: const Text('إعادة تسمية'),
                  onTap: () => Navigator.pop(
                    context,
                    'rename',
                  ),
                ),
              if (!folder)
                ListTile(
                  leading: const Icon(
                    Icons.drive_file_move_rounded,
                  ),
                  title: const Text('نقل إلى مجلد'),
                  onTap: () => Navigator.pop(
                    context,
                    'move',
                  ),
                ),
              if (folder)
                ListTile(
                  leading: const Icon(
                    Icons.drive_file_rename_outline_rounded,
                  ),
                  title: const Text('إعادة تسمية المجلد'),
                  onTap: () => Navigator.pop(
                    context,
                    'rename',
                  ),
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  'حذف',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
                onTap: () => Navigator.pop(
                  context,
                  'delete',
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    return result;
  }

  Future<void> handleEntryAction(
    String path,
  ) async {
    final action = await showEntryMenu(path);

    if (action == 'preview') {
      await previewAsset(path);
      return;
    }

    if (action == 'rename') {
      if (isFolder(path)) {
        await renameFolder(path);
      } else if (isAsset(path)) {
        await renameAsset(path);
      } else {
        await renameFile(path);
      }

      return;
    }

    if (action == 'move') {
      if (isAsset(path)) {
        await moveAsset(path);
      } else {
        await moveFile(path);
      }

      return;
    }

    if (action == 'delete') {
      if (isFolder(path)) {
        await deleteFolder(path);
      } else if (isAsset(path)) {
        await deleteAsset(path);
      } else {
        await deleteFile(path);
      }
    }
  }

  Future<void> openFileExplorer() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final entries = explorerEntries();

            return FractionallySizedBox(
              heightFactor: .9,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        4,
                        18,
                        10,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Project',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'الملفات والـ Assets',
                                  style: TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'ملف جديد',
                            onPressed: () async {
                              await createFile();
                              sheetSetState(() {});
                            },
                            icon: const Icon(
                              Icons.note_add_rounded,
                            ),
                          ),
                          IconButton(
                            tooltip: 'مجلد جديد',
                            onPressed: () async {
                              await createFolder();
                              sheetSetState(() {});
                            },
                            icon: const Icon(
                              Icons.create_new_folder_rounded,
                            ),
                          ),
                          IconButton(
                            tooltip: 'إضافة Assets',
                            onPressed: () async {
                              await addAssets();
                              sheetSetState(() {});
                            },
                            icon: const Icon(
                              Icons.perm_media_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        10,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'اضغط على الملف لفتحه، أو اضغط مطولًا لإدارته.',
                                style: TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final path = entries[index];
                          final folder = isFolder(path);
                          final asset = isAsset(path);
                          final depth = pathDepth(path);
                          final selected =
                              currentFile == path;

                          return Padding(
                            padding: EdgeInsets.only(
                              left: 8.0 + depth * 18,
                              right: 8,
                            ),
                            child: ListTile(
                              dense: true,
                              selected: selected,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              leading: Icon(
                                folder
                                    ? Icons.folder_rounded
                                    : fileIcon(path),
                                color: folder
                                    ? Colors.amber
                                    : null,
                              ),
                              title: Text(
                                path.split('/').last,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                              subtitle: depth > 0
                                  ? Text(
                                      path,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style:
                                          const TextStyle(
                                        fontSize: 10,
                                      ),
                                    )
                                  : null,
                              trailing: IconButton(
                                tooltip: 'خيارات',
                                onPressed: () async {
                                  await handleEntryAction(path);
                                  sheetSetState(() {});
                                },
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                ),
                              ),
                              onTap: () {
                                if (folder) {
                                  return;
                                }

                                if (asset) {
                                  if (isImage(path) ||
                                      isAudio(path) ||
                                      isVideo(path)) {
                                    previewAsset(path);
                                  }

                                  return;
                                }

                                setState(() {
                                  currentFile = path;
                                });

                                Navigator.pop(sheetContext);
                              },
                              onLongPress: () async {
                                await handleEntryAction(path);
                                sheetSetState(() {});
                              },
                            ),
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

  Widget buildEditorHeader() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        6,
        12,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: openFileExplorer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        fileIcon(currentFile),
                        size: 19,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentFile,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Undo',
            onPressed: undoStack.isEmpty ? null : undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: redoStack.isEmpty ? null : redo,
            icon: const Icon(Icons.redo_rounded),
          ),
        ],
      ),
    );
  }

  Widget buildLanBar() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        8,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: lanRunning
              ? Colors.green.withOpacity(.08)
              : scheme.surfaceContainerHighest,
          border: lanRunning
              ? Border.all(
                  color: Colors.green.withOpacity(.25),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              lanRunning
                  ? Icons.wifi_tethering_rounded
                  : Icons.wifi_off_rounded,
              size: 19,
              color: lanRunning
                  ? Colors.green
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    lanRunning
                        ? 'LAN Server يعمل'
                        : 'LAN Server متوقف',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (lanRunning && lanUrl != null)
                    Text(
                      lanUrl!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            if (lanRunning)
              IconButton(
                tooltip: 'نسخ الرابط',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: lanUrl ?? '',
                    ),
                  );

                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ الرابط 📋'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                ),
              ),
            FilledButton(
              style: lanRunning
                  ? FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    )
                  : null,
              onPressed: lanRunning ? stopLan : startLan,
              child: Text(
                lanRunning ? 'إيقاف' : 'تشغيل',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCodeEditor() {
    final controller = controllers[currentFile];

    if (controller == null) {
      return const Expanded(
        child: Center(
          child: Text('اختر ملفًا للبدء'),
        ),
      );
    }

    final dark =
        Theme.of(context).brightness == Brightness.dark;

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
            wrap: false,
            horizontalScroll: true,
            lineNumbers: true,
            textStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              height: 1.55,
              letterSpacing: .15,
              color: dark
                  ? Colors.white
                  : const Color(0xFF20222B),
            ),
            background: dark
                ? const Color(0xFF15171C)
                : const Color(0xFFFAFAFC),
            padding: const EdgeInsets.all(16),
            lineNumberStyle: const LineNumberStyle(
              width: 60,
              margin: 8,
              textAlign: TextAlign.right,
            ),
            cursorColor:
                Theme.of(context).colorScheme.primary,
            keyboardType: TextInputType.multiline,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!settingsLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (previewMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
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
                  color: Colors.black.withOpacity(.65),
                  borderRadius: BorderRadius.circular(14),
                  child: IconButton(
                    onPressed: closePreview,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
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
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        autoSaveTimer?.cancel();
        finishHistoryBatch();

        await saveProject();

        if (!mounted) {
          return;
        }

        Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                widget.project.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                hasChanges ? 'غير محفوظ' : 'محفوظ',
                style: TextStyle(
                  fontSize: 10,
                  color: hasChanges
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                      : Theme.of(context)
                          .colorScheme
                          .primary,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'الملفات',
              onPressed: openFileExplorer,
              icon: const Icon(
                Icons.folder_copy_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Preview',
              onPressed: openPreview,
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            buildEditorHeader(),
            buildLanBar(),
            buildCodeEditor(),
          ],
        ),
        floatingActionButton:
            FloatingActionButton.extended(
          onPressed: openPreview,
          icon: const Icon(
            Icons.play_arrow_rounded,
          ),
          label: const Text('Preview'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    autoSaveTimer?.cancel();
    previewTimer?.cancel();
    historyTimer?.cancel();

    for (final controller in controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
}
