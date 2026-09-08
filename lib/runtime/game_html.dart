import '../models/game_project.dart';

class GameHtml {
  static String generate(GameProject project) {
    final objects = project.objects.map((o) {
      return '''
      {
        id: "${o.id}",
        type: "${o.type}",
        x: ${o.x},
        y: ${o.y},
        width: ${o.width},
        height: ${o.height},
        rotation: ${o.rotation}
      }
      ''';
    }).join(',');

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no">
<style>
html,body{
margin:0;
padding:0;
overflow:hidden;
background:#10131a;
font-family:Arial;
touch-action:none;
}
#game{
position:relative;
width:100vw;
height:100vh;
overflow:hidden;
background:linear-gradient(#182238,#0e1420);
}
#world{
position:absolute;
left:0;
top:0;
width:${project.worldWidth}px;
height:${project.worldHeight}px;
}
.obj{
position:absolute;
box-sizing:border-box;
}
.player{
background:#4fc3f7;
border-radius:14px;
box-shadow:0 0 15px #4fc3f7;
}
.platform{
background:#6d4c41;
border-radius:8px;
box-shadow:inset 0 5px rgba(255,255,255,.12);
}
.coin{
background:#ffd54f;
border-radius:50%;
box-shadow:0 0 18px #ffd54f;
}
.enemy{
background:#ef5350;
border-radius:12px;
box-shadow:0 0 12px #ef5350;
}
.box{
background:#8d6e63;
border-radius:5px;
}
#hud{
position:fixed;
top:18px;
left:18px;
z-index:20;
color:white;
font-size:18px;
font-weight:bold;
text-shadow:0 2px 4px #000;
}
#controls{
position:fixed;
bottom:25px;
left:0;
right:0;
display:flex;
justify-content:space-between;
padding:0 25px;
z-index:30;
pointer-events:none;
}
.controlGroup{
display:flex;
gap:15px;
pointer-events:auto;
}
button{
width:72px;
height:72px;
border-radius:50%;
border:1px solid rgba(255,255,255,.25);
background:rgba(255,255,255,.15);
color:white;
font-size:30px;
backdrop-filter:blur(8px);
}
</style>
</head>
<body>
<div id="game">
<div id="world"></div>
</div>

<div id="hud">🪙 <span id="score">0</span></div>

<div id="controls">
<div class="controlGroup">
<button id="left">◀</button>
<button id="right">▶</button>
</div>
<div class="controlGroup">
<button id="jump">⬆</button>
</div>
</div>

<script>
const objects = [${objects}];

const world = document.getElementById("world");
const scoreElement = document.getElementById("score");

let score = 0;
let cameraX = 0;
let cameraY = 0;
let leftPressed = false;
let rightPressed = false;
let jumpPressed = false;
let gameOver = false;

const gravity = 0.7;
const moveSpeed = 5.5;
const jumpPower = 14;

let player = null;
let velocityX = 0;
let velocityY = 0;
let grounded = false;

const elements = [];

function sound(type){
  try{
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    const ctx = new AudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.connect(gain);
    gain.connect(ctx.destination);

    if(type === "jump"){
      osc.frequency.value = 520;
      gain.gain.value = 0.08;
    }

    if(type === "coin"){
      osc.frequency.value = 900;
      gain.gain.value = 0.1;
    }

    if(type === "hit"){
      osc.frequency.value = 120;
      gain.gain.value = 0.12;
    }

    if(type === "win"){
      osc.frequency.value = 1200;
      gain.gain.value = 0.1;
    }

    osc.start();
    osc.stop(ctx.currentTime + 0.12);
  }catch(e){}
}

function createObject(o){
  const el = document.createElement("div");
  el.className = "obj " + o.type.toLowerCase();
  el.style.left = o.x + "px";
  el.style.top = o.y + "px";
  el.style.width = o.width + "px";
  el.style.height = o.height + "px";
  el.style.transform = "rotate(" + o.rotation + "deg)";
  world.appendChild(el);

  const item = {
    data:o,
    element:el,
    active:true
  };

  elements.push(item);

  if(o.type === "Player"){
    player = item;
  }

  return item;
}

objects.forEach(createObject);

if(!player){
  player = createObject({
    id:"player",
    type:"Player",
    x:100,
    y:300,
    width:55,
    height:70,
    rotation:0
  });
}

