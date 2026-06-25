// Banc d'essai : génère des missions (paramétrées), les joue en IA-vs-IA (sync),
// agrège les données et balaie les paramètres clés — TAILLE DE MAP, DISTANCE/ESPACEMENT
// DES PODS, TAILLE DE MOUVEMENT, COUVERT — pour calibrer la génération.
const fs = require("fs");
const path = require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const M = loadMesh();

// ---------- IA générique synchrone (mêmes primitives que le jeu) ----------
function rangeOf(u,m){ const w=u.w[m]; return w?(w.range||1):1; }
function pickMode(u){ if(u.w.ranged&&(u.clip===undefined||u.ammo>0))return "ranged"; if(u.w.melee)return "melee"; return u.w.ranged?"ranged":"melee"; }
function nearestFoe(u){ let best=null,bd=1e9; for(const p of M.units){ if(!M.hostile(u,p)||p.hp<=0)continue; const d=M.hops(u.cell,p.cell); if(d<bd){bd=d;best=p;} } return best; }
function actUnit(u){ let guard=0;
  while(u.hp>0 && !M.over && guard++<8 && (u.ap>0||u.freeAvail)){
    const t=nearestFoe(u); if(!t)return;
    const m=pickMode(u);
    if(M.inRange(u,t,m)){ M.doAttack(u,t,m); return; }            // doAttack met ap=0 → fin
    const d=M.reach(u); let best=null,bestScore=1e18;
    for(const k in d){ const cell=+k; const ap=M.apForMove(u,d[k]);
      const hit = m==="ranged" ? (M.hops(cell,t.cell)<=rangeOf(u,m)&&M.los(cell,t.cell)) : M.adjacent(cell,t.cell);
      const score = hit ? ap : 100 + M.hops(cell,t.cell);
      if(score<bestScore){bestScore=score;best=cell;} }
    if(best==null||best===u.cell)return;
    M.moveAlong(u,best);
  }
}
const alive = (team)=> M.units.some(u=>u.team===team&&u.hp>0);
function refreshAP(team){ for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;} }
const SEQ = process.env.SEQ!=="0";   // activation séquentielle des pods (réaliste) ; SEQ=0 = engagement simultané
function simulate(maxTurns){
  M.mode="play"; M.over=false; M.turn="player";
  if(!SEQ){ for(const u of M.units)if(u.team==="enemy")u.asleep=false; }   // engagement simultané (pire cas)
  let turns=0, side="player";
  while(turns<maxTurns && !M.over && alive("player") && alive("enemy")){
    refreshAP(side);
    for(const u of M.units.slice()){ if(M.over)break; if(u.team!==side||u.hp<=0)continue;
      if(side==="enemy"&&SEQ&&!M.enemyActive(u))continue;                 // pod dormant : ne joue pas tant qu'il n'est pas repéré
      actUnit(u); }
    if(side==="enemy")turns++;
    side = side==="player"?"enemy":"player";
  }
  const pAlive=M.units.filter(u=>u.team==="player"&&u.hp>0).length;
  const eAlive=M.units.filter(u=>u.team==="enemy"&&u.hp>0).length;
  const result = !alive("enemy")?"win" : !alive("player")?"loss" : "timeout";
  return { result, turns, pAlive, eAlive };
}

// ---------- métriques statiques de la map générée ----------
function mapMetrics(meta){
  const cells=M.cells, n=cells.length;
  let wall=0,rough=0; for(const c of cells){ if(c.terr==="wall")wall++; else if(c.terr==="rough")rough++; }
  const players=M.units.filter(u=>u.team==="player"), enemies=M.units.filter(u=>u.team==="enemy");
  const deploy = players.length?players[0].cell : (meta&&meta.deploy);
  // pods = ancres (1er ennemi de chaque pod)
  const podCells=(meta&&meta.podAnchors)||[];
  // distance déploiement → pod la plus proche
  let dDeployPod=Infinity; for(const pc of podCells){ const h=M.hops(deploy,pc); if(h<dDeployPod)dDeployPod=h; }
  // espacement min entre pods
  let podSpacingMin=Infinity; for(let i=0;i<podCells.length;i++)for(let j=i+1;j<podCells.length;j++){ const h=M.hops(podCells[i],podCells[j]); if(h<podSpacingMin)podSpacingMin=h; }
  // accessibilité : tous les ennemis joignables depuis le déploiement ?
  let reachableEnemies=0; for(const e of enemies){ if(M.hops(deploy,e.cell)<1e8)reachableEnemies++; }
  return { cells:n, coverPct:Math.round(100*(wall+rough)/Math.max(1,n)), wallPct:Math.round(100*wall/Math.max(1,n)),
    players:players.length, enemies:enemies.length, pods:podCells.length,
    dDeployPod:isFinite(dDeployPod)?dDeployPod:-1, podSpacingMin:isFinite(podSpacingMin)?podSpacingMin:-1,
    accessible: reachableEnemies===enemies.length && enemies.length>0 };
}

