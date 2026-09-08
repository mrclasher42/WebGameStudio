import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const WebGameStudio());
}

class WebGameStudio extends StatelessWidget {
  const WebGameStudio({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090C12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StudioHome(),
    );
  }
}

class StudioHome extends StatefulWidget {
  const StudioHome({super.key});

  @override
  State<StudioHome> createState() => _StudioHomeState();
}

class _StudioHomeState extends State<StudioHome> {
  int tab = 0;
  final codeController = TextEditingController();
  late final WebViewController webController;

  final defaultGame = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<style>
*{box-sizing:border-box}
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#101522}
canvas{display:block;width:100%;height:100%}
</style>
</head>
<body>
<canvas id="game"></canvas>
<script>
const canvas=document.getElementById("game");
const ctx=canvas.getContext("2d");
let w=0;
let h=0;
let player={x:100,y:100,size:50,vy:0};
let left=false;
let right=false;

function resize(){
  w=canvas.width=innerWidth*devicePixelRatio;
  h=canvas.height=innerHeight*devicePixelRatio;
  ctx.setTransform(devicePixelRatio,0,0,devicePixelRatio,0,0);
}

addEventListener("resize",resize);
resize();

addEventListener("touchstart",e=>{
  const x=e.touches[0].clientX;
  if(x<innerWidth/2)left=true;
  else right=true;
});

addEventListener("touchend",()=>{
  left=false;
  right=false;
});

function loop(){
  const sw=innerWidth;
  const sh=innerHeight;

  if(left)player.x-=5;
  if(right)player.x+=5;

  player.vy+=0.5;
  player.y+=player.vy;

  if(player.y+player.size>sh-80){
    player.y=sh-80-player.size;
    player.vy=0;
  }

  ctx.clearRect(0,0,sw,sh);

  ctx.fillStyle="#151D2D";
  ctx.fillRect(0,0,sw,sh);

  ctx.fillStyle="#6C63FF";
  ctx.fillRect(0,sh-80,sw,80);

  ctx.fillStyle="#5EE7A0";
  ctx.fillRect(player.x,player.y,player.size,player.size);

  requestAnimationFrame(loop);
}

loop();
</script>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    codeController.text = defaultGame;

    webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF101522))
      ..loadHtmlString(defaultGame);

    _loadProject();
  }

  Future<void> _loadProject() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('game_code');

    if (saved != null && saved.isNotEmpty) {
      codeController.text = saved;
      await webController.loadHtmlString(saved);
    }
  }

  Future<void> _saveProject() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('game_code', codeController.text);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ اللعبة ✓'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _runGame() async {
    await webController.loadHtmlString(codeController.text);

    if (!mounted) return;

    setState(() {
      tab = 1;
    });
  }

  void _insertTemplate(String template) {
    codeController.text += template;
    codeController.selection = TextSelection.collapsed(
      offset: codeController.text.length,
    );
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: tab == 0 ? _editor() : _preview(),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF111621),
        border: Border(
          bottom: BorderSide(color: Color(0xFF222938)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.games_rounded,
            color: Color(0xFF7C72FF),
            size: 30,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Web Game Studio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _saveProject,
            icon: const Icon(Icons.save_rounded),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _runGame,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('تشغيل'),
          ),
        ],
      ),
    );
  }

  Widget _editor() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _toolButton(
                Icons.person_rounded,
                'Player',
                '''
<div id="player"></div>
''',
              ),
              _toolButton(
                Icons.crop_square_rounded,
                'Platform',
                '''
<div class="platform"></div>
''',
              ),
              _toolButton(
                Icons.circle_rounded,
                'Coin',
                '''
<div class="coin"></div>
''',
              ),
              _toolButton(
                Icons.warning_rounded,
                'Enemy',
                '''
<div class="enemy"></div>
''',
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131D),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF252D3D),
              ),
            ),
            child: TextField(
              controller: codeController,
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: Color(0xFFE7EAF0),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                hintText: 'اكتب HTML / CSS / JavaScript...',
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    codeController.clear();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('مسح'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _runGame,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('معاينة'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolButton(
    IconData icon,
    String label,
    String template,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: () => _insertTemplate(template),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF171E2B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: const Color(0xFF8A82FF),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    return Stack(
      children: [
        WebViewWidget(controller: webController),
        Positioned(
          top: 12,
          left: 12,
          child: FloatingActionButton.small(
            onPressed: () {
              setState(() {
                tab = 0;
              });
            },
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: Color(0xFF111621),
        border: Border(
          top: BorderSide(color: Color(0xFF222938)),
        ),
      ),
      child: Row(
        children: [
          _bottomItem(
            Icons.code_rounded,
            'المحرر',
            0,
          ),
          _bottomItem(
            Icons.play_circle_outline_rounded,
            'المعاينة',
            1,
          ),
        ],
      ),
    );
  }

  Widget _bottomItem(
    IconData icon,
    String title,
    int index,
  ) {
    final active = tab == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            tab = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active
                  ? const Color(0xFF8A82FF)
                  : const Color(0xFF737B8C),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: active
                    ? const Color(0xFF8A82FF)
                    : const Color(0xFF737B8C),
                fontWeight: active
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
