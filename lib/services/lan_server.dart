import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:serious_python/serious_python.dart';

class LanServerService {
  LanServerService._();

  static final LanServerService instance = LanServerService._();

  Directory? _root;
  File? _stopFile;
  File? _portFile;
  int? _port;
  bool _running = false;
  Future<void>? _pythonFuture;

  bool get isRunning => _running;

  int? get port => _port;

  Future<String> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address;

          if (!ip.startsWith('127.') &&
              !ip.startsWith('169.254.')) {
            return ip;
          }
        }
      }
    } catch (_) {}

    return '127.0.0.1';
  }

  String _buildDocument({
    required String html,
    required String css,
    required String js,
    required bool singleFile,
  }) {
    if (singleFile) {
      return html;
    }

    final hasDocument = RegExp(
      r'<html[\s>]',
      caseSensitive: false,
    ).hasMatch(html);

    if (hasDocument) {
      var document = html;

      final headStyle = '<style>\n$css\n</style>';

      if (css.trim().isNotEmpty &&
          !RegExp(
            r'<style[\s>]',
            caseSensitive: false,
          ).hasMatch(document)) {
        if (RegExp(
          r'</head>',
          caseSensitive: false,
        ).hasMatch(document)) {
          document = document.replaceFirst(
            RegExp(r'</head>', caseSensitive: false),
            '$headStyle\n</head>',
          );
        } else {
          document = '$headStyle\n$document';
        }
      }

      if (js.trim().isNotEmpty) {
        final script = '<script>\n$js\n</script>';

        if (RegExp(
          r'</body>',
          caseSensitive: false,
        ).hasMatch(document)) {
          document = document.replaceFirst(
            RegExp(r'</body>', caseSensitive: false),
            '$script\n</body>',
          );
        } else {
          document = '$document\n$script';
        }
      }

      return document;
    }

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
html, body {
  margin: 0;
  padding: 0;
  width: 100%;
  min-height: 100%;
}
* {
  box-sizing: border-box;
}
$css
</style>
</head>
<body>
$html
<script>
$js
</script>
</body>
</html>''';
  }

  Future<void> _writeProject({
    required String html,
    required String css,
    required String js,
    required bool singleFile,
  }) async {
    final root = _root;

    if (root == null) {
      return;
    }

    final document = _buildDocument(
      html: html,
      css: css,
      js: js,
      singleFile: singleFile,
    );

    await File('${root.path}/index.html').writeAsString(
      document,
      flush: true,
    );
  }

  Future<String> start({
    required String projectId,
    required String html,
    required String css,
    required String js,
    required bool singleFile,
  }) async {
    if (_running) {
      final ip = await _findLocalIp();
      return 'http://$ip:${_port ?? 8765}';
    }

    await stop();

    final support = await getApplicationSupportDirectory();

    final safeId = projectId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    final root = Directory(
      '${support.path}/data/lan_servers/$safeId',
    );

    await root.create(recursive: true);

    _root = root;
    _stopFile = File('${root.path}/.stop');
    _portFile = File('${root.path}/.port');

    await _writeProject(
      html: html,
      css: css,
      js: js,
      singleFile: singleFile,
    );

    final stopFile = _stopFile!;
    final portFile = _portFile!;

    await stopFile.delete().catchError((_) => stopFile);
    await portFile.delete().catchError((_) => portFile);

    try {
      final future = SeriousPython.run(
        'assets/python/app.zip',
        appFileName: 'server.py',
        environmentVariables: {
          'WGS_ROOT': root.path,
          'WGS_PORT': '8765',
          'WGS_PORT_FILE': portFile.path,
          'WGS_STOP_FILE': stopFile.path,
        },
      );

      _pythonFuture = future;

      future.catchError((_) {});

      int? detectedPort;

      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(
          const Duration(milliseconds: 100),
        );

        if (await portFile.exists()) {
          final value = await portFile.readAsString();

          detectedPort = int.tryParse(value.trim());

          if (detectedPort != null) {
            break;
          }
        }
      }

      if (detectedPort == null) {
        throw Exception('فشل تشغيل Python LAN Server');
      }

      _port = detectedPort;
      _running = true;

      final ip = await _findLocalIp();

      return 'http://$ip:$detectedPort';
    } catch (e) {
      _running = false;
      _port = null;
      _root = null;
      _stopFile = null;
      _portFile = null;
      rethrow;
    }
  }

  Future<void> update({
    required String html,
    required String css,
    required String js,
    required bool singleFile,
  }) async {
    if (!_running) {
      return;
    }

    await _writeProject(
      html: html,
      css: css,
      js: js,
      singleFile: singleFile,
    );
  }

  Future<void> stop() async {
    final stopFile = _stopFile;

    if (stopFile != null) {
      try {
        if (!await stopFile.exists()) {
          await stopFile.writeAsString(
            'stop',
            flush: true,
          );
        }
      } catch (_) {}
    }

    final pythonFuture = _pythonFuture;

    if (pythonFuture != null) {
      try {
        await Future.any<void>([
          pythonFuture,
          Future<void>.delayed(
            const Duration(milliseconds: 700),
          ),
        ]);
      } catch (_) {}
    }

    _running = false;
    _port = null;
    _root = null;
    _stopFile = null;
    _portFile = null;
    _pythonFuture = null;
  }
}
