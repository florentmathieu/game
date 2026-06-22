// Génère des missions, les joue en IA-vs-IA (les deux camps), calibre la difficulté
// pour un taux de victoire joueur dans [60%,80%], et enregistre les bonnes dans missions/.
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const { loadEngine } = require("./engine.js");

const ROOT = path.join(__dirname, "..");
const MDIR = path.join(ROOT, "missions");
const LOG = path.join(__dirname, "balance.log");
const T = loadEngine();

// ---- utilitaires ----
const ri = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
const rf = (a, b) => a + Math.random() * (b - a);
const choice = (a) => a[Math.floor(Math.random() * a.length)];
const now = () => Date.now();
function log(s){ const line = `[${new Date().toISOString()}] ${s}`; console.log(line); try{ fs.appendFileSync(LOG, line + "\n"); }catch(e){} }

// ---- IA générique (sync), miroir d'enemyAct, pour n'importe quelle équipe ----
function randStrat(){
  return { off: rf(0.8,1.3), threat: rf(0.4,1.0), near: rf(1.1,2.0), height: rf(0.2,0.9), cover: rf(0.02,0.10), aggr: rf(0,1) };
}
function visOf(e){ return e.team === "player" ? T.visible : T.enemyVisible; }
function genericGrenade(e){
  const cr = e.weapons.cracker, src = T.offsetToCube(e.col, e.row), vis = visOf(e);
  let best = null, bs = 0;
  for (let r = 0; r < T.ROWS; r++) for (let c = 0; c < T.COLS; c++){
    if (T.cubeDist(src, T.offsetToCube(c, r)) > cr.range || !vis.has(T.key(c, r))) continue;
    const ic = T.offsetToCube(c, r); let pl = 0, al = 0, cov = false;
    for (const u of T.units){ if (u.hp <= 0) continue;
      if (T.cubeDist(ic, T.offsetToCube(u.col, u.row)) <= cr.radius){
        if (u.team !== e.team){ pl++; if (T.coverPenalty(u, e.col, e.row) >= 20) cov = true; } else al++;
      } }
    const score = pl - 1.5*al;
    if (pl >= 1 && (score >= 2 || (score >= 1 && cov)) && score > bs){ bs = score; best = { col:c, row:r }; }
  }
  return best;
}
function aiAct(e, W){
  if (e.hp <= 0 || T.gameOver) return;
  e.overwatch = false;
  // pod ennemi pas encore conscient du joueur : il garde sa zone, ne fonce pas
  if (e.team === "enemy" && !T.enemyActive(e)){
    if (e.range > 1 && (e.clip === undefined || e.ammo > 0)) e.overwatch = true;
    e.ap = 0; return;
  }
  const opp = e.team === "player" ? "enemy" : "player";
  const vis = visOf(e);
  // l'ennemi ne perçoit le joueur furtif (assassin) que de face -> enemyCanSee
  const seen = e.team === "enemy"
    ? T.units.filter(u => u.team === "player" && u.hp > 0 && T.enemyCanSee(u))
    : T.units.filter(u => u.team === opp && u.hp > 0 && vis.has(T.key(u.col, u.row)));

  if (e.weapons.cracker && e.crackers > 0 && e.ap > 0 && seen.length){
    const g = genericGrenade(e); if (g){ T.resolveThrow(e, g.col, g.row); return; }
  }
  // pour le déplacement : cibles vues, sinon on avance vers l'adversaire le plus proche (toutes positions)
  const targets = seen.length ? seen : T.units.filter(u => u.team === opp && u.hp > 0);
  if (!targets.length){ e.ap = 0; return; }

  const allies = T.units.filter(o => o !== e && o.team === e.team && o.hp > 0);
  const r = T.computeReach(e);
  const cands = [[e.col, e.row, 0]];
  for (const k in r.dist){ const [c, row] = k.split(",").map(Number); cands.push([c, row, r.dist[k]]); }

  let best = [e.col, e.row, 0], bestScore = -Infinity;
  for (const [c, row, cost] of cands){
    let offense = 0, threat = 0, nearest = Infinity, coverv = 0;
    for (const p of targets){
      offense = Math.max(offense, T.shotChanceFrom(c, row, e, p.col, p.row));
      threat  = Math.max(threat,  T.shotChanceFrom(p.col, p.row, p, c, row));
      nearest = Math.min(nearest, T.cubeDist(T.offsetToCube(c, row), T.offsetToCube(p.col, p.row)));
      coverv  = Math.max(coverv,  T.coverPenalty({ col:c, row }, p.col, p.row));
    }
    if (T.apForMove(e, cost) > 1 || (e.wtype === "ranged" && e.clip !== undefined && e.ammo <= 0)) offense = 0;
    let clump = 0;
    for (const o of allies) if (T.cubeDist(T.offsetToCube(c, row), T.offsetToCube(o.col, o.row)) <= 1) clump += 6;
    const elev = T.tiles[row][c].elev;
    const score = W.off*offense - W.threat*threat - W.near*nearest + W.height*elev + W.cover*coverv - clump;
    if (score > bestScore){ bestScore = score; best = [c, row, cost]; }
  }
  if (best[0] !== e.col || best[1] !== e.row){
    const path = T.buildPath(r.prev, best[0], best[1]);
    T.spendMove(e, best[2]); T.executeMove(e, path);
    if (e.hp <= 0 || T.gameOver) return;
  }
  if (e.wtype === "ranged" && e.clip !== undefined && e.ammo <= 0 && e.ap > 0){
    if (T.units.some(p => p.team === opp && p.hp > 0 && visOf(e).has(T.key(p.col, p.row)) && T.hexDistUnits(e, p) <= e.range && T.lineOfFire(e, p))){
      e.ap -= 1; e.ammo = e.clip;
    }
  }
  const t = T.bestTarget(e);
  if (t){ T.doAttack(e, t); return; }
  if (e.shieldBlock > 0 && e.ap > 0 && !e.bracing && seen.some(p => T.shotChanceFrom(p.col, p.row, p, e.col, e.row) > 0)){
    e.ap -= 1; e.bracing = true;
  }
  if (e.range > 1 && (e.clip === undefined || e.ammo > 0) && seen.length) e.overwatch = true;
  const np = T.nearestOpposing(e); if (np) T.faceTowards(e, np.col, np.row);
  e.ap = 0;
}

