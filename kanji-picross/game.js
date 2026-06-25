(() => {
  'use strict';

  const PUZZLES = [
    {
      kanji: '山', reading: 'やま', meaning: '山 / mountain',
      grid: [
        '0000100000',
        '0000100000',
        '0000100000',
        '0010100100',
        '0010100100',
        '0010100100',
        '0010100100',
        '0011111100',
        '0000000000',
        '0000000000'
      ]
    },
    {
      kanji: '川', reading: 'かわ', meaning: '川 / river',
      grid: [
        '0100100010',
        '0100100010',
        '0100100010',
        '0100100010',
        '0100100010',
        '0100100010',
        '0100100010',
        '0100100010',
        '0100100010',
        '0000000000'
      ]
    },
    {
      kanji: '木', reading: 'き', meaning: '木 / tree',
      grid: [
        '0000100000',
        '0000100000',
        '0000100000',
        '0011111100',
        '0001110000',
        '0010101000',
        '0100100100',
        '1000100010',
        '0000100000',
        '0000100000'
      ]
    },
    {
      kanji: '日', reading: 'ひ / にち', meaning: '日 / sun, day',
      grid: [
        '0011111100',
        '0010000100',
        '0010000100',
        '0010000100',
        '0011111100',
        '0010000100',
        '0010000100',
        '0010000100',
        '0011111100',
        '0000000000'
      ]
    },
    {
      kanji: '月', reading: 'つき', meaning: '月 / moon',
      grid: [
        '0011111000',
        '0010001000',
        '0010001000',
        '0011111000',
        '0010001000',
        '0010001000',
        '0011111000',
        '0010001000',
        '0100001000',
        '1000001000'
      ]
    },
    {
      kanji: '火', reading: 'ひ', meaning: '火 / fire',
      grid: [
        '0000100000',
        '0100100100',
        '0010101000',
        '0001110000',
        '0001110000',
        '0010101000',
        '0100100100',
        '1000100010',
        '0000100000',
        '0000000000'
      ]
    }
  ];

  const UNKNOWN = 0;
  const DUG = 1;
  const MARKED = 2;
  const MISS = 3;

  const gridRoot = document.getElementById('gridRoot');
  const puzzleName = document.getElementById('puzzleName');
  const progressEl = document.getElementById('progress');
  const mistakesEl = document.getElementById('mistakes');
  const timerEl = document.getElementById('timer');
  const subtitle = document.getElementById('subtitle');
  const digMode = document.getElementById('digMode');
  const markMode = document.getElementById('markMode');
  const hintBtn = document.getElementById('hintBtn');
  const prevBtn = document.getElementById('prevBtn');
  const nextBtn = document.getElementById('nextBtn');
  const resetBtn = document.getElementById('resetBtn');
  const overlay = document.getElementById('overlay');
  const bigKanji = document.getElementById('bigKanji');
  const clearTitle = document.getElementById('clearTitle');
  const clearText = document.getElementById('clearText');
  const continueBtn = document.getElementById('continueBtn');

  let puzzleIndex = Number(localStorage.getItem('kanji-picross-index') || 0) % PUZZLES.length;
  let puzzle;
  let size;
  let solution;
  let cells;
  let mode = 'dig';
  let mistakes = 0;
  let startedAt = Date.now();
  let solved = false;
  let tickId = 0;

  function parsePuzzle(p) {
    const rows = p.grid.map(row => row.trim());
    const n = rows.length;
    if (!rows.every(row => row.length === n)) {
      throw new Error(`Puzzle ${p.kanji} must be square`);
    }
    return rows.map(row => [...row].map(ch => ch === '1'));
  }

  function clueForLine(values) {
    const clues = [];
    let run = 0;
    for (const v of values) {
      if (v) run++;
      else if (run) { clues.push(run); run = 0; }
    }
    if (run) clues.push(run);
    return clues.length ? clues : [0];
  }

  function rowClues() {
    return solution.map(row => clueForLine(row));
  }

  function colClues() {
    return Array.from({ length: size }, (_, x) => clueForLine(solution.map(row => row[x])));
  }

  function resetPuzzle(index = puzzleIndex) {
    puzzleIndex = (index + PUZZLES.length) % PUZZLES.length;
    localStorage.setItem('kanji-picross-index', String(puzzleIndex));
    puzzle = PUZZLES[puzzleIndex];
    solution = parsePuzzle(puzzle);
    size = solution.length;
    cells = Array.from({ length: size }, () => Array(size).fill(UNKNOWN));
    mistakes = 0;
    solved = false;
    startedAt = Date.now();
    overlay.classList.add('hidden');
    buildBoard();
    updateUi();
    setMode(mode);
  }

  function buildBoard() {
    gridRoot.innerHTML = '';
    gridRoot.style.setProperty('--size', size);

    const corner = document.createElement('div');
    corner.className = 'corner';
    corner.textContent = '石板';
    gridRoot.appendChild(corner);

    for (const clue of colClues()) {
      const el = document.createElement('div');
      el.className = 'col-clue';
      clue.forEach(n => {
        const span = document.createElement('span');
        span.textContent = n;
        el.appendChild(span);
      });
      gridRoot.appendChild(el);
    }

    const rows = rowClues();
    for (let y = 0; y < size; y++) {
      const clueEl = document.createElement('div');
      clueEl.className = 'row-clue';
      rows[y].forEach(n => {
        const span = document.createElement('span');
        span.textContent = n;
        clueEl.appendChild(span);
      });
      gridRoot.appendChild(clueEl);

      for (let x = 0; x < size; x++) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'cell';
        btn.dataset.x = x;
        btn.dataset.y = y;
        btn.setAttribute('aria-label', `${x + 1}列 ${y + 1}行`);
        btn.addEventListener('click', event => {
          event.preventDefault();
          actOnCell(x, y, mode);
        });
        btn.addEventListener('contextmenu', event => {
          event.preventDefault();
          actOnCell(x, y, 'mark');
        });
        gridRoot.appendChild(btn);
      }
    }
  }

  function buttonAt(x, y) {
    return gridRoot.querySelector(`.cell[data-x="${x}"][data-y="${y}"]`);
  }

  function actOnCell(x, y, action) {
    if (solved) return;
    const current = cells[y][x];
    if (action === 'mark') {
      if (current === UNKNOWN) cells[y][x] = MARKED;
      else if (current === MARKED) cells[y][x] = UNKNOWN;
      renderCell(x, y);
      return;
    }

    if (current === DUG || current === MISS) return;
    if (solution[y][x]) {
      cells[y][x] = DUG;
    } else {
      cells[y][x] = MISS;
      mistakes++;
    }
    renderCell(x, y);
    updateUi();
    updateClueCompletion();
    checkSolved();
  }

  function renderCell(x, y) {
    const btn = buttonAt(x, y);
    if (!btn) return;
    btn.classList.remove('dug', 'marked', 'miss', 'hint');
    const state = cells[y][x];
    if (state === DUG) btn.classList.add('dug');
    else if (state === MARKED) btn.classList.add('marked');
    else if (state === MISS) btn.classList.add('miss');
  }

  function updateClueCompletion() {
    const rowEls = [...gridRoot.querySelectorAll('.row-clue')];
    const colEls = [...gridRoot.querySelectorAll('.col-clue')];

    for (let y = 0; y < size; y++) {
      const done = solution[y].every((v, x) => !v || cells[y][x] === DUG);
      rowEls[y]?.querySelectorAll('span').forEach(s => s.classList.toggle('done', done));
    }
    for (let x = 0; x < size; x++) {
      const done = solution.every((row, y) => !row[x] || cells[y][x] === DUG);
      colEls[x]?.querySelectorAll('span').forEach(s => s.classList.toggle('done', done));
    }
  }

  function countFilled() {
    return solution.flat().filter(Boolean).length;
  }

  function countDug() {
    let n = 0;
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        if (solution[y][x] && cells[y][x] === DUG) n++;
      }
    }
    return n;
  }

  function updateUi() {
    const dug = countDug();
    const total = countFilled();
    puzzleName.textContent = `${puzzle.kanji} (${puzzleIndex + 1}/${PUZZLES.length})`;
    subtitle.textContent = `読み: ${puzzle.reading} / ${puzzle.meaning}`;
    progressEl.textContent = `${Math.floor(dug / total * 100)}%`;
    mistakesEl.textContent = String(mistakes);
    updateTimer();
  }

  function updateTimer() {
    const sec = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
    const m = String(Math.floor(sec / 60)).padStart(2, '0');
    const s = String(sec % 60).padStart(2, '0');
    timerEl.textContent = `${m}:${s}`;
  }

  function checkSolved() {
    if (countDug() !== countFilled()) return;
    solved = true;
    const elapsed = timerEl.textContent;
    bigKanji.textContent = puzzle.kanji;
    clearTitle.textContent = '発掘完了';
    clearText.innerHTML = `${puzzle.kanji}（${puzzle.reading}）を発掘しました。<br>ミス ${mistakes} / 時間 ${elapsed}`;
    overlay.classList.remove('hidden');
  }

  function setMode(nextMode) {
    mode = nextMode;
    digMode.classList.toggle('active', mode === 'dig');
    markMode.classList.toggle('active', mode === 'mark');
  }

  function revealHint() {
    if (solved) return;
    const candidates = [];
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        if (solution[y][x] && cells[y][x] !== DUG) candidates.push([x, y]);
      }
    }
    if (!candidates.length) return;
    const [x, y] = candidates[Math.floor(Math.random() * candidates.length)];
    cells[y][x] = DUG;
    renderCell(x, y);
    const btn = buttonAt(x, y);
    btn?.classList.add('hint');
    setTimeout(() => btn?.classList.remove('hint'), 700);
    updateUi();
    updateClueCompletion();
    checkSolved();
  }

  digMode.addEventListener('click', () => setMode('dig'));
  markMode.addEventListener('click', () => setMode('mark'));
  hintBtn.addEventListener('click', revealHint);
  prevBtn.addEventListener('click', () => resetPuzzle(puzzleIndex - 1));
  nextBtn.addEventListener('click', () => resetPuzzle(puzzleIndex + 1));
  resetBtn.addEventListener('click', () => resetPuzzle(puzzleIndex));
  continueBtn.addEventListener('click', () => resetPuzzle(puzzleIndex + 1));

  window.addEventListener('keydown', event => {
    if (event.key === '1' || event.key.toLowerCase() === 'd') setMode('dig');
    if (event.key === '2' || event.key.toLowerCase() === 'm') setMode('mark');
    if (event.key.toLowerCase() === 'h') revealHint();
    if (event.key.toLowerCase() === 'r') resetPuzzle(puzzleIndex);
  });

  clearInterval(tickId);
  tickId = setInterval(() => { if (!solved) updateTimer(); }, 1000);
  resetPuzzle(puzzleIndex);
})();