// ---------- un essai : génère + joue R fois ----------
function trial(P, runs, baseSeed){
  if(P.board)M.setBoardSize(P.board[0],P.board[1]);
  M.setMove(P.mob, P.ap, P.free);
  const agg={ runs:0, win:0, loss:0, timeout:0, turnsSum:0, pAliveSum:0, eAliveSum:0, degenerate:0, map:null };
  for(let r=0;r<runs;r++){
    M.setSeed(baseSeed + r*1013904223);
    let meta; try{ meta=M.genMission(P); }catch(e){ agg.degenerate++; continue; }
    if(!meta){ agg.degenerate++; continue; }
    const mm=mapMetrics(meta);
    if(!agg.map)agg.map=mm;
    if(!mm.accessible){ agg.degenerate++; }           // map dégénérée : ennemi injoignable
    M.reseed(baseSeed*2654435761 + r*40503 + 1);
    const s=simulate(P.maxTurns||30);
    agg.runs++; agg[s.result]++; agg.turnsSum+=s.turns; agg.pAliveSum+=s.pAlive; agg.eAliveSum+=s.eAlive;
  }
  const r=agg.runs||1;
  return { winRate:+(100*agg.win/r).toFixed(0), lossRate:+(100*agg.loss/r).toFixed(0), timeoutRate:+(100*agg.timeout/r).toFixed(0),
    avgTurns:+(agg.turnsSum/r).toFixed(1), avgPAlive:+(agg.pAliveSum/r).toFixed(1), avgEAlive:+(agg.eAliveSum/r).toFixed(1),
    degenerate:agg.degenerate, map:agg.map, runs:agg.runs };
}

// ---------- balayages ----------
const RUNS = +(process.env.RUNS||8);
const results = [];
function sweep(name, base, axis, values){
  console.log(`\n=== ${name} ===`);
  console.log("param            | cells cov% pods dDepl spc acc | win% loss% to%  turns pAlv eAlv | degen");
  for(const v of values){
    const P=Object.assign({maxTurns:45}, base, axis(v));
    const out=trial(P, RUNS, 1234567);
    const mp=out.map||{};
    const line=`${String(name+"="+JSON.stringify(v)).padEnd(16)} | ${String(mp.cells).padStart(5)} ${String(mp.coverPct).padStart(3)} ${String(mp.pods).padStart(4)} ${String(mp.dDeployPod).padStart(5)} ${String(mp.podSpacingMin).padStart(3)} ${mp.accessible?" Y":" n"} | ${String(out.winRate).padStart(4)} ${String(out.lossRate).padStart(5)} ${String(out.timeoutRate).padStart(3)} ${String(out.avgTurns).padStart(6)} ${String(out.avgPAlive).padStart(4)} ${String(out.avgEAlive).padStart(4)} | ${out.degenerate}`;
    console.log(line);
    results.push({sweep:name, value:v, params:P, map:mp, out});
  }
}

// 1) TAILLE DE MAP (board) — petit / moyen / grand
sweep("mapSize", {cover:0.28, podCount:3, podSpacing:3, mob:3, ap:2, free:2},
  v=>({board:v}), [[8,6],[12,9],[16,12],[20,14]]);
// 2) MOUVEMENT (MOB) — combien on avance par tour
sweep("mob", {board:[12,9], cover:0.28, podCount:3, podSpacing:3, ap:2, free:2},
  v=>({mob:v}), [2,3,4,5]);
// 3) ESPACEMENT DES PODS (distance min entre pods)
sweep("podSpacing", {board:[12,9], cover:0.28, podCount:4, mob:3, ap:2, free:2},
  v=>({podSpacing:v}), [2,3,5,7]);
// 4) DISTANCE DÉPLOIEMENT → PODS
sweep("podMinDist", {board:[12,9], cover:0.28, podCount:3, podSpacing:3, mob:3, ap:2, free:2},
  v=>({podMinDist:v}), [3,5,8,12]);
// 5) NOMBRE DE PODS
sweep("podCount", {board:[12,9], cover:0.28, podSpacing:3, mob:3, ap:2, free:2},
  v=>({podCount:v}), [1,2,3,4,5]);
// 6) COUVERT
sweep("cover", {board:[12,9], podCount:3, podSpacing:3, mob:3, ap:2, free:2},
  v=>({cover:v}), [0.12,0.22,0.32,0.45]);

fs.writeFileSync(path.join(__dirname,"sim-results.json"), JSON.stringify(results,null,1));
console.log(`\n${results.length} configs testées · ${RUNS} parties/config · données -> tools/sim-results.json`);