// ---- une partie complète (renvoie "player"/"enemy") ----
function playGame(mission, cap = 30){
  T.applyMission(mission);
  const sp = randStrat(), se = randStrat();
  let turn = 1;
  while (!T.gameOver && turn <= cap){
    for (const u of T.units.filter(x => x.team === "player")){ if (T.gameOver) break; if (u.hp > 0) aiAct(u, sp); }
    if (T.gameOver) break;
    for (const u of T.units.filter(x => x.team === "enemy")){ if (T.gameOver) break; if (u.hp > 0) aiAct(u, se); }
    if (T.gameOver) break;
    for (const u of T.units){ u.reacted = false; u.ap = T.AP_MAX; u.freeAvail = true; u.bracing = false; }
    for (const u of T.units) if (u.team === "player") u.overwatch = false;
    T.recomputeVision();
    turn++;
  }
  if (T.gameOver === "win") return "player";
  if (T.gameOver === "lose") return "enemy";
  const ph = T.units.filter(u => u.team === "player").reduce((s, u) => s + Math.max(0, u.hp), 0);
  const eh = T.units.filter(u => u.team === "enemy").reduce((s, u) => s + Math.max(0, u.hp), 0);
  return ph >= eh ? "player" : "enemy";   // dépassement : départage aux PV restants
}
function winrate(mission, games){
  let w = 0; for (let i = 0; i < games; i++) if (playGame(mission) === "player") w++;
  return w / games;
}

