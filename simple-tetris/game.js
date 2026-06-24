(() => {
  'use strict';

  const COLS = 10;
  const ROWS = 20;
  const BLOCK = 30;
  const NEXT_BLOCK = 24;

  const boardCanvas = document.getElementById('board');
  const ctx = boardCanvas.getContext('2d');
  const nextCanvas = document.getElementById('next');
  const nctx = nextCanvas.getContext('2d');

  const scoreEl = document.getElementById('score');
  const linesEl = document.getElementById('lines');
  const levelEl = document.getElementById('level');
  const overlay = document.getElementById('overlay');
  const overlayTitle = document.getElementById('overlayTitle');
  const overlayText = document.getElementById('overlayText');
  const startBtn = document.getElementById('startBtn');
  const restartBtn = document.getElementById('restartBtn');

  const COLORS = {
    I: '#36f4ff',
    J: '#4f73ff',
    L: '#ff9f38',
    O: '#ffe15a',
    S: '#6cff82',
    T: '#c65cff',
    Z: '#ff4f70'
  };

  const SHAPES = {
    I: [
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ],
    J: [
      [1, 0, 0],
      [1, 1, 1],
      [0, 0, 0]
    ],
    L: [
      [0, 0, 1],
      [1, 1, 1],
      [0, 0, 0]
    ],
    O: [
      [1, 1],
      [1, 1]
    ],
    S: [
      [0, 1, 1],
      [1, 1, 0],
      [0, 0, 0]
    ],
    T: [
      [0, 1, 0],
      [1, 1, 1],
      [0, 0, 0]
    ],
    Z: [
      [1, 1, 0],
      [0, 1, 1],
      [0, 0, 0]
    ]
  };

  const LINE_SCORE = [0, 100, 300, 500, 800];
  const clone = matrix => matrix.map(row => row.slice());

  let grid;
  let current;
  let nextType;
  let bag = [];
  let score = 0;
  let lines = 0;
  let level = 1;
  let dropCounter = 0;
  let lastTime = 0;
  let running = false;
  let paused = false;
  let over = false;
  let rafId = 0;

  function makeGrid() {
    return Array.from({ length: ROWS }, () => Array(COLS).fill(null));
  }

  function shuffle(array) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
    return array;
  }

  function takeFromBag() {
    if (bag.length === 0) bag = shuffle(Object.keys(SHAPES));
    return bag.pop();
  }

  function createPiece(type) {
    const matrix = clone(SHAPES[type]);
    return {
      type,
      matrix,
      x: Math.floor((COLS - matrix[0].length) / 2),
      y: type === 'I' ? -1 : 0
    };
  }

  function resetGame() {
    grid = makeGrid();
    bag = [];
    score = 0;
    lines = 0;
    level = 1;
    dropCounter = 0;
    lastTime = performance.now();
    over = false;
    paused = false;
    running = true;
    nextType = takeFromBag();
    spawnPiece();
    hideOverlay();
    updateHud();
    draw();
  }

  function spawnPiece() {
    current = createPiece(nextType);
    nextType = takeFromBag();
    if (collides(current, current.x, current.y, current.matrix)) {
      gameOver();
    }
  }

  function collides(piece, px, py, matrix) {
    for (let y = 0; y < matrix.length; y++) {
      for (let x = 0; x < matrix[y].length; x++) {
        if (!matrix[y][x]) continue;
        const bx = px + x;
        const by = py + y;
        if (bx < 0 || bx >= COLS || by >= ROWS) return true;
        if (by >= 0 && grid[by][bx]) return true;
      }
    }
    return false;
  }

  function mergePiece() {
    const { matrix, x: px, y: py, type } = current;
    for (let y = 0; y < matrix.length; y++) {
      for (let x = 0; x < matrix[y].length; x++) {
        if (!matrix[y][x]) continue;
        const by = py + y;
        const bx = px + x;
        if (by >= 0 && by < ROWS && bx >= 0 && bx < COLS) {
          grid[by][bx] = type;
        }
      }
    }
  }

  function clearLines() {
    let cleared = 0;
    outer: for (let y = ROWS - 1; y >= 0; y--) {
      for (let x = 0; x < COLS; x++) {
        if (!grid[y][x]) continue outer;
      }
      grid.splice(y, 1);
      grid.unshift(Array(COLS).fill(null));
      cleared++;
      y++;
    }

    if (cleared > 0) {
      lines += cleared;
      level = Math.floor(lines / 10) + 1;
      score += LINE_SCORE[cleared] * level;
      updateHud();
    }
  }

  function hardDrop() {
    if (!canPlay()) return;
    let distance = 0;
    while (!collides(current, current.x, current.y + 1, current.matrix)) {
      current.y++;
      distance++;
    }
    score += distance * 2;
    lockPiece();
  }

  function softDrop() {
    if (!canPlay()) return;
    if (!collides(current, current.x, current.y + 1, current.matrix)) {
      current.y++;
      score += 1;
    } else {
      lockPiece();
    }
    dropCounter = 0;
    updateHud();
  }

  function move(dx) {
    if (!canPlay()) return;
    if (!collides(current, current.x + dx, current.y, current.matrix)) {
      current.x += dx;
    }
  }

  function rotateMatrix(matrix, dir) {
    const n = matrix.length;
    const result = Array.from({ length: n }, () => Array(n).fill(0));
    for (let y = 0; y < n; y++) {
      for (let x = 0; x < n; x++) {
        if (dir > 0) result[x][n - 1 - y] = matrix[y][x];
        else result[n - 1 - x][y] = matrix[y][x];
      }
    }
    return result;
  }

  function rotate(dir) {
    if (!canPlay() || current.type === 'O') return;
    const rotated = rotateMatrix(current.matrix, dir);
    const kicks = [0, -1, 1, -2, 2];
    for (const kick of kicks) {
      if (!collides(current, current.x + kick, current.y, rotated)) {
        current.x += kick;
        current.matrix = rotated;
        return;
      }
    }
  }

  function lockPiece() {
    mergePiece();
    clearLines();
    spawnPiece();
    updateHud();
  }

  function dropInterval() {
    return Math.max(80, 1000 - (level - 1) * 75);
  }

  function update(time = performance.now()) {
    const delta = time - lastTime;
    lastTime = time;

    if (running && !paused && !over) {
      dropCounter += delta;
      if (dropCounter >= dropInterval()) {
        if (!collides(current, current.x, current.y + 1, current.matrix)) {
          current.y++;
        } else {
          lockPiece();
        }
        dropCounter = 0;
      }
      draw();
    }

    rafId = requestAnimationFrame(update);
  }

  function canPlay() {
    return running && !paused && !over;
  }

  function gameOver() {
    over = true;
    running = false;
    showOverlay('GAME OVER', `スコア ${score.toLocaleString()} / ライン ${lines}<br>もう一回やりますか？`, 'RETRY');
  }

  function togglePause() {
    if (over || !running) return;
    paused = !paused;
    if (paused) showOverlay('PAUSE', 'Pキーでもう一度再開します。', 'RESUME');
    else hideOverlay();
  }

  function showOverlay(title, text, button) {
    overlayTitle.textContent = title;
    overlayText.innerHTML = text;
    startBtn.textContent = button;
    overlay.classList.remove('hidden');
  }

  function hideOverlay() {
    overlay.classList.add('hidden');
  }

  function updateHud() {
    scoreEl.textContent = score.toLocaleString();
    linesEl.textContent = String(lines);
    levelEl.textContent = String(level);
    drawNext();
  }

  function ghostY() {
    let y = current.y;
    while (!collides(current, current.x, y + 1, current.matrix)) y++;
    return y;
  }

  function drawCell(context, x, y, size, type, alpha = 1) {
    const px = x * size;
    const py = y * size;
    context.save();
    context.globalAlpha = alpha;
    context.fillStyle = COLORS[type];
    context.fillRect(px + 1, py + 1, size - 2, size - 2);

    const grad = context.createLinearGradient(px, py, px + size, py + size);
    grad.addColorStop(0, 'rgba(255,255,255,.34)');
    grad.addColorStop(.48, 'rgba(255,255,255,.05)');
    grad.addColorStop(1, 'rgba(0,0,0,.25)');
    context.fillStyle = grad;
    context.fillRect(px + 1, py + 1, size - 2, size - 2);

    context.strokeStyle = 'rgba(255,255,255,.18)';
    context.lineWidth = 1;
    context.strokeRect(px + 1.5, py + 1.5, size - 3, size - 3);
    context.restore();
  }

  function drawMatrix(context, matrix, offsetX, offsetY, size, type, alpha = 1) {
    for (let y = 0; y < matrix.length; y++) {
      for (let x = 0; x < matrix[y].length; x++) {
        if (matrix[y][x]) drawCell(context, offsetX + x, offsetY + y, size, type, alpha);
      }
    }
  }

  function drawBoardBackground() {
    ctx.fillStyle = '#050711';
    ctx.fillRect(0, 0, boardCanvas.width, boardCanvas.height);

    ctx.strokeStyle = 'rgba(255,255,255,.045)';
    ctx.lineWidth = 1;
    for (let x = 0; x <= COLS; x++) {
      ctx.beginPath();
      ctx.moveTo(x * BLOCK + .5, 0);
      ctx.lineTo(x * BLOCK + .5, ROWS * BLOCK);
      ctx.stroke();
    }
    for (let y = 0; y <= ROWS; y++) {
      ctx.beginPath();
      ctx.moveTo(0, y * BLOCK + .5);
      ctx.lineTo(COLS * BLOCK, y * BLOCK + .5);
      ctx.stroke();
    }
  }

  function draw() {
    drawBoardBackground();

    for (let y = 0; y < ROWS; y++) {
      for (let x = 0; x < COLS; x++) {
        const type = grid[y][x];
        if (type) drawCell(ctx, x, y, BLOCK, type);
      }
    }

    if (current && !over) {
      drawMatrix(ctx, current.matrix, current.x, ghostY(), BLOCK, current.type, 0.22);
      drawMatrix(ctx, current.matrix, current.x, current.y, BLOCK, current.type, 1);
    }
  }

  function drawNext() {
    nctx.clearRect(0, 0, nextCanvas.width, nextCanvas.height);
    nctx.fillStyle = 'rgba(0,0,0,.18)';
    nctx.fillRect(0, 0, nextCanvas.width, nextCanvas.height);

    if (!nextType) return;
    const matrix = SHAPES[nextType];
    const w = matrix[0].length;
    const h = matrix.length;
    const ox = Math.floor((nextCanvas.width / NEXT_BLOCK - w) / 2);
    const oy = Math.floor((nextCanvas.height / NEXT_BLOCK - h) / 2);
    drawMatrix(nctx, matrix, ox, oy, NEXT_BLOCK, nextType, 1);
  }

  function handleKey(event) {
    const keys = ['ArrowLeft', 'ArrowRight', 'ArrowDown', 'ArrowUp', 'Space'];
    if (keys.includes(event.code)) event.preventDefault();

    if (event.code === 'KeyP') {
      togglePause();
      return;
    }
    if (event.code === 'KeyR') {
      resetGame();
      return;
    }
    if (!canPlay()) return;

    switch (event.code) {
      case 'ArrowLeft': move(-1); break;
      case 'ArrowRight': move(1); break;
      case 'ArrowDown': softDrop(); break;
      case 'ArrowUp':
      case 'KeyX': rotate(1); break;
      case 'KeyZ': rotate(-1); break;
      case 'Space': hardDrop(); break;
      default: return;
    }
    draw();
  }

  let touchStart = null;
  boardCanvas.addEventListener('pointerdown', event => {
    event.preventDefault();
    boardCanvas.setPointerCapture?.(event.pointerId);
    touchStart = { x: event.clientX, y: event.clientY, t: performance.now() };
  });

  boardCanvas.addEventListener('pointerup', event => {
    if (!touchStart) return;
    event.preventDefault();
    const dx = event.clientX - touchStart.x;
    const dy = event.clientY - touchStart.y;
    const adx = Math.abs(dx);
    const ady = Math.abs(dy);
    touchStart = null;

    if (!canPlay()) return;
    if (Math.max(adx, ady) < 22) rotate(1);
    else if (adx > ady) move(dx > 0 ? 1 : -1);
    else if (dy > 0) softDrop();
    else hardDrop();
    draw();
  });

  startBtn.addEventListener('click', () => {
    if (paused) {
      paused = false;
      hideOverlay();
    } else {
      resetGame();
    }
  });
  restartBtn.addEventListener('click', resetGame);
  window.addEventListener('keydown', handleKey);

  grid = makeGrid();
  nextType = takeFromBag();
  updateHud();
  drawBoardBackground();
  drawNext();
  cancelAnimationFrame(rafId);
  rafId = requestAnimationFrame(update);
})();
