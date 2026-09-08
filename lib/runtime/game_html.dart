import 'dart:convert';

import '../models/game_project.dart';
import '../models/game_type.dart';

class GameHtml {
  static String generate(GameProject project) {
    switch (project.gameType) {
      case GameType.platformer:
        return _platformer(project);
      case GameType.ticTacToe:
        return _ticTacToe(project);
      case GameType.quiz:
        return _quiz(project);
      case GameType.puzzle:
        return _puzzle(project);
      case GameType.card:
        return _card(project);
      case GameType.clicker:
        return _clicker(project);
      case GameType.custom:
        return _custom(project);
    }
  }

  static String _base(String title, String body, String script) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<meta charset="UTF-8">
<title>$title</title>
<style>
* {
  box-sizing: border-box;
  -webkit-tap-highlight-color: transparent;
}
html, body {
  margin: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  font-family: Arial, sans-serif;
  background: #111;
}
body {
  display: flex;
  align-items: center;
  justify-content: center;
}
button {
  font-family: inherit;
  touch-action: manipulation;
}
</style>
</head>
<body>
$body
<script>
$script
</script>
</body>
</html>
''';
  }

  static String _platformer(GameProject project) {
    final objects = project.objects.map((o) {
      return {
        'type': o.type.toLowerCase(),
        'x': o.x,
        'y': o.y,
        'width': o.width,
        'height': o.height,
      };
    }).toList();

    return _base(
      'Platformer Preview',
      '''
<div id="game">
  <div id="world"></div>
  <div id="touch">
    <button id="left">◀</button>
    <button id="jump">▲</button>
    <button id="right">▶</button>
  </div>
</div>
''',
      '''
const objects = ${jsonEncode(objects)};

const game = document.getElementById("game");
const world = document.getElementById("world");

game.style.position = "relative";
game.style.width = "100vw";
game.style.height = "100vh";
game.style.background = "linear-gradient(#75c9ff,#dff6ff)";
game.style.overflow = "hidden";

world.style.position = "absolute";
world.style.left = "0";
world.style.top = "0";
world.style.width = "3000px";
world.style.height = "1200px";

objects.forEach(o => {
  const el = document.createElement("div");
  el.style.position = "absolute";
  el.style.left = o.x + "px";
  el.style.top = o.y + "px";
  el.style.width = o.width + "px";
  el.style.height = o.height + "px";
  el.style.background = "#4caf50";
  el.style.borderRadius = "8px";

  if (o.type === "player") el.style.background = "#ff5252";
  if (o.type === "coin") {
    el.style.background = "#ffd740";
    el.style.borderRadius = "50%";
  }
  if (o.type === "enemy") el.style.background = "#7e57c2";
  if (o.type === "box") el.style.background = "#795548";

  world.appendChild(el);
});

const touch = document.getElementById("touch");
touch.style.position = "fixed";
touch.style.bottom = "20px";
touch.style.left = "20px";
touch.style.right = "20px";
touch.style.display = "flex";
touch.style.justifyContent = "space-between";

document.querySelectorAll("#touch button").forEach(b => {
  b.style.width = "70px";
  b.style.height = "70px";
  b.style.border = "0";
  b.style.borderRadius = "50%";
  b.style.fontSize = "30px";
  b.style.opacity = "0.8";
});
''',
    );
  }

  static String _ticTacToe(GameProject project) {
    return _base(
      'Tic Tac Toe Preview',
      '''
<div id="app">
  <h1>XO</h1>
  <div id="status">Player X</div>
  <div id="board"></div>
  <button id="reset">Restart</button>
</div>
''',
      '''
const app = document.getElementById("app");
const board = document.getElementById("board");
const status = document.getElementById("status");
const reset = document.getElementById("reset");

app.style.width = "min(92vw, 430px)";
app.style.textAlign = "center";
app.style.color = "white";

board.style.display = "grid";
board.style.gridTemplateColumns = "repeat(3,1fr)";
board.style.gap = "10px";
board.style.margin = "25px 0";

let cells = Array(9).fill("");
let player = "X";
let finished = false;

function draw() {
  board.innerHTML = "";

  cells.forEach((value, index) => {
    const cell = document.createElement("button");
    cell.textContent = value;
    cell.style.height = "100px";
    cell.style.fontSize = "45px";
    cell.style.fontWeight = "bold";
    cell.style.border = "0";
    cell.style.borderRadius = "16px";
    cell.style.background = "#292929";
    cell.style.color = "white";

    cell.onclick = () => play(index);

    board.appendChild(cell);
  });
}

function play(index) {
  if (cells[index] || finished) return;

  cells[index] = player;

  const winner = checkWinner();

  if (winner) {
    status.textContent = "Winner: " + winner;
    finished = true;
  } else if (!cells.includes("")) {
    status.textContent = "Draw!";
    finished = true;
  } else {
    player = player === "X" ? "O" : "X";
    status.textContent = "Player " + player;
  }

  draw();
}

function checkWinner() {
  const lines = [
    [0,1,2],[3,4,5],[6,7,8],
    [0,3,6],[1,4,7],[2,5,8],
    [0,4,8],[2,4,6]
  ];

  for (const line of lines) {
    const [a,b,c] = line;
    if (cells[a] && cells[a] === cells[b] && cells[a] === cells[c]) {
      return cells[a];
    }
  }

  return null;
}

reset.onclick = () => {
  cells = Array(9).fill("");
  player = "X";
  finished = false;
  status.textContent = "Player X";
  draw();
};

reset.style.border = "0";
reset.style.padding = "14px 30px";
reset.style.borderRadius = "12px";
reset.style.fontSize = "18px";

draw();
''',
    );
  }

  static String _quiz(GameProject project) {
    return _base(
      'Quiz Preview',
      '''
<div id="app">
  <div id="progress">Question 1</div>
  <div id="card">
    <div id="question">Your question will appear here</div>
    <div id="answers"></div>
    <div id="result"></div>
  </div>
</div>
''',
      '''
const app = document.getElementById("app");
const card = document.getElementById("card");
const question = document.getElementById("question");
const answers = document.getElementById("answers");
const result = document.getElementById("result");

app.style.width = "min(92vw, 520px)";
app.style.color = "white";

card.style.background = "#202020";
card.style.borderRadius = "24px";
card.style.padding = "25px";
card.style.boxShadow = "0 15px 40px rgba(0,0,0,.35)";

question.style.fontSize = "25px";
question.style.fontWeight = "bold";
question.style.marginBottom = "25px";

const empty = document.createElement("div");
empty.textContent = "Add a Quiz Question in the editor to start building your quiz.";
empty.style.opacity = ".7";
empty.style.textAlign = "center";
empty.style.padding = "20px";

answers.appendChild(empty);
''',
    );
  }

  static String _puzzle(GameProject project) {
    return _base(
      'Puzzle Preview',
      '''
<div id="app">
  <h1>Puzzle</h1>
  <div id="board"></div>
  <p>Build your puzzle from the editor.</p>
</div>
''',
      '''
const app = document.getElementById("app");
const board = document.getElementById("board");

app.style.width = "min(92vw, 500px)";
app.style.textAlign = "center";
app.style.color = "white";

board.style.width = "300px";
board.style.height = "300px";
board.style.margin = "30px auto";
board.style.borderRadius = "20px";
board.style.border = "2px dashed #777";
board.style.display = "flex";
board.style.alignItems = "center";
board.style.justifyContent = "center";

board.textContent = "Your puzzle";
''',
    );
  }

  static String _card(GameProject project) {
    return _base(
      'Card Game Preview',
      '''
<div id="app">
  <h1>Card Game</h1>
  <div id="cards"></div>
  <p>Build your cards from the editor.</p>
</div>
''',
      '''
const app = document.getElementById("app");
const cards = document.getElementById("cards");

app.style.width = "min(92vw, 600px)";
app.style.textAlign = "center";
app.style.color = "white";

cards.style.minHeight = "220px";
cards.style.display = "flex";
cards.style.alignItems = "center";
cards.style.justifyContent = "center";
cards.style.border = "2px dashed #777";
cards.style.borderRadius = "20px";

cards.textContent = "Your cards";
''',
    );
  }

  static String _clicker(GameProject project) {
    return _base(
      'Clicker Preview',
      '''
<div id="app">
  <div id="score">0</div>
  <button id="click">CLICK</button>
  <p>Build your clicker from the editor.</p>
</div>
''',
      '''
const app = document.getElementById("app");
const score = document.getElementById("score");
const click = document.getElementById("click");

app.style.textAlign = "center";
app.style.color = "white";

score.style.fontSize = "70px";
score.style.fontWeight = "bold";
score.style.marginBottom = "30px";

click.style.width = "220px";
click.style.height = "220px";
click.style.borderRadius = "50%";
click.style.border = "0";
click.style.fontSize = "30px";
click.style.fontWeight = "bold";

let value = 0;

click.onclick = () => {
  value++;
  score.textContent = value;
};
''',
    );
  }

  static String _custom(GameProject project) {
    return _base(
      'Game Preview',
      '''
<div id="app">
  <h1>Your Game</h1>
  <p>Start building your game from the editor.</p>
</div>
''',
      '''
const app = document.getElementById("app");

app.style.color = "white";
app.style.textAlign = "center";
''',
    );
  }
}