// ---- génération de carte (relief + topologie) ----
function component(sc, sr){
  const seen = new Set([T.key(sc, sr)]); const st = [[sc, sr]];
  while (st.length){ const [c, r] = st.pop();
    for (const [nc, nr] of T.neighbors(c, r)){
      if (T.tiles[nr][nc].obstacle) continue;
      if (T.moveCost(T.tiles[r][c], T.tiles[nr][nc]) === null) continue;
      const k = T.key(nc, nr); if (!seen.has(k)){ seen.add(k); st.push([nc, nr]); }
    }
  }
  return seen;
}
function largestComponent(){
  const visited = new Set(); let best = new Set();
  for (let r = 0; r < T.ROWS; r++) for (let c = 0; c < T.COLS; c++){
    if (T.tiles[r][c].obstacle || visited.has(T.key(c, r))) continue;
    const comp = component(c, r);
    for (const k of comp) visited.add(k);
    if (comp.size > best.size) best = comp;
  }
  return best;
}
function setRock(c, r){ const t = T.tiles[r] && T.tiles[r][c]; if (t){ t.obstacle = true; t.cover = "full"; } }

// pose des rochers/murets « logiques » MAIS bien répartis : forteresse légère sur les
// hauteurs, chicane éventuelle, puis couvert distribué case-grille sur toute la carte.
function topology(format, axis){
  const C = T.COLS, R = T.ROWS;
  let maxE = 0; for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) maxE = Math.max(maxE, T.tiles[r][c].elev);
  const high = [];
  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (T.tiles[r][c].elev >= maxE - 1) high.push([c, r]);

  let count = 0; const cap = Math.round(C * R * 0.09);          // densité de rochers plafonnée (~9%)
  const tryRock = (c, r) => { if (c>=0&&c<C&&r>=0&&r<R&&!T.tiles[r][c].obstacle && count<cap){ setRock(c, r); count++; return true; } return false; };

  // forteresse légère : quelques rochers en contrebas des hauteurs (avec ouvertures)
  if (high.length && maxE >= 2){
    for (const [c, r] of high) for (const [nc, nr] of T.neighbors(c, r)){
      const t = T.tiles[nr][nc];
      if (t.elev < T.tiles[r][c].elev && Math.random() < 0.3) tryRock(nc, nr);
    }
  }
  // chicane / chokepoint pour le format « parcours »
  if (format === "path"){
    const mid = Math.floor(R / 2), gap = ri(2, C - 3);
    for (let c = 0; c < C; c++) if (Math.abs(c - gap) > 1 && Math.random() < 0.7) tryRock(c, mid);
  }
  // couvert RÉPARTI : remplissage cellule par cellule, en tourniquet, jusqu'au plafond
  const gx = 4, gy = 4, cw = C / gx, ch = R / gy;
  const cells = []; for (let ix = 0; ix < gx; ix++) for (let iy = 0; iy < gy; iy++) cells.push([ix, iy]);
  for (let round = 0; round < 3 && count < cap; round++){
    for (const [ix, iy] of cells){
      if (count >= cap) break;
      if (round > 0 && Math.random() < 0.4) continue;   // densité décroissante après le 1er passage
      const c = Math.min(C - 1, Math.floor(ix * cw + Math.random() * cw));
      const r = Math.min(R - 1, Math.floor(iy * ch + Math.random() * ch));
      tryRock(c, r);
    }
  }
  const walls = new Set();
  // MURETS DE PROGRESSION : lignes grossièrement perpendiculaires à l'avancée du joueur,
  // posées sur l'arête tournée vers l'ennemi -> couvert frontal pour avancer (avec ouvertures).
  // h : avancée +c, arête est (c,c+1) ; v : avancée -r (vers le haut), arête nord (r,r-1).
  const bands = [0.30, 0.45, 0.60, 0.75];
  for (const f of bands){
    if (axis === "h"){
      const cBand = Math.min(C - 2, Math.max(1, Math.round(f * (C - 1))));
      for (let r = 0; r < R; r++){
        if (Math.random() < 0.4) continue;                       // ouvertures dans la ligne
        const c = Math.min(C - 2, Math.max(1, cBand + ri(-1, 1)));
        if (!T.tiles[r][c].obstacle && !T.tiles[r][c + 1].obstacle && T.tiles[r][c].elev <= T.tiles[r][c + 1].elev)
          walls.add(T.wallKey(c, r, c + 1, r));
      }
    } else {
      const rBand = Math.min(R - 1, Math.max(1, Math.round(f * (R - 1))));
      for (let c = 0; c < C; c++){
        if (Math.random() < 0.4) continue;
        const r = Math.min(R - 1, Math.max(1, rBand + ri(-1, 1)));
        if (!T.tiles[r][c].obstacle && !T.tiles[r - 1][c].obstacle && T.tiles[r][c].elev <= T.tiles[r - 1][c].elev)
          walls.add(T.wallKey(c, r, c, r - 1));
      }
    }
  }
  // quelques murets épars en complément
  for (let s = 0; s < ri(3, 6); s++){
    const cc = ri(1, C - 2), rr = ri(1, R - 2);
    const [dc, dr] = choice(T.NEI[rr & 1]); const nc = cc + dc, nr = rr + dr;
    if (nc < 0 || nc >= C || nr < 0 || nr >= R) continue;
    if (!T.tiles[rr][cc].obstacle && !T.tiles[nr][nc].obstacle) walls.add(T.wallKey(cc, rr, nc, nr));
  }
  T.walls = walls;
}

