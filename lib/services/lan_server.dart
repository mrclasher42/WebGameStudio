import 'dart:convert';
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

class _Player {
  String id;
  String name;
  double x;
  double y;
  String color;
  DateTime lastSeen;

  _Player({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.color,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'x': x,
      'y': y,
      'color': color,
    };
  }
}

class LanServerService {
  LanServerService._();

  static final LanServerService instance = LanServerService._();

  HttpServer? _server;
  String? _url;
  String _document = '';

  final Map<String, _Player> _players = {};

  bool _foregroundStarted = false;

  bool get isRunning => _server != null;

  String? get url => _url;

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

            final name = interface.name.toLowerCase();

            if (name.contains('wlan') ||
                name.contains('wifi') ||
                name.contains('wi-fi')) {
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

  Future<void> _startForegroundService() async {
    if (_foregroundStarted) {
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

    if (Platform.isAndroid) {
      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();

      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
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

    _foregroundStarted = true;
  }

  Future<void> _stopForegroundService() async {
    if (!_foregroundStarted) {
      return;
    }

    if (Platform.isAndroid) {
      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
    }

    _foregroundStarted = false;
  }

  void _cleanupPlayers() {
    final now = DateTime.now();

    _players.removeWhere(
      (_, player) => now.difference(player.lastSeen).inSeconds > 5,
    );
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();

      if (body.trim().isEmpty) {
        return {};
      }

      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {};
    } catch (_) {
      return {};
    }
  }

  void _headers(HttpResponse response) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );

    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );

    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );

    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate, max-age=0',
    );

    response.headers.set(
      'Pragma',
      'no-cache',
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    _headers(response);

    try {
      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.noContent;
        await response.close();
        return;
      }

      _cleanupPlayers();

      final path = request.uri.path;

      if (request.method == 'GET' &&
          (path == '/' || path == '/index.html')) {
        response.statusCode = HttpStatus.ok;
        response.headers.contentType = ContentType(
          'text',
          'html',
          charset: 'utf-8',
        );
        response.write(_document);
        await response.close();
        return;
      }

      if (path == '/players' && request.method == 'GET') {
        response.headers.contentType = ContentType.json;

        final players = _players.values
            .map((player) => player.toJson())
            .toList();

        response.statusCode = HttpStatus.ok;
        response.write(
          jsonEncode({
            'players': players,
            'count': players.length,
          }),
        );

        await response.close();
        return;
      }

      if (path == '/join' && request.method == 'POST') {
        final data = await _readJson(request);

        final id = (data['id'] ?? '').toString();
        final name =
            (data['name'] ?? 'Player').toString().trim();

        final x =
            (data['x'] is num) ? (data['x'] as num).toDouble() : 50.0;

        final y =
            (data['y'] is num) ? (data['y'] as num).toDouble() : 50.0;

        final color =
            (data['color'] ?? '#4ade80').toString();

        if (id.isEmpty) {
          response.statusCode = HttpStatus.badRequest;
          response.write(
            jsonEncode({
              'ok': false,
              'error': 'Missing player id',
            }),
          );
          await response.close();
          return;
        }

        _players[id] = _Player(
          id: id,
          name: name.isEmpty ? 'Player' : name.substring(
            0,
            name.length > 16 ? 16 : name.length,
          ),
          x: x.clamp(0.0, 100.0),
          y: y.clamp(0.0, 100.0),
          color: color,
          lastSeen: DateTime.now(),
        );

        response.headers.contentType = ContentType.json;
        response.statusCode = HttpStatus.ok;
        response.write(
          jsonEncode({
            'ok': true,
            'players': _players.values
                .map((player) => player.toJson())
                .toList(),
          }),
        );

        await response.close();
        return;
      }

      if (path == '/update' && request.method == 'POST') {
        final data = await _readJson(request);

        final id = (data['id'] ?? '').toString();

        if (id.isEmpty) {
          response.statusCode = HttpStatus.badRequest;
          response.write(
            jsonEncode({
              'ok': false,
              'error': 'Missing player id',
            }),
          );
          await response.close();
          return;
        }

        final player = _players[id];

        if (player == null) {
          response.statusCode = HttpStatus.notFound;
          response.write(
            jsonEncode({
              'ok': false,
              'error': 'Player not found',
            }),
          );
          await response.close();
          return;
        }

        if (data['x'] is num) {
          player.x =
              (data['x'] as num).toDouble().clamp(0.0, 100.0);
        }

        if (data['y'] is num) {
          player.y =
              (data['y'] as num).toDouble().clamp(0.0, 100.0);
        }

        if (data['name'] != null) {
          final name = data['name'].toString().trim();

          if (name.isNotEmpty) {
            player.name = name.substring(
              0,
              name.length > 16 ? 16 : name.length,
            );
          }
        }

        if (data['color'] != null) {
          player.color = data['color'].toString();
        }

        player.lastSeen = DateTime.now();

        response.headers.contentType = ContentType.json;
        response.statusCode = HttpStatus.ok;
        response.write(
          jsonEncode({
            'ok': true,
          }),
        );

        await response.close();
        return;
      }

      if (path == '/leave' && request.method == 'POST') {
        final data = await _readJson(request);

        final id = (data['id'] ?? '').toString();

        if (id.isNotEmpty) {
          _players.remove(id);
        }

        response.headers.contentType = ContentType.json;
        response.statusCode = HttpStatus.ok;
        response.write(
          jsonEncode({
            'ok': true,
          }),
        );

        await response.close();
        return;
      }

      if (path == '/health' && request.method == 'GET') {
        response.headers.contentType = ContentType.json;
        response.statusCode = HttpStatus.ok;
        response.write(
          jsonEncode({
            'ok': true,
            'players': _players.length,
          }),
        );
        await response.close();
        return;
      }

      response.statusCode = HttpStatus.notFound;
      response.write('Not Found');
      await response.close();
    } catch (_) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {}
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
      _handleRequest,
      onError: (_) {},
      cancelOnError: false,
    );

    final ip = await _findLocalIp();

    _url = 'http://$ip:${server.port}';

    await _startForegroundService();

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
    _players.clear();

    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {}
    }

    await _stopForegroundService();
  }
}
