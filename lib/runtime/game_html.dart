import 'dart:convert';
import '../models/game_project.dart';

class GameHtml {
  static String generate(GameProject project) {
    final scene = project.scenes.isEmpty
        ? GameScene(name: 'Main')
        : project.scenes.first;

    final objects = scene.objects.map((object) {
      final html = object.html.trim().isEmpty
          ? '<div></div>'
          : object.html;

      return '''
<div
  class="wgs-object"
  id="${_escape(object.id)}"
  data-name="${_escape(object.name)}"
  style="left:${object.x}px;top:${object.y}px;width:${object.width}px;height:${object.height}px;transform:rotate(${object.rotation}deg);"
>
$html
</div>
<style>
#wgs-root #${_escape(object.id)} {
${object.css}
}
</style>
<script>
window.WGS_OBJECTS["${_escape(object.id)}"] = ${jsonEncode(object.logic)};
</script>
''';
    }).join('\n');

    final encodedGlobalLogic = jsonEncode(project.globalLogic);

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>
html,body {
  margin:0;
  padding:0;
  width:100%;
  height:100%;
  overflow:hidden;
  background:#10131a;
  font-family:Arial,sans-serif;
}
#wgs-root {
  position:relative;
  width:${project.width}px;
  height:${project.height}px;
  overflow:hidden;
  background:#151923;
  transform-origin:top left;
}
.wgs-object {
  position:absolute;
  box-sizing:border-box;
  user-select:none;
  touch-action:none;
}
.wgs-button {
  cursor:pointer;
}
${project.globalCss}
</style>
</head>
<body>
<div id="wgs-root">
$objects
</div>
<script>
window.WGS_OBJECTS = {};
window.WGS = {
  move: function(id,x,y) {
    const e=document.getElementById(id);
    if(e){e.style.left=x+'px';e.style.top=y+'px';}
  },
  moveX: function(id,value) {
    const e=document.getElementById(id);
    if(e){e.style.left=(e.offsetLeft+Number(value))+'px';}
  },
  moveY: function(id,value) {
    const e=document.getElementById(id);
    if(e){e.style.top=(e.offsetTop+Number(value))+'px';}
  },
  setText: function(id,value) {
    const e=document.getElementById(id);
    if(e){e.innerText=value;}
  },
  show: function(id) {
    const e=document.getElementById(id);
    if(e){e.style.display='block';}
  },
  hide: function(id) {
    const e=document.getElementById(id);
    if(e){e.style.display='none';}
  },
  remove: function(id) {
    const e=document.getElementById(id);
    if(e){e.remove();}
  },
  scene: function(name) {
    window.location.hash=name;
  },
  playSound: function(id) {
    const e=document.getElementById(id);
    if(e && e.dataset.sound){
      const a=new Audio(e.dataset.sound);
      a.play();
    }
  }
};

function runUserCode(code, objectId) {
  if(!code) return;
  try {
    const api = {
      moveX: value => WGS.moveX(objectId,value),
      moveY: value => WGS.moveY(objectId,value),
      move: (x,y) => {
        const e=document.getElementById(objectId);
        if(e) WGS.move(objectId,e.offsetLeft+Number(x),e.offsetTop+Number(y));
      },
      setText: value => WGS.setText(objectId,value),
      show: () => WGS.show(objectId),
      hide: () => WGS.hide(objectId),
      destroy: () => WGS.remove(objectId),
      playSound: () => WGS.playSound(objectId)
    };

    const onKey = (key, callback) => {
      window.addEventListener('keydown', event => {
        if(event.key === key) callback(api);
      });
    };

    const onTap = callback => {
      const element=document.getElementById(objectId);
      if(element) element.addEventListener('click', () => callback(api));
    };

    const onTouch = callback => {
      const element=document.getElementById(objectId);
      if(element) element.addEventListener('touchstart', () => callback(api));
    };

    const onUpdate = callback => {
      setInterval(() => callback(api),16);
    };

    const onStart = callback => {
      setTimeout(() => callback(api),0);
    };

    new Function('onKey','onTap','onTouch','onUpdate','onStart','player','WGS',code)(
      onKey,
      onTap,
      onTouch,
      onUpdate,
      onStart,
      api,
      WGS
    );
  } catch(error) {
    console.error(error);
  }
}

setTimeout(() => {
  const scripts = document.querySelectorAll('[data-name]');
  document.querySelectorAll('.wgs-object').forEach(element => {
    const code = window.WGS_OBJECTS[element.id] || '';
    runUserCode(code, element.id);
  });

  runUserCode($encodedGlobalLogic, '');
}, 50);
</script>
</body>
</html>
''';
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
