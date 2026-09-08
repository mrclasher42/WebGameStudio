import 'dart:convert';

import '../models/game_project.dart';

class GameHtml {
  static String generate(GameProject project) {
    final objects = project.objects
        .map(
          (object) => {
            'id': object.id,
            'type': object.type,
            'x': object.x,
            'y': object.y,
            'width': object.width,
            'height': object.height,
            'rotation': object.rotation,
            'data': object.data,
            'events': object.events.map((e) => e.toMap()).toList(),
          },
        )
        .toList();

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no">
<meta charset="UTF-8">
<style>
*{box-sizing:border-box}
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#0b0f14}
body{font-family:Arial,sans-serif}
#world{position:relative;width:100%;height:100%;overflow:hidden;background:#101722}
.object{position:absolute;display:flex;align-items:center;justify-content:center;overflow:hidden;user-select:none}
.text{background:transparent!important;color:white}
.button{border:0;color:white;border-radius:12px;font-size:18px}
.input{background:white;color:#111;border:0;border-radius:10px;padding:10px;font-size:16px}
.question{background:#172554;color:white;padding:14px;border-radius:14px}
.question .answers{display:flex;flex-direction:column;gap:8px;width:100%;margin-top:10px}
.question button{border:0;border-radius:9px;padding:10px;font-size:15px}
</style>
</head>
<body>
<div id="world"></div>
<script>
const objects=${jsonEncode(objects)};
const variables=${jsonEncode(project.variables.map((e)=>e.toMap()).toList())};
const world=document.getElementById("world");
const elements={};
const state={};

variables.forEach(v=>state[v.name]=v.value);

function color(value,fallback){
  if(typeof value==="number"){
    return "#" + (value & 0xffffff).toString(16).padStart(6,"0");
  }
  return fallback;
}

function makeVisual(o,el){
  const d=o.data||{};
  const t=o.type||"";

  el.style.background=color(d.color,"#4f46e5");

  if(t==="text"){
    el.className+=" text";
    el.textContent=d.text||"";
  }

  else if(t==="button"){
    el.className+=" button";
    el.style.background=color(d.color,"#4f46e5");
    const b=document.createElement("button");
    b.textContent=d.text||"Button";
    b.style.cssText="width:100%;height:100%;border:0;background:transparent;color:white;font-size:18px";
    b.onclick=()=>trigger(o,"onTap");
    el.appendChild(b);
  }

  else if(t==="input"){
    el.className+=" input";
    const input=document.createElement("input");
    input.placeholder=d.placeholder||"";
    input.style.cssText="width:100%;height:100%;border:0;outline:0;font-size:16px";
    el.appendChild(input);
  }

  else if(t==="player"){
    el.style.borderRadius="35% 35% 20% 20%";
  }

  else if(t==="platform"){
    el.style.background="#334155";
    el.style.borderRadius="6px";
  }

  else if(t==="coin"){
    el.style.background="#fbbf24";
    el.style.borderRadius="50%";
    el.style.border="5px solid #a16207";
  }

  else if(t==="enemy"){
    el.style.background=color(d.color,"#ef4444");
    el.style.clipPath="polygon(10% 75%,20% 22%,38% 38%,50% 18%,62% 38%,80% 22%,90% 75%)";
  }

  else if(t==="box"){
    el.style.background="#a16207";
    el.style.border="5px solid #facc15";
  }

  else if(t==="grid"){
    el.style.background="transparent";
    el.style.backgroundImage="linear-gradient(#64748b 2px,transparent 2px),linear-gradient(90deg,#64748b 2px,transparent 2px)";
    el.style.backgroundSize="33.33% 33.33%";
  }

  else if(t==="cell"){
    el.style.background="transparent";
    el.style.border="2px solid #64748b";
  }

  else if(t==="card"){
    el.style.background="#fff";
    el.style.borderRadius="14px";
  }

  else if(t==="panel"){
    el.style.background="#1e293b";
    el.style.borderRadius="14px";
  }

  else if(t==="progress"){
    el.style.background="#263241";
    el.style.borderRadius="20px";
    const bar=document.createElement("div");
    bar.style.width=((Number(d.value)||0))+"%";
    bar.style.height="100%";
    bar.style.background=color(d.color,"#4f46e5");
    bar.style.borderRadius="20px";
    el.appendChild(bar);
  }

  else if(t==="timer"){
    el.style.background="#1e293b";
    el.style.color="white";
    el.style.borderRadius="12px";
    el.textContent=String(d.seconds||60);
  }

  else if(t==="image"){
    if(d.source){
      const img=document.createElement("img");
      img.src=d.source;
      img.style.cssText="width:100%;height:100%;object-fit:cover";
      el.appendChild(img);
    }
  }

  else if(t==="question"){
    const title=document.createElement("div");
    title.style.cssText="width:100%;font-size:18px;font-weight:600";
    title.textContent=d.question||"";
    const box=document.createElement("div");
    box.className="answers";
    const answers=Array.isArray(d.answers)?d.answers:[];
    answers.forEach((answer,index)=>{
      if(!answer)return;
      const b=document.createElement("button");
      b.textContent=answer;
      b.onclick=()=>{
        if(Number(d.correct||0)===index){
          b.style.background="#16a34a";
          trigger(o,"onCorrect");
        }else{
          b.style.background="#dc2626";
          trigger(o,"onWrong");
        }
      };
      box.appendChild(b);
    });
    el.appendChild(title);
    el.appendChild(box);
  }
}

function render(o){
  const el=document.createElement("div");
  el.className="object";
  el.style.left=o.x+"px";
  el.style.top=o.y+"px";
  el.style.width=o.width+"px";
  el.style.height=o.height+"px";
  el.style.transform="rotate("+o.rotation+"deg)";
  makeVisual(o,el);
  elements[o.id]=el;
  world.appendChild(el);
}

function action(a){
  const target=objects.find(o=>o.id===a.targetId);
  if(!target)return;

  const el=elements[target.id];
  const d=a.data||{};

  if(a.type==="move"){
    target.x+=Number(d.dx)||0;
    target.y+=Number(d.dy)||0;
    el.style.left=target.x+"px";
    el.style.top=target.y+"px";
  }

  else if(a.type==="setText"){
    target.data=target.data||{};
    target.data.text=d.text||"";
    el.textContent=d.text||"";
  }

  else if(a.type==="changeVariable"){
    const name=d.variable;
    if(name in state)state[name]=(Number(state[name])||0)+(Number(d.amount)||0);
  }

  else if(a.type==="show"){
    el.style.display="flex";
  }

  else if(a.type==="hide"){
    el.style.display="none";
  }

  else if(a.type==="destroy"){
    el.remove();
  }
}

function trigger(object,eventName){
  const events=Array.isArray(object.events)?object.events:[];
  events.forEach(e=>{
    if(e.trigger!==eventName)return;
    const actions=Array.isArray(e.actions)?e.actions:[];
    actions.forEach(action);
  });
}

objects.forEach(render);

objects.forEach(o=>{
  if(Array.isArray(o.events)){
    o.events.forEach(e=>{
      if(e.trigger==="onStart")trigger(o,"onStart");
    });
  }
});

document.addEventListener("keydown",e=>{
  objects.forEach(o=>{
    if(Array.isArray(o.events)){
      o.events.forEach(event=>{
        if(event.trigger==="onKey"){
          const key=event.actions?.[0]?.data?.key;
          if(!key||key.toLowerCase()===e.key.toLowerCase())trigger(o,"onKey");
        }
      });
    }
  });
});
</script>
</body>
</html>
''';
  }
}