// choisit n cases dans le composant, scorées par `pref`, avec espacement minimal
function pickSpots(comp, pref, n, occupied, minSpace){
  const tiles = [...comp].map(k => k.split(",").map(Number)).filter(([c, r]) => !occupied.has(T.key(c, r)));
  tiles.sort((a, b) => pref(b[0], b[1]) - pref(a[0], a[1]));
  const out = [];
  for (const [c, r] of tiles){
    if (out.every(([oc, orr]) => T.cubeDist(T.offsetToCube(c, r), T.offsetToCube(oc, orr)) >= minSpace)){
      out.push([c, r]); if (out.length >= n) break;
    }
  }
  while (out.length < n && tiles.length){ const [c, r] = tiles[out.length % tiles.length]; out.push([c, r]); } // secours
  return out;
}

function makeMap(infil){
  // l'infiltration demande de la profondeur d'approche -> formats allongés
  const format = infil ? choice(["vertical", "horizontal"]) : choice(["vertical", "horizontal", "square", "path"]);
  let cols, rows;
  if (format === "vertical"){ cols = ri(12, 16); rows = ri(20, 26); }
  else if (format === "horizontal"){ cols = ri(22, 28); rows = ri(12, 16); }
  else { cols = ri(16, 20); rows = ri(16, 20); }
  // sens de progression imposé : gauche->droite (h) ou bas->haut (v)
  const axis = format === "horizontal" ? "h" : format === "vertical" ? "v" : choice(["h", "v"]);
  T.resizeGrid(cols, rows); T.generateElevation(); topology(format, axis);
  const comp = largestComponent();
  if (comp.size < cols * rows * 0.35) return null;   // carte trop morcelée
  const C = T.COLS, R = T.ROWS;
  // h : joueurs à gauche (c petit) -> ennemis à droite ; v : joueurs en bas (r grand) -> ennemis en haut
  const playerPref = axis === "h" ? (c, r) => (C-1-c) - T.tiles[r][c].elev * 0.5
                                  : (c, r) => r - T.tiles[r][c].elev * 0.5;
  const enemyPref  = axis === "h" ? (c, r) => c + T.tiles[r][c].elev * 1.2
                                  : (c, r) => (R-1-r) + T.tiles[r][c].elev * 1.2;
  // angle (pixel) de l'avancée joueur -> ennemi : est (h) ou haut (v). Sert à orienter les dormants.
  const advAngle = axis === "h" ? 0 : -Math.PI / 2;
  return { format, axis, cols, rows, comp, playerPref, enemyPref, advAngle };
}
const snapHex = (a) => Math.round(a / (Math.PI / 3)) * (Math.PI / 3);

