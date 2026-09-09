import 'dart:async';
import 'dart:io';

class LanServerService {
  LanServerService._();

  static final LanServerService instance = LanServerService._();

  HttpServer? _server;
  String? _url;
  String _document = '';

  bool get isRunning => _server != null;

  String? get url => _url;

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
<meta name="viewport" content="width=device-width, initial-scale=1.0">
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
      final headPattern = RegExp(
        r'</head>',
        caseSensitive: false,
      );

      if (headPattern.hasMatch(document)) {
        document = document.replaceFirst(
          headPattern,
          '$style\n</head>',
        );
      } else {
        document = '$style\n$document';
      }
    }

    if (script.isNotEmpty) {
      final bodyPattern = RegExp(
        r'</body>',
        caseSensitive: false,
      );

      if (bodyPattern.hasMatch(document)) {
        document = document.replaceFirst(
          bodyPattern,
          '$script\n</body>',
        );
      } else {
        document = '$document\n$script';
      }
    }

    return document;
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

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      0,
      shared: true,
    );

    _server = server;

    unawaited(
      server.listen(
        (request) async {
          try {
            request.response.headers.contentType = ContentType.html;
            request.response.headers.set(
              'Cache-Control',
              'no-store, no-cache, must-revalidate',
            );
            request.response.headers.set(
              'Pragma',
              'no-cache',
            );
            request.response.headers.set(
              'Access-Control-Allow-Origin',
              '*',
            );

            if (request.uri.path == '/' ||
                request.uri.path == '/index.html') {
              request.response.statusCode = HttpStatus.ok;
              request.response.write(_document);
            } else {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write('Not Found');
            }
          } catch (_) {
            try {
              request.response.statusCode =
                  HttpStatus.internalServerError;
            } catch (_) {}
          } finally {
            try {
              await request.response.close();
            } catch (_) {}
          }
        },
      ),
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

    if (server == null) {
      return;
    }

    try {
      await server.close(force: true);
    } catch (_) {}
  }
}
