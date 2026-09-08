import 'dart:convert';

import '../models/game_project.dart';

class GameHtml {
  static String generate(GameProject project) {
    final objects = project.objects.map((object) {
      return {
        'id': object.id,
        'type': object.type,
        'x': object.x,
        'y': object.y,
        'width': object.width,
        'height': object.height,
        'rotation': object.rotation,
        'data': object.data,
      };
    }).toList();

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no">
<meta charset="UTF-8">
<style>
*{box-sizing:border-box}
html,body{margin:0;width:100%;height:100%;overflow:hidden}
body{background:#111;font-family:Arial,sans-serif}
#world{position:relative;width:100%;height:100%;overflow:hidden;background:#181818}
.object{position:absolute;display:flex;align-items:center;justify-content:center;overflow:hidden}
.text{background:transparent!important;color:white!important}
.button{border:0;color:white;font-size:18px;border-radius:12px}
.input{background:white!important;color:#222!important;border:0;border-radius:10px;padding:10px;font-size:16px}
.question{color:white;padding:16px;border-radius:16px}
.question .answers{display:flex;flex-direction:column;gap:8px;margin-top:12px;width:100%}
.question button{border:0;border-radius:10px;padding:12px;font-size:16px}
</style>
</head>
<body>
<div id="world"></div>

<script>
const objects = ${jsonEncode(objects)};
const world = document.getElementById("world");

function addObject(o) {
  const el = document.createElement("div");
  el.className = "object";

  el.style.left = o.x + "px";
  el.style.top = o.y + "px";
  el.style.width = o.width + "px";
  el.style.height = o.height + "px";
  el.style.transform = "rotate(" + o.rotation + "deg)";

  const data = o.data || {};
  const type = o.type || "";

  if (data.color) {
    el.style.background = "rgb(" +
      ((data.color >> 16) & 255) + "," +
      ((data.color >> 8) & 255) + "," +
      (data.color & 255) + ")";
  }

  if (type === "text") {
    el.className += " text";
    el.textContent = data.text || "";
  } else if (type === "button") {
    el.className += " button";
    el.style.background = "#2878ff";
    const button = document.createElement("button");
    button.textContent = data.text || "Button";
    button.style.width = "100%";
    button.style.height = "100%";
    button.style.border = "0";
    button.style.background = "transparent";
    button.style.color = "white";
    button.style.fontSize = "18px";
    el.appendChild(button);
  } else if (type === "input") {
    el.className += " input";
    const input = document.createElement("input");
    input.placeholder = data.placeholder || "";
    input.style.width = "100%";
    input.style.height = "100%";
    input.style.border = "0";
    input.style.outline = "0";
    input.style.fontSize = "16px";
    el.appendChild(input);
  } else if (type === "question") {
    el.className += " question";
    el.style.background = "#252d52";

    const content = document.createElement("div");
    content.style.width = "100%";

    const title = document.createElement("div");
    title.textContent = data.question || "";
    title.style.fontSize = "20px";
    title.style.fontWeight = "bold";

    const answerBox = document.createElement("div");
    answerBox.className = "answers";

    const answers = Array.isArray(data.answers) ? data.answers : [];

    answers.forEach((answer, index) => {
      if (!answer) return;

      const button = document.createElement("button");
      button.textContent = answer;
      button.onclick = () => {
        const correct = Number(data.correct || 0);

        if (index === correct) {
          button.style.background = "#21b66f";
          button.style.color = "white";
        } else {
          button.style.background = "#e5484d";
          button.style.color = "white";
        }
      };

      answerBox.appendChild(button);
    });

    content.appendChild(title);
    content.appendChild(answerBox);
    el.appendChild(content);
  } else if (type === "image") {
    el.style.background = "#303030";
    el.textContent = data.source || "Image";
    el.style.color = "white";
  } else if (type === "panel") {
    el.style.background = "#252525";
    el.style.borderRadius = "12px";
  } else if (type === "shape") {
    el.style.background = "#777";
    el.style.borderRadius = "12px";
  } else if (type === "player") {
    el.style.background = "#42a5f5";
  } else if (type === "platform") {
    el.style.background = "#795548";
  } else if (type === "coin") {
    el.style.background = "#ffd740";
    el.style.borderRadius = "50%";
  } else if (type === "enemy") {
    el.style.background = "#ef5350";
  } else if (type === "box") {
    el.style.background = "#8d6e63";
  } else if (type === "cell") {
    el.style.background = "#303030";
    el.style.border = "2px solid #777";
  } else if (type === "grid") {
    el.style.background = "transparent";
    el.style.border = "2px solid #777";
  } else if (type === "card") {
    el.style.background = "#fff";
    el.style.color = "#222";
    el.style.borderRadius = "14px";
  } else if (type === "progress") {
    el.style.background = "#303030";
    el.style.borderRadius = "20px";

    const bar = document.createElement("div");
    bar.style.width = "50%";
    bar.style.height = "100%";
    bar.style.background = "#20b486";
    bar.style.borderRadius = "20px";

    el.appendChild(bar);
  } else if (type === "timer") {
    el.style.background = "#303030";
    el.style.color = "white";
    el.textContent = "00:00";
  } else {
    el.style.background = "#555";
  }

  world.appendChild(el);
}

objects.forEach(addObject);
</script>
</body>
</html>
''';
  }
}
