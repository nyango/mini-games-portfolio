(() => {
  'use strict';

  const canvas = document.getElementById('game');
  const ctx = canvas.getContext('2d');
  const scoreEl = document.getElementById('score');
  const comboEl = document.getElementById('combo');
  const bestEl = document.getElementById('best');
  const energyEl = document.getElementById('energy');
  const overlay = document.getElementById('overlay');
  const startBtn = document.getElementById('startBtn');
  const message = document.getElementById('message');
  const modeDesc = document.getElementById('modeDesc');
  const modeBadge = document.getElementById('modeBadge');
  const modeBtns = [...document.querySelectorAll('.mode')];
  const guideToggle = document.getElementById('guideToggle');
  const guide = document.getElementById('guide');

  const W = 960;
  const H = 540;
  const TAU = Math.PI * 2;
  const DPR_MAX = 2;

  const modeSettings = {
    normal: {
      label: 'NORMAL',
      desc: 'NORMAL：元の緊張感重視。短いバーストで正確に敵を砕き、ゲージ管理で高得点を狙う。',
      bestKey: 'neon-combo-burst-best-v1',
      dashDuration: 0.18,
      dashCool: 0.24,
      dashSpeed: 1040,
      energyCost: 0.26,
      energyRegen: 0.052,
      killRadius: 35,
      comboWindow: 2.1,
      killEnergy: 0.045,
      gemEnergy: 0.33,
      gemInterval: [1.4, 2.35],
      spawnBase: 0.9,
      spawnMin: 0.18,
      spawnSlope: 0.008,
      extraSpawnTime: 25,
      extraSpawnChance: 0.18,
      enemySpeed: 1,
      pickupBonus: 7,
      dangerHitRadius: 0.78,
      chainRadius: 0,
      chainDepth: 0,
      emergencyCost: 0
    },
    easy: {
      label: '楽々連鎖モード',
      desc: '楽々連鎖モード：当たり判定が広く、コンボが切れにくい。敵を巻き込む連鎖爆発と緊急バリアで爽快に遊べる。',
      bestKey: 'neon-combo-burst-best-easy-v1',
      dashDuration: 0.24,
      dashCool: 0.16,
      dashSpeed: 1120,
      energyCost: 0.18,
      energyRegen: 0.085,
      killRadius: 60,
      comboWindow: 4.0,
      killEnergy: 0.075,
      gemEnergy: 0.45,
      gemInterval: [1.0, 1.7],
      spawnBase: 0.78,
      spawnMin: 0.15,
      spawnSlope: 0.006,
      extraSpawnTime: 14,
      extraSpawnChance: 0.26,
      enemySpeed: 0.83,
      pickupBonus: 20,
      dangerHitRadius: 0.58,
      chainRadius: 78,
      chainDepth: 2,
      emergencyCost: 0.22
    }
  };

  let currentMode = localStorage.getItem('neon-combo-burst-mode') || 'easy';
  if (!modeSettings[currentMode]) currentMode = 'easy';
  let best = Number(localStorage.getItem(modeSettings[currentMode].bestKey) || 0);
  bestEl.textContent = String(best);

  const pointer = { x: W / 2, y: H / 2, down: false, active: false };
  const keys = new Set();

  let state;
  let last = performance.now();
  let raf = 0;

  const rand = (min, max) => min + Math.random() * (max - min);
  const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
  const dist2 = (a, b) => {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return dx * dx + dy * dy;
  };
  const easeOut = t => 1 - Math.pow(1 - t, 3);
  const cfg = () => modeSettings[currentMode];

  function resize() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(DPR_MAX, window.devicePixelRatio || 1);
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
    ctx.setTransform(canvas.width / W, 0, 0, canvas.height / H, 0, 0);
  }

  function toCanvasPoint(event) {
    const rect = canvas.getBoundingClientRect();
    const client = event.touches ? event.touches[0] || event.changedTouches[0] : event;
    return {
      x: clamp((client.clientX - rect.left) / rect.width * W, 0, W),
      y: clamp((client.clientY - rect.top) / rect.height * H, 0, H)
    };
  }

  function refreshModeUI() {
    const c = cfg();
    modeBtns.forEach(btn => btn.classList.toggle('is-active', btn.dataset.mode === currentMode));
    modeDesc.textContent = c.desc;
    modeBadge.textContent = c.label;
    best = Number(localStorage.getItem(c.bestKey) || 0);
    bestEl.textContent = String(best);
  }

  function setMode(mode) {
    if (!modeSettings[mode]) return;
    currentMode = mode;
    localStorage.setItem('neon-combo-burst-mode', currentMode);
    refreshModeUI();
  }

  function reset() {
    state = {
      playing: true,
      mode: currentMode,
      time: 0,
      score: 0,
      combo: 1,
      comboTimer: 0,
      energy: 1,
      shake: 0,
      flash: 0,
      slow: 0,
      spawnTimer: 0,
      gemTimer: 0,
      dangerPulse: 0,
      player: {
        x: W / 2,
        y: H / 2,
        vx: 0,
        vy: 0,
        r: 14,
        dash: 0,
        dashCool: 0,
        dashDirX: 1,
        dashDirY: 0,
        trail: []
      },
      enemies: [],
      gems: [],
      particles: [],
      rings: [],
      texts: []
    };
    pointer.x = W / 2;
    pointer.y = H / 2;
    scoreEl.textContent = '0';
    comboEl.textContent = 'x1';
    energyEl.style.transform = 'scaleX(1)';
    overlay.classList.add('hidden');
  }

  function startGame() {
    reset();
  }

  function endGame() {
    state.playing = false;
    state.flash = 1;
    if (state.score > best) {
      best = state.score;
      localStorage.setItem(cfg().bestKey, String(best));
      bestEl.textContent = String(best);
    }
    message.innerHTML = `${cfg().label}：スコア <b>${state.score}</b> / ベスト <b>${best}</b><br>もう一回でコンボ更新を狙えます。`;
    startBtn.textContent = 'RETRY';
    overlay.classList.remove('hidden');
  }

  function spawnEnemy() {
    const side = Math.floor(rand(0, 4));
    let x, y;
    if (side === 0) { x = rand(0, W); y = -35; }
    else if (side === 1) { x = W + 35; y = rand(0, H); }
    else if (side === 2) { x = rand(0, W); y = H + 35; }
    else { x = -35; y = rand(0, H); }

    const p = state.player;
    const angle = Math.atan2(p.y - y, p.x - x) + rand(-0.48, 0.48);
    const difficulty = Math.min(1, state.time / 85);
    const speed = (rand(58, 114) + difficulty * 88) * cfg().enemySpeed;
    const size = rand(11, 19) - difficulty * 2;
    state.enemies.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      r: clamp(size, 9, 20),
      rot: rand(0, TAU),
      spin: rand(-5, 5),
      hue: rand(330, 365),
      born: state.time
    });
  }

  function spawnGem() {
    state.gems.push({
      x: rand(55, W - 55),
      y: rand(72, H - 55),
      r: 9,
      life: 8.5,
      pulse: rand(0, TAU)
    });
  }

  function burst() {
    const p = state.player;
    const c = cfg();
    if (!state.playing || p.dashCool > 0 || state.energy < c.energyCost) return;

    let dx = pointer.x - p.x;
    let dy = pointer.y - p.y;
    const len = Math.hypot(dx, dy) || 1;
    dx /= len;
    dy /= len;

    p.dash = c.dashDuration;
    p.dashCool = c.dashCool;
    p.dashDirX = dx;
    p.dashDirY = dy;
    p.vx = dx * c.dashSpeed;
    p.vy = dy * c.dashSpeed;
    state.energy = Math.max(0, state.energy - c.energyCost);
    state.shake = Math.max(state.shake, currentMode === 'easy' ? 11 : 9);
    state.flash = Math.max(state.flash, currentMode === 'easy' ? 0.22 : 0.18);
    addRing(p.x, p.y, currentMode === 'easy' ? 62 : 42, '#37f8ff');
    for (let i = 0; i < (currentMode === 'easy' ? 26 : 18); i++) {
      addParticle(p.x, p.y, rand(140, 430), rand(0, TAU), '#37f8ff', rand(0.18, 0.45), rand(2, 5));
    }
  }

  function addParticle(x, y, speed, angle, color, life = 0.45, size = 3) {
    state.particles.push({
      x, y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      color,
      life,
      maxLife: life,
      size,
      drag: rand(2.5, 6)
    });
  }

  function addRing(x, y, radius, color) {
    state.rings.push({ x, y, r: 5, end: radius, color, life: 0.34, maxLife: 0.34 });
  }

  function addText(x, y, text, color) {
    state.texts.push({ x, y, text, color, life: 0.75, maxLife: 0.75, vy: -42 });
  }

  function killEnemy(enemy, bonus = 0) {
    const s = 12 + Math.min(42, state.combo * 1.3);
    const points = Math.round((10 + bonus) * state.combo);
    state.score += points;
    state.combo = Math.min(currentMode === 'easy' ? 199 : 99, state.combo + 1);
    state.comboTimer = cfg().comboWindow;
    state.energy = clamp(state.energy + cfg().killEnergy, 0, 1);
    state.slow = Math.max(state.slow, currentMode === 'easy' ? 0.045 : 0.035);
    state.shake = Math.max(state.shake, 5 + Math.min(13, state.combo * 0.15));
    state.flash = Math.max(state.flash, 0.13);
    addRing(enemy.x, enemy.y, s + 18, '#ff3df2');
    addText(enemy.x, enemy.y - 18, `+${points}`, '#ffe16b');
    for (let i = 0; i < (currentMode === 'easy' ? 34 : 26); i++) {
      addParticle(enemy.x, enemy.y, rand(110, 560), rand(0, TAU), i % 3 === 0 ? '#ffe16b' : '#ff3df2', rand(0.25, 0.78), rand(2, 6));
    }
  }

  function triggerChain(origin, depth = 0) {
    const c = cfg();
    if (!c.chainRadius || depth >= c.chainDepth) return;

    const radius = c.chainRadius * (1 - depth * 0.18);
    let chained = 0;
    for (let i = state.enemies.length - 1; i >= 0; i--) {
      const e = state.enemies[i];
      if (dist2(origin, e) < Math.pow(radius + e.r, 2)) {
        state.enemies.splice(i, 1);
        killEnemy(e, 8 + depth * 4);
        chained++;
        triggerChain(e, depth + 1);
      }
    }
    if (chained) {
      addRing(origin.x, origin.y, radius, '#ffe16b');
      addText(origin.x, origin.y + 22, `CHAIN x${chained}`, '#37f8ff');
    }
  }

  function update(dt) {
    if (!state) reset();
    const slowScale = state.slow > 0 ? 0.44 : 1;
    const gameDt = dt * slowScale;
    state.time += gameDt;
    state.slow = Math.max(0, state.slow - dt);
    state.shake = Math.max(0, state.shake - dt * 26);
    state.flash = Math.max(0, state.flash - dt * 2.4);
    state.dangerPulse += dt;

    if (!state.playing) {
      updateEffects(dt);
      return;
    }

    const p = state.player;
    const c = cfg();
    const aimX = pointer.active ? pointer.x : W / 2 + Math.cos(state.time * 0.65) * 160;
    const aimY = pointer.active ? pointer.y : H / 2 + Math.sin(state.time * 0.5) * 90;

    p.dash = Math.max(0, p.dash - gameDt);
    p.dashCool = Math.max(0, p.dashCool - gameDt);
    state.energy = clamp(state.energy + gameDt * c.energyRegen, 0, 1);

    if (p.dash <= 0) {
      p.vx += (aimX - p.x) * 14 * gameDt;
      p.vy += (aimY - p.y) * 14 * gameDt;
      p.vx *= Math.pow(0.025, gameDt);
      p.vy *= Math.pow(0.025, gameDt);
    } else {
      p.vx = p.dashDirX * c.dashSpeed;
      p.vy = p.dashDirY * c.dashSpeed;
    }

    p.x += p.vx * gameDt;
    p.y += p.vy * gameDt;

    if (p.x < p.r) { p.x = p.r; p.vx = Math.abs(p.vx) * 0.35; }
    if (p.x > W - p.r) { p.x = W - p.r; p.vx = -Math.abs(p.vx) * 0.35; }
    if (p.y < 64) { p.y = 64; p.vy = Math.abs(p.vy) * 0.35; }
    if (p.y > H - p.r) { p.y = H - p.r; p.vy = -Math.abs(p.vy) * 0.35; }

    p.trail.unshift({ x: p.x, y: p.y, dash: p.dash > 0 });
    p.trail.length = Math.min(p.trail.length, p.dash > 0 ? 24 : 14);

    state.spawnTimer -= gameDt;
    const spawnEvery = Math.max(c.spawnMin, c.spawnBase - state.time * c.spawnSlope);
    if (state.spawnTimer <= 0) {
      spawnEnemy();
      if (state.time > c.extraSpawnTime && Math.random() < c.extraSpawnChance) spawnEnemy();
      state.spawnTimer = spawnEvery;
    }

    state.gemTimer -= gameDt;
    if (state.gemTimer <= 0) {
      spawnGem();
      state.gemTimer = rand(c.gemInterval[0], c.gemInterval[1]);
    }

    state.comboTimer -= gameDt;
    if (state.comboTimer <= 0 && state.combo > 1) {
      state.combo = 1;
      addText(p.x, p.y - 26, 'combo lost', 'rgba(255,255,255,.7)');
    }

    updateEnemies(gameDt);
    updateGems(gameDt);
    updateEffects(dt);

    scoreEl.textContent = String(state.score);
    comboEl.textContent = `x${state.combo}`;
    energyEl.style.transform = `scaleX(${state.energy})`;
  }

  function updateEnemies(dt) {
    const p = state.player;
    const c = cfg();
    const killRadius = p.dash > 0 ? c.killRadius : 0;
    for (let i = state.enemies.length - 1; i >= 0; i--) {
      const e = state.enemies[i];
      e.x += e.vx * dt;
      e.y += e.vy * dt;
      e.rot += e.spin * dt;

      if (e.x < -90 || e.x > W + 90 || e.y < -90 || e.y > H + 90) {
        state.enemies.splice(i, 1);
        continue;
      }

      const d = Math.sqrt(dist2(e, p));
      if (p.dash > 0 && d < e.r + killRadius) {
        killEnemy(e, Math.floor((1 - p.dash / c.dashDuration) * 10));
        state.enemies.splice(i, 1);
        triggerChain(e);
        continue;
      }
      if (d < e.r + p.r * c.dangerHitRadius) {
        if (c.emergencyCost && state.energy >= c.emergencyCost) {
          state.energy = Math.max(0, state.energy - c.emergencyCost);
          killEnemy(e, 4);
          state.enemies.splice(i, 1);
          triggerChain(e);
          state.shake = Math.max(state.shake, 13);
          state.flash = Math.max(state.flash, 0.25);
          addRing(p.x, p.y, 88, '#ffffff');
          addText(p.x, p.y - 28, 'SAFE BURST', '#ffffff');
          continue;
        }
        explodePlayer();
        endGame();
        return;
      }
    }
  }

  function updateGems(dt) {
    const p = state.player;
    const c = cfg();
    for (let i = state.gems.length - 1; i >= 0; i--) {
      const g = state.gems[i];
      g.life -= dt;
      g.pulse += dt * 5;
      if (g.life <= 0) {
        state.gems.splice(i, 1);
        continue;
      }
      if (dist2(g, p) < Math.pow(g.r + p.r + c.pickupBonus, 2)) {
        state.energy = clamp(state.energy + c.gemEnergy, 0, 1);
        state.score += 5 * state.combo;
        addText(g.x, g.y - 14, 'CHARGE', '#37f8ff');
        addRing(g.x, g.y, 44, '#37f8ff');
        for (let n = 0; n < 16; n++) addParticle(g.x, g.y, rand(70, 260), rand(0, TAU), '#37f8ff', rand(0.22, 0.55), rand(2, 4));
        state.gems.splice(i, 1);
      }
    }
  }

  function updateEffects(dt) {
    for (let i = state.particles.length - 1; i >= 0; i--) {
      const p = state.particles[i];
      p.life -= dt;
      p.vx *= Math.pow(0.04, dt / p.drag);
      p.vy *= Math.pow(0.04, dt / p.drag);
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.life <= 0) state.particles.splice(i, 1);
    }
    for (let i = state.rings.length - 1; i >= 0; i--) {
      const r = state.rings[i];
      r.life -= dt;
      const t = 1 - r.life / r.maxLife;
      r.r = easeOut(t) * r.end;
      if (r.life <= 0) state.rings.splice(i, 1);
    }
    for (let i = state.texts.length - 1; i >= 0; i--) {
      const t = state.texts[i];
      t.life -= dt;
      t.y += t.vy * dt;
      if (t.life <= 0) state.texts.splice(i, 1);
    }
  }

  function explodePlayer() {
    const p = state.player;
    addRing(p.x, p.y, 160, '#ffffff');
    for (let i = 0; i < 70; i++) {
      addParticle(p.x, p.y, rand(170, 720), rand(0, TAU), i % 2 ? '#ff3df2' : '#37f8ff', rand(0.38, 1.1), rand(2, 7));
    }
  }

  function draw() {
    if (!state) reset();
    ctx.save();
    ctx.clearRect(0, 0, W, H);

    const shake = state.shake;
    if (shake > 0) ctx.translate(rand(-shake, shake), rand(-shake, shake));

    drawBackground();
    drawGems();
    drawEnemies();
    drawPlayer();
    drawEffects();
    drawAim();

    if (state.flash > 0) {
      ctx.globalAlpha = Math.min(0.22, state.flash);
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, W, H);
      ctx.globalAlpha = 1;
    }
    ctx.restore();
  }

  function drawBackground() {
    const grd = ctx.createRadialGradient(W / 2, H / 2, 40, W / 2, H / 2, 560);
    grd.addColorStop(0, '#111a42');
    grd.addColorStop(0.58, '#070814');
    grd.addColorStop(1, '#02030a');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, W, H);

    ctx.save();
    ctx.globalAlpha = 0.17;
    ctx.strokeStyle = '#37f8ff';
    ctx.lineWidth = 1;
    const offset = (state.time * 22) % 42;
    for (let x = -42 + offset; x < W + 42; x += 42) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, H);
      ctx.stroke();
    }
    for (let y = 0; y < H + 42; y += 42) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(W, y);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawPlayer() {
    const p = state.player;
    ctx.save();
    for (let i = p.trail.length - 1; i >= 0; i--) {
      const t = p.trail[i];
      const a = (1 - i / p.trail.length) * (t.dash ? 0.35 : 0.17);
      ctx.globalAlpha = a;
      ctx.fillStyle = t.dash ? '#37f8ff' : '#ffffff';
      ctx.beginPath();
      ctx.arc(t.x, t.y, p.r * (1 - i / p.trail.length), 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    const pulse = 1 + Math.sin(state.time * 13) * 0.05;
    const glow = ctx.createRadialGradient(p.x, p.y, 2, p.x, p.y, 38);
    glow.addColorStop(0, p.dash > 0 ? '#ffffff' : '#bfffff');
    glow.addColorStop(0.45, '#37f8ff');
    glow.addColorStop(1, 'rgba(55,248,255,0)');
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(p.x, p.y, 38 * pulse, 0, TAU);
    ctx.fill();

    ctx.fillStyle = '#faffff';
    ctx.strokeStyle = p.dash > 0 ? '#ffe16b' : '#37f8ff';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.r * pulse, 0, TAU);
    ctx.fill();
    ctx.stroke();

    if (p.dashCool <= 0 && state.energy >= cfg().energyCost) {
      ctx.globalAlpha = 0.55 + Math.sin(state.time * 10) * 0.22;
      ctx.strokeStyle = '#ffe16b';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(p.x, p.y, 24 + Math.sin(state.time * 6) * 3, 0, TAU);
      ctx.stroke();
    }
    if (p.dash > 0 && currentMode === 'easy') {
      ctx.globalAlpha = 0.18;
      ctx.strokeStyle = '#37f8ff';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(p.x, p.y, cfg().killRadius, 0, TAU);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawEnemies() {
    ctx.save();
    for (const e of state.enemies) {
      ctx.save();
      ctx.translate(e.x, e.y);
      ctx.rotate(e.rot);
      const hot = 0.65 + Math.sin((state.time - e.born) * 11) * 0.22;
      ctx.fillStyle = `hsla(${e.hue}, 100%, ${58 + hot * 12}%, .92)`;
      ctx.strokeStyle = '#ffd1fb';
      ctx.lineWidth = 2;
      ctx.shadowColor = '#ff3df2';
      ctx.shadowBlur = 18;
      ctx.beginPath();
      for (let i = 0; i < 3; i++) {
        const a = -Math.PI / 2 + i * TAU / 3;
        const rr = e.r * (i === 0 ? 1.25 : 1);
        ctx.lineTo(Math.cos(a) * rr, Math.sin(a) * rr);
      }
      ctx.closePath();
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.stroke();
      ctx.restore();
    }
    ctx.restore();
  }

  function drawGems() {
    ctx.save();
    for (const g of state.gems) {
      const pulse = 1 + Math.sin(g.pulse) * 0.18;
      ctx.globalAlpha = clamp(g.life, 0, 1);
      ctx.shadowColor = '#37f8ff';
      ctx.shadowBlur = 22;
      ctx.fillStyle = '#37f8ff';
      ctx.beginPath();
      ctx.arc(g.x, g.y, g.r * pulse, 0, TAU);
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(g.x, g.y, g.r * 1.9 * pulse, 0, TAU);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawEffects() {
    ctx.save();
    ctx.lineCap = 'round';
    for (const r of state.rings) {
      const a = clamp(r.life / r.maxLife, 0, 1);
      ctx.globalAlpha = a;
      ctx.strokeStyle = r.color;
      ctx.lineWidth = 5 * a;
      ctx.shadowColor = r.color;
      ctx.shadowBlur = 20;
      ctx.beginPath();
      ctx.arc(r.x, r.y, r.r, 0, TAU);
      ctx.stroke();
    }
    for (const p of state.particles) {
      const a = clamp(p.life / p.maxLife, 0, 1);
      ctx.globalAlpha = a;
      ctx.fillStyle = p.color;
      ctx.shadowColor = p.color;
      ctx.shadowBlur = 12;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size * a, 0, TAU);
      ctx.fill();
    }
    ctx.shadowBlur = 0;
    ctx.font = '900 24px ui-rounded, system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const t of state.texts) {
      const a = clamp(t.life / t.maxLife, 0, 1);
      ctx.globalAlpha = a;
      ctx.fillStyle = t.color;
      ctx.fillText(t.text, t.x, t.y);
    }
    ctx.restore();
  }

  function drawAim() {
    if (!state.playing || !pointer.active) return;
    const p = state.player;
    ctx.save();
    ctx.globalAlpha = 0.32;
    ctx.strokeStyle = state.energy >= cfg().energyCost ? '#37f8ff' : '#ffffff';
    ctx.setLineDash([8, 10]);
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(p.x, p.y);
    ctx.lineTo(pointer.x, pointer.y);
    ctx.stroke();
    ctx.restore();
  }

  function tick(now) {
    const dt = Math.min(0.034, (now - last) / 1000 || 0);
    last = now;
    update(dt);
    draw();
    raf = requestAnimationFrame(tick);
  }

  function setPointer(event) {
    pointer.active = true;
    const p = toCanvasPoint(event);
    pointer.x = p.x;
    pointer.y = p.y;
  }

  canvas.addEventListener('mousemove', setPointer);
  canvas.addEventListener('mousedown', event => {
    setPointer(event);
    pointer.down = true;
    burst();
  });
  window.addEventListener('mouseup', () => { pointer.down = false; });
  canvas.addEventListener('touchstart', event => {
    event.preventDefault();
    setPointer(event);
    pointer.down = true;
    burst();
  }, { passive: false });
  canvas.addEventListener('touchmove', event => {
    event.preventDefault();
    setPointer(event);
  }, { passive: false });
  canvas.addEventListener('touchend', () => { pointer.down = false; });

  window.addEventListener('keydown', event => {
    if (event.code === 'Space' || event.code === 'Enter') {
      event.preventDefault();
      if (!state || !state.playing) startGame();
      else burst();
    }
    keys.add(event.code);
  });
  window.addEventListener('keyup', event => keys.delete(event.code));
  startBtn.addEventListener('click', startGame);
  modeBtns.forEach(btn => btn.addEventListener('click', () => setMode(btn.dataset.mode)));
  guideToggle.addEventListener('click', () => {
    guide.hidden = !guide.hidden;
    guideToggle.textContent = guide.hidden ? '攻略法を見る' : '攻略法を閉じる';
  });
  window.addEventListener('resize', resize);

  resize();
  refreshModeUI();
  reset();
  state.playing = false;
  overlay.classList.remove('hidden');
  cancelAnimationFrame(raf);
  raf = requestAnimationFrame(tick);
})();