function rect(item){
  return {
    x:item.data.x,
    y:item.data.y,
    w:item.data.width,
    h:item.data.height
  };
}

function intersects(a,b){
  return a.x < b.x + b.w &&
         a.x + a.w > b.x &&
         a.y < b.y + b.h &&
         a.y + a.h > b.y;
}

function updatePlayer(){
  if(gameOver) return;

  if(leftPressed){
    velocityX = -moveSpeed;
  }else if(rightPressed){
    velocityX = moveSpeed;
  }else{
    velocityX *= 0.82;
  }

  if(jumpPressed && grounded){
    velocityY = -jumpPower;
    grounded = false;
    sound("jump");
  }

  jumpPressed = false;

  velocityY += gravity;

  player.data.x += velocityX;

  const platforms = elements.filter(e =>
    e.active && e.data.type === "Platform"
  );

  for(const platform of platforms){
    const p = rect(player);
    const b = rect(platform);

    if(intersects(p,b)){
      if(velocityX > 0){
        player.data.x = b.x - p.w;
      }else if(velocityX < 0){
        player.data.x = b.x + b.w;
      }
      velocityX = 0;
    }
  }

  player.data.y += velocityY;
  grounded = false;

  for(const platform of platforms){
    const p = rect(player);
    const b = rect(platform);

    if(intersects(p,b)){
      if(velocityY > 0){
        player.data.y = b.y - p.h;
        velocityY = 0;
        grounded = true;
      }else if(velocityY < 0){
        player.data.y = b.y + b.h;
        velocityY = 0;
      }
    }
  }

  if(player.data.y > ${project.worldHeight} + 300){
    gameOver = true;
    sound("hit");
    setTimeout(() => location.reload(), 900);
  }

  for(const item of elements){
    if(!item.active || item === player) continue;

    const p = rect(player);
    const b = rect(item);

    if(intersects(p,b)){
      if(item.data.type === "Coin"){
        item.active = false;
        item.element.remove();
        score++;
        scoreElement.textContent = score;
        sound("coin");
      }

      if(item.data.type === "Enemy"){
        if(velocityY > 0 && p.y + p.h < b.y + b.h * 0.55){
          item.active = false;
          item.element.remove();
          velocityY = -8;
          sound("hit");
        }else{
          gameOver = true;
          sound("hit");
          setTimeout(() => location.reload(), 900);
        }
      }
    }
  }
}

function render(){
  for(const item of elements){
    if(!item.active) continue;

    item.element.style.left = item.data.x + "px";
    item.element.style.top = item.data.y + "px";
  }

  cameraX = player.data.x - window.innerWidth * 0.35;
  cameraY = player.data.y - window.innerHeight * 0.45;

  cameraX = Math.max(0, Math.min(cameraX, ${project.worldWidth} - window.innerWidth));
  cameraY = Math.max(0, Math.min(cameraY, ${project.worldHeight} - window.innerHeight));

  world.style.transform =
    "translate(" + (-cameraX) + "px," + (-cameraY) + "px)";
}

function loop(){
  updatePlayer();
  render();
  requestAnimationFrame(loop);
}

function bindButton(id, down, up){
  const el = document.getElementById(id);

  el.addEventListener("touchstart", e => {
    e.preventDefault();
    down();
  });

  el.addEventListener("touchend", e => {
    e.preventDefault();
    up();
  });

  el.addEventListener("mousedown", down);
  el.addEventListener("mouseup", up);
  el.addEventListener("mouseleave", up);
}

bindButton("left",
  () => leftPressed = true,
  () => leftPressed = false
);

bindButton("right",
  () => rightPressed = true,
  () => rightPressed = false
);

bindButton("jump",
  () => jumpPressed = true,
  () => {}
);

window.addEventListener("keydown", e => {
  if(e.key === "ArrowLeft" || e.key === "a") leftPressed = true;
  if(e.key === "ArrowRight" || e.key === "d") rightPressed = true;
  if(e.key === "ArrowUp" || e.key === " " || e.key === "w") jumpPressed = true;
});

window.addEventListener("keyup", e => {
  if(e.key === "ArrowLeft" || e.key === "a") leftPressed = false;
  if(e.key === "ArrowRight" || e.key === "d") rightPressed = false;
});

document.body.addEventListener("touchstart", () => {
  try{
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    new AudioContext().resume();
  }catch(e){}
},{once:true});

loop();
</script>
</body>
</html>
''';
  }
}
