// Sanity-check des archétypes : l'IA des deux camps, victoire/défaite décidées par checkEnd (objectif).
const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh(); const actUnit = makeActUnit(M);
function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function sim(maxT){
  M.mode="play"; M.over=false; M.lastOutcome=null; M.turn="player"; M.turnNum=1;
  let turns=0, side="player";
  while(turns<maxT && !M.over){
    if(side==="player"){ M.turnNum=turns+1; M.checkEnd(); if(M.over)break; }
    refreshAP(side);
    for(const u of M.units.slice()){ if(M.over)break; if(u.team!==side||u.hp<=0)continue; if(side==="enemy"&&!M.enemyActive(u))continue; if(side==="player")M.refresh(); else M.computeEVis(); actUnit(u); M.checkEnd(); if(M.over)break; }
    if(side==="enemy")turns++; side=side==="player"?"enemy":"player";
  }
  return { r: M.over ? (M.lastOutcome||"loss") : "timeout", turns };
}
const archs=["eliminate","assassinate","rescue","defend","survive","extract"];
const N=+(process.env.N||8);
for(const a of archs){ let w=0,l=0,t=0,seq="";
  for(let r=0;r<N;r++){ M.setBoardSize(13,10); M.setMove(3,2,2); M.setSeed(424242+r*1013904223);
    let meta; try{meta=M.genMission({archetype:a,podCount:2,cover:0.30,podSpacing:4});}catch(e){continue;} if(!meta)continue;
    M.reseed(r*2654435761+7); const s=sim(12);
    if(s.r==="win")w++;else if(s.r==="loss"||s.r==="lose")l++;else t++; seq+=s.r[0]; }
  console.log(`${a.padEnd(11)} | win ${w} loss ${l} to ${t} /${N}  [${seq}]`);
}
