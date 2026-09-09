import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class _LanForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}

@pragma('vm:entry-point')
void _lanForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(
    _LanForegroundTaskHandler(),
  );
}

class LanServerService {
  LanServerService._();

  static final LanServerService instance = LanServerService._();

  HttpServer? _server;
  String? _url;
  String _document = '';
  bool _foregroundInitialized = false;

  bool get isRunning => _server != null;

  String? get url => _url;

  Future<void> _initForegroundService() async {
    if (_foregroundInitialized) {
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'web_game_studio_lan',
        channelName: 'Web Game Studio LAN Server',
        channelDescription:
            'Keeps the Web Game Studio LAN Server running in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: false,
        allowWifiLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );

    _foregroundInitialized = true;
  }

  Future<void> _startForegroundService() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _initForegroundService();

    final permission =
        await FlutterForegroundTask.checkNotificationPermission();

    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      serviceTypes: const [
        ForegroundServiceTypes.connectedDevice,
      ],
      notificationTitle: 'Web Game Studio',
      notificationText: 'LAN Server يعمل في الخلفية',
      notificationIcon: null,
      notificationInitialRoute: '/',
      callback: _lanForegroundTaskCallback,
    );
  }

  Future<void> _stopForegroundService() async {
    if (!Platform.isAndroid) {
      return;
    }

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
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

    final hasHtml = RegExp(
      r'<html[\s>]',
      caseSensitive: false,
    ).hasMatch(html);

    final style = css.trim().isEmpty
        ? ''
        : '<style>\n$css\n</style>';

    final script = js.trim().isEmpty
        ? ''
        : '<script>\n$js\n</script>';

    if (!hasHtml) {
      return '''<!doctype html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
$style
</head>
<body>
$html
$script
</body>
</html>''';
    }

    var document = html;

    if (style.isNotEmpty) {
      final pattern = RegExp(
        r'</head>',
        caseSensitive: false,
      );

      if (pattern.hasMatch(document)) {
        document = document.replaceFirst(
          pattern,
          '$style\n</head>',
        );
      } else {
        document = '$style\n$document';
      }
    }

    if (script.isNotEmpty) {
      final pattern = RegExp(
        r'</body>',
        caseSensitive: false,
      );

      if (pattern.hasMatch(document)) {
        document = document.replaceFirst(
          pattern,
          '$script\n</body>',
        );
      } else {
        document = '$document\n$script';
      }
    }

    return document;
  }

  bool _isPrivateIpv4(String ip) {
    final parts = ip.split('.');

    if (parts.length != 4) {
      return false;
    }

    final numbers = parts.map(int.tryParse).toList();

    if (numbers.any((value) => value == null)) {
      return false;
    }

    final a = numbers[0]!;
    final b = numbers[1]!;

    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  Future<String> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      String? privateIp;
      String? wlanIp;
      String? fallbackIp;

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address;

          if (ip.startsWith('127.') ||
              ip.startsWith('169.254.')) {
            continue;
          }

          fallbackIp ??= ip;

          if (_isPrivateIpv4(ip)) {
            privateIp ??= ip;

            if (interface.name.toLowerCase().contains('wlan')) {
              wlanIp ??= ip;
            }
          }
        }
      }

      return wlanIp ?? privateIp ?? fallbackIp ?? '127.0.0.1';
    } catch (_) {
      return '127.0.0.1';
    }
  }

  Future<String> start({
    required String projectId,
    required String html,
    required String css,
    required String js,
    required bool singleFile,
  }) async {
    if (_server != null) {
      await update(
        html: html,
        css: css,
        js: js,
        singleFile: singleFile,
      );

      return _url!;
    }

    await _startForegroundService();

    _document = _buildDocument(
      html: html,
      css: css,
      js: js,
      singleFile: singleFile,
    );

    HttpServer server;

    try {
      server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        8080,
        shared: false,
      );
    } catch (_) {
      server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        0,
        shared: false,
      );
    }

    _server = server;

    server.listen(
      (request) async {
        final response = request.response;

        try {
          response.headers.contentType = ContentType(
            'text',
            'html',
            charset: 'utf-8',
          );

          response.headers.set(
            'Cache-Control',
            'no-store, no-cache, must-revalidate, max-age=0',
          );

          response.headers.set(
            'Pragma',
            'no-cache',
          );

          response.headers.set(
            'Access-Control-Allow-Origin',
            '*',
          );

          response.persistentConnection = false;

          if (request.uri.path == '/' ||
              request.uri.path == '/index.html') {
            response.statusCode = HttpStatus.ok;
            response.write(_document);
          } else if (request.uri.path == '/favicon.ico') {
            response.statusCode = HttpStatus.noContent;
          } else {
            response.statusCode = HttpStatus.notFound;
            response.write('Not Found');
          }
        } catch (_) {
          try {
            response.statusCode =
                HttpStatus.internalServerError;
          } catch (_) {}
        }

        try {
          await response.close();
        } catch (_) {}
      },
      onError: (_) {},
      cancelOnError: false,
    );

    final ip = await _findLocalIp();

    _url = 'http://$ip:${server.port}';

    return _url!;
  }

  Future<void> update({
    required String html,
    required String css,
    required String js,
    required bool singleFile,
  }) async {
    if (_server == null) {
      return;
    }

    _document = _buildDocument(
      html: html,
      css: css,
      js: js,
      singleFile: singleFile,
    );
  }

  Future<void> stop() async {
    final server = _server;

    _server = null;
    _url = null;
    _document = '';

    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {}
    }

    await _stopForegroundService();
  }
}
