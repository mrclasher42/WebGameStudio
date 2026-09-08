import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/game_project.dart';
import 'game_html.dart';

class GameRuntime extends StatefulWidget {
  final GameProject project;

  const GameRuntime({
    super.key,
    required this.project,
  });

  @override
  State<GameRuntime> createState() => _GameRuntimeState();
}

class _GameRuntimeState extends State<GameRuntime> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(GameHtml.generate(widget.project));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Preview'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
