// Variante du banc d'essai avec une IA joueur PLUS MALIGNE (borne haute de difficulté) :
// focus-fire (bestEnemyTarget), kiting des unités à distance, recherche couvert/hauteur,
// éviter de finir au contact de plusieurs ennemis, conserver des PA.
// But : encadrer les taux de victoire (IA naïve = borne basse) pour des données plus fiables.
const { loadMesh } = require("./mesh-engine.cjs");
const M = loadMesh();
const RUNS = +(process.env.RUNS||10);

function rangeOf(u,m){const w=u.w[m];return w?(w.range||1):1;}
function pickMode(u){if(u.w.ranged&&(u.clip===undefined||u.ammo>0))return "ranged";if(u.w.melee)return "melee";return u.w.ranged?"ranged":"melee";}
function actUnit(u){ let g=0;
  while(u.hp>0&&!M.over&&g++<8&&(u.ap>0||u.freeAvail)){
    const m=pickMode(u);
    const t=M.bestEnemyTarget(u);                       // focus-fire : meilleure cible À PORTÉE
    if(t&&M.inRange(u,t,m)){ M.doAttack(u,t,m); return; }
    const foe=M.nearestOpposing(u); if(!foe)return;
    const d=M.reach(u); let best=null,bs=-1e18;
    for(const k in d){ const c=+k, ap=M.apForMove(u,d[k]);
      const canHit = m==="ranged" ? (M.hops(c,foe.cell)<=rangeOf(u,m)&&M.los(c,foe.cell)) : M.adjacent(c,foe.cell);
      const elev=(M.cells[c].elev||0), adjWalls=M.cells[c].nb.filter(n=>!M.passable(n)).length;
      const enemiesAdj=M.units.filter(e=>e.hp>0&&M.hostile(u,e)&&M.adjacent(c,e.cell)).length;
      let s=0;
      if(canHit){ s+=1000; if(m==="ranged")s+=M.hops(c,foe.cell)*5; }   // pouvoir frapper ; à distance, kiter
      else s-=M.hops(c,foe.cell)*2;                                      // sinon se rapprocher
      s += elev*8 + adjWalls*4 - enemiesAdj*15 - ap*2;                   // hauteur + couvert ; éviter l'encerclement ; garder du PA
      if(s>bs){bs=s;best=c;} }
    if(best==null||best===u.cell)return;
    M.moveAlong(u,best);
  } }
const alive=t=>M.units.some(u=>u.team===t&&u.hp>0);
function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function simulate(maxTurns){
  M.mode="play";M.over=false;M.turn="player";
  let turns=0,side="player";
  while(turns<maxTurns&&!M.over&&alive("player")&&alive("enemy")){
    refreshAP(side);
    for(const u of M.units.slice()){if(M.over)break;if(u.team!==side||u.hp<=0)continue;
      if(side==="enemy"&&!M.enemyActive(u))continue;
      actUnit(u);}
    if(side==="enemy")turns++; side=side==="player"?"enemy":"player";
  }
  return !alive("enemy")?"win":!alive("player")?"loss":"timeout";
}
function cfg(P){ let win=0;
  for(let r=0;r<RUNS;r++){ if(P.board)M.setBoardSize(P.board[0],P.board[1]); M.setMove(3,2,2);
    M.setSeed(424242+r*1013904223); let meta; try{meta=M.genMission(P);}catch(e){continue;} if(!meta)continue;
    M.reseed(r*2654435761+7); if(simulate(45)==="win")win++; }
  return Math.round(100*win/RUNS); }

console.log(`IA maligne (borne haute) · ${RUNS} parties/case · séquentiel\n`);
console.log("=== nb de pods (board 13x10, couvert 0.30, spc 4) ===");
for(const p of [1,2,3,4]) console.log(`pods=${p} -> win ${cfg({podCount:p,board:[13,10],cover:0.30,podSpacing:4})}%`);
console.log("\n=== nb de pods x couvert (board 13x10) ===");
console.log("pods\\cov |   0.15   0.25   0.35");
for(const p of [1,2,3]){ const row=[0.15,0.25,0.35].map(c=>String(cfg({podCount:p,board:[13,10],cover:c,podSpacing:4})).padStart(6)).join(" "); console.log(`pods=${p}  | ${row}`); }