// place les ennemis en DEUX pods séparés (2 à 4 unités chacun), regroupés autour de deux
// points d'ancrage éloignés l'un de l'autre (évite un seul gros paquet).
function pickPods(map, n, occupied){
  const comp = [...map.comp].map(k => k.split(",").map(Number)).filter(([c, r]) => !occupied.has(T.key(c, r)));
  if (comp.length < n) return null;
  const cb = (c, r) => T.offsetToCube(c, r);
  const C = T.COLS, R = T.ROWS;
  // zone ennemie définie par la POSITION (moitié opposée au joueur) -> les deux pods restent loin
  const onSide = map.axis === "h" ? ([c]) => c >= C * 0.55 : ([, r]) => r <= R * 0.45;
  let zone = comp.filter(onSide);
  const sorted = comp.slice().sort((a, b) => map.enemyPref(b[0], b[1]) - map.enemyPref(a[0], a[1]));
  if (zone.length < n) zone = sorted.slice(0, Math.max(n, Math.ceil(comp.length * 0.4)));
  zone.sort((a, b) => map.enemyPref(b[0], b[1]) - map.enemyPref(a[0], a[1]));
  const a1 = zone[0];
  // 2e ancre : DANS la zone ennemie, la plus éloignée possible de la 1re (pods séparés latéralement)
  let a2 = zone[1] || a1, bs = -Infinity;
  for (const [c, r] of zone){
    const d = T.cubeDist(cb(c, r), cb(a1[0], a1[1]));
    if (d > bs){ bs = d; a2 = [c, r]; }
  }
  const s1 = Math.floor(n / 2), s2 = n - s1;          // 4->2,2 5->2,3 6->3,3 7->3,4 (chacun dans 2..4)
  const taken = new Set(occupied), out = [];
  for (const [anchor, size] of [[a1, s1], [a2, s2]]){
    const near = comp.filter(([c, r]) => !taken.has(T.key(c, r)))
      .map(([c, r]) => [c, r, T.cubeDist(cb(c, r), cb(anchor[0], anchor[1]))])
      .sort((p, q) => p[2] - q[2] || (map.enemyPref(q[0], q[1]) - map.enemyPref(p[0], p[1])));
    let cnt = 0;
    for (const [c, r] of near){
      out.push([c, r]); taken.add(T.key(c, r));
      if (++cnt >= size) break;
    }
  }
  return out.length === n ? out : null;
}

const ENEMY_POOL = ["Garde", "Archer", "Brute"];
function enemyComposition(n){
  // au moins un tireur souvent, le reste mêlée variée
  const comp = [];
  if (Math.random() < 0.8) comp.push("Archer");
  while (comp.length < n) comp.push(choice(ENEMY_POOL));
  return comp.slice(0, n);
}

function buildMission(map, name, nEnemies, buff, infil){
  const occupied = new Set();
  const pSpots = pickSpots(map.comp, map.playerPref, 3, occupied, 2);
  for (const [c, r] of pSpots) occupied.add(T.key(c, r));
  const eSpots = pickPods(map, nEnemies, occupied);
  if (!eSpots) return null;
  const players = [["Stiff", "player"], ["Merry", "player"], ["Gizzard", "player"]]
    .map((u, i) => ({ type:u[0], team:"player", col:pSpots[i][0], row:pSpots[i][1] }));
  const comp = enemyComposition(nEnemies);
  const s1 = Math.floor(nEnemies / 2);   // pickPods range les positions pod0 puis pod1
  const enemies = eSpots.map((s, i) => {
    const e = { type:comp[i], team:"enemy", col:s[0], row:s[1], hp:buff.hp, aim:buff.aim, pod: i < s1 ? 0 : 1 };
    if (infil){ e.asleep = true; e.facing = snapHex(map.advAngle + choice([-1, 0, 0, 1]) * (Math.PI / 3)); }  // dormants, tournés ~vers l'avant (dos au joueur)
    return e;
  });
  T.placeUnitsFrom([...players, ...enemies].map(u => ({ ...u })));
  return T.serializeMission(name);
}

// ---- calibration : viser 60–80% de victoires joueur ----
const LO = 0.60, HI = 0.80, SCREEN = 14, CONFIRM = 40;
function calibrate(map, infil){
  let n = ri(4, 7), buff = { hp: 0, aim: 0 };      // départ varié pour obtenir 4..7 ennemis
  for (let it = 0; it < 9; it++){
    const mission = buildMission(map, "tmp", n, buff, infil);
    if (!mission){ if (n > 4){ n--; continue; } return null; }
    const wr = winrate(mission, SCREEN);
    if (wr >= LO && wr <= HI){
      const wr2 = winrate(mission, CONFIRM);          // confirmation sur plus de parties
      if (wr2 >= LO && wr2 <= HI) return { mission, wr: wr2, n, buff: { ...buff } };
    }
    if (wr > HI){                                     // trop facile -> durcir (renforcer un peu avant d'ajouter)
      if (buff.aim < 12) buff.aim += 4;
      else if (buff.hp < 4) buff.hp += 2;
      else if (n < 7){ n++; buff = { hp:0, aim:0 }; }
      else break;
    } else if (wr < LO){                              // trop dur -> affaiblir un peu avant de retirer un ennemi
      if (buff.aim > -8) buff.aim -= 4;
      else if (buff.hp > -2) buff.hp -= 2;
      else if (n > 4){ n--; buff = { hp:0, aim:0 }; }
      else break;
    }
  }
  return null;
}

