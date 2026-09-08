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

    await File('${root.path}/index.html').writeAsString(
      html,
      flush: true,
    );

    if (!singleFile) {
      await File('${root.path}/style.css').writeAsString(
        css,
        flush: true,
      );

      await File('${root.path}/script.js').writeAsString(
        js,
        flush: true,
      );
    }
  }

  Future<String> start({
    required String projectId,
    required String html,
    required String css,
    required String js,
    required bool singleFile,
  }) async {
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

    if (await _stopFile!.exists()) {
      await _stopFile!.delete();
    }

    if (await _portFile!.exists()) {
      await _portFile!.delete();
    }

    unawaited(
      SeriousPython.run(
        'assets/python/app.zip',
        appFileName: 'server.py',
        environmentVariables: {
          'WGS_ROOT': root.path,
          'WGS_PORT': '8765',
          'WGS_PORT_FILE': _portFile!.path,
          'WGS_STOP_FILE': _stopFile!.path,
        },
      ),
    );

    int? detectedPort;

    for (var i = 0; i < 80; i++) {
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      );

      if (await _portFile!.exists()) {
        final value = await _portFile!.readAsString();

        detectedPort = int.tryParse(value.trim());

        if (detectedPort != null) {
          break;
        }
      }
    }

    if (detectedPort == null) {
      await stop();
      throw Exception(
        'تعذر تشغيل Python LAN Server',
      );
    }

    _port = detectedPort;
    _running = true;

    final ip = await _findLocalIp();

    return 'http://$ip:$detectedPort';
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
        await stopFile.writeAsString(
          'stop',
          flush: true,
        );
      } catch (_) {}
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    _running = false;
    _port = null;
    _root = null;
    _stopFile = null;
    _portFile = null;
  }
}
