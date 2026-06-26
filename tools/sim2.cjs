// Banc d'essai avec l'IA tactique (tools/ai.cjs) pour les DEUX camps — estimation réaliste.
const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh();
const actUnit = makeActUnit(M);
const RUNS = +(process.env.RUNS||10);

const alive=t=>M.units.some(u=>u.team===t&&u.hp>0);
function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function simulate(maxTurns){
  M.mode="play";M.over=false;M.turn="player";
  let turns=0,side="player";
  while(turns<maxTurns&&!M.over&&alive("player")&&alive("enemy")){
    refreshAP(side);
    for(const u of M.units.slice()){if(M.over)break;if(u.team!==side||u.hp<=0)continue;if(side==="enemy"&&!M.enemyActive(u))continue;if(side==="player")M.refresh();else M.computeEVis();actUnit(u);}
    if(side==="enemy")turns++; side=side==="player"?"enemy":"player";
  }
  const r=!alive("enemy")?"win":!alive("player")?"loss":"timeout";
  const pAlive=M.units.filter(u=>u.team==="player"&&u.hp>0).length;
  return {r,pAlive,turns};
}
function cfg(P){ let win=0,loss=0,to=0,pa=0,tn=0;
  for(let r=0;r<RUNS;r++){ if(P.board)M.setBoardSize(P.board[0],P.board[1]); M.setMove(P.mob||3,2,2);
    M.setSeed(424242+r*1013904223); let meta; try{meta=M.genMission(P);}catch(e){continue;} if(!meta)continue;
    M.reseed(r*2654435761+7); const s=simulate(+(process.env.MAXT||45)); if(s.r==="win")win++;else if(s.r==="loss")loss++;else to++; pa+=s.pAlive; tn+=s.turns; }
  return {win:Math.round(100*win/RUNS), loss:Math.round(100*loss/RUNS), to:Math.round(100*to/RUNS), pa:+(pa/RUNS).toFixed(1), turns:+(tn/RUNS).toFixed(0)}; }

console.log(`IA TACTIQUE (deux camps) · ${RUNS} parties/case · séquentiel\n`);
console.log("=== nb de pods (board 13x10, couvert 0.30, spc 4) ===");
console.log("pods | win% loss% to% | survJ tours");
for(const p of [1,2,3,4]){ const o=cfg({podCount:p,board:[13,10],cover:0.30,podSpacing:4}); console.log(`  ${p}  | ${String(o.win).padStart(3)} ${String(o.loss).padStart(4)} ${String(o.to).padStart(3)} | ${String(o.pa).padStart(4)} ${o.turns}`); }
console.log("\n=== espacement des pods (3 pods, board 13x10) ===");
for(const s of [2,4,6]){ const o=cfg({podCount:3,podSpacing:s,board:[13,10],cover:0.30}); console.log(`spc=${s} | win ${o.win}% loss ${o.loss}% to ${o.to}%`); }
console.log("\n=== nb de pods x couvert (board 13x10) ===");
console.log("pods\\cov | 0.15 0.25 0.35");
for(const p of [1,2,3]){ const row=[0.15,0.25,0.35].map(c=>String(cfg({podCount:p,cover:c,board:[13,10],podSpacing:4}).win).padStart(4)).join(" "); console.log(`   ${p}    |${row}`); }
console.log("\n(IA tactique des deux côtés : estimation réaliste, à comparer à l'IA naïve.)");