// ---- persistance + git ----
function readList(){ try{ return JSON.parse(fs.readFileSync(path.join(MDIR, "list.json"), "utf8")) || []; }catch(e){ return []; } }
function nextIndex(list){
  let mx = 0; for (const it of list){ const m = /mission-(\d+)\.json/.exec(it.file || ""); if (m) mx = Math.max(mx, +m[1]); }
  return mx + 1;
}
function saveMission(mission, wr, meta){
  const list = readList();
  const idx = nextIndex(list);
  const file = `mission-${idx}.json`;
  mission.name = (meta.infil ? "Infiltration " : "Mission ") + idx;
  mission.meta = { winrate: Math.round(wr * 100), ...meta };
  fs.writeFileSync(path.join(MDIR, file), JSON.stringify(mission, null, 1));
  list.push({ file, name: mission.name });
  fs.writeFileSync(path.join(MDIR, "list.json"), JSON.stringify(list, null, 1));
  try{
    execSync(`git add missions/`, { cwd: ROOT });
    execSync(`git commit -q -m "${mission.name} (auto, ${Math.round(wr*100)}% victoire joueur, ${meta.infil?'infiltration, ':''}${meta.format}, ${meta.cols}x${meta.rows}, ${meta.n} ennemis)" ` +
      `-m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" -m "Claude-Session: https://claude.ai/code/session_011W5fGsCJX3Rz6FN17p17HS"`, { cwd: ROOT });
    for (let a = 0; a < 4; a++){ try{ execSync(`git push -u origin claude/intelligent-hypatia-nojupi`, { cwd: ROOT, stdio:"ignore" }); break; }
      catch(e){ execSync(`sleep ${2 << a}`); } }
  }catch(e){ log("git: " + e.message); }
  return file;
}

// ---- boucle principale ----
function main(){
  const minutes = +(process.env.BAL_MINUTES || 150);
  const maxKeep = +(process.env.BAL_MAX || 14);
  const infilTarget = +(process.env.BAL_INFIL || 6);   // nombre de missions d'infiltration visées
  const deadline = now() + minutes * 60 * 1000;
  let tested = 0, kept = 0, keptInfil = 0;
  const t0 = now();
  log(`=== démarrage : budget ${minutes} min, max ${maxKeep} missions (dont ~${infilTarget} infiltration) ===`);
  while (now() < deadline && kept < maxKeep){
    const infil = keptInfil < infilTarget;             // on enchaîne d'abord les infiltrations
    const map = makeMap(infil); tested++;
    if (!map) continue;
    const res = calibrate(map, infil);
    if (res){
      const file = saveMission(res.mission, res.wr,
        { format: map.format, cols: map.cols, rows: map.rows, n: res.n, buff: res.buff, infil });
      kept++; if (infil) keptInfil++;
      log(`✓ gardée ${file} ${infil?"[INFIL] ":""}— ${Math.round(res.wr*100)}% (${map.format} ${map.cols}x${map.rows}, ${res.n} ennemis, buff hp${res.buff.hp}/aim${res.buff.aim}) | testées ${tested}, gardées ${kept}`);
    } else if (tested % 10 === 0){
      const rate = (now() - t0) / tested;
      log(`… ${tested} cartes testées, ${kept} gardées (~${rate.toFixed(0)} ms/carte)`);
    }
  }
  log(`=== fin : ${tested} cartes testées, ${kept} gardées en ${(((now()-t0)/60000)).toFixed(1)} min ===`);
}

module.exports = { T, makeMap, buildMission, playGame, winrate, calibrate, aiAct };
if (require.main === module) main();
