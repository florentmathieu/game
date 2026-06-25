const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh(); const actUnit = makeActUnit(M);
function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function sim(maxT){ M.mode="play";M.over=false;M.lastOutcome=null;M.turn="player";M.turnNum=1;let turns=0,side="player";
  while(turns<maxT&&!M.over){ if(side==="player"){M.turnNum=turns+1;M.checkEnd();if(M.over)break;} refreshAP(side);
    for(const u of M.units.slice()){if(M.over)break;if(u.team!==side||u.hp<=0)continue;if(side==="enemy"&&!M.enemyActive(u))continue;if(side==="player")M.refresh();actUnit(u);M.checkEnd();if(M.over)break;}
    if(side==="enemy")turns++;side=side==="player"?"enemy":"player";}
  return M.over?(M.lastOutcome||"loss"):"timeout"; }
const ARCH=process.env.ARCH||"eliminate"; const POD=+(process.env.POD||2);
const SEEDS=+(process.env.SEEDS||8), K=+(process.env.K||5);
console.log(`${ARCH} pod${POD} 13x10 cover .30 · ${SEEDS} cartes × ${K} parties`);
for(const en of [3,4,5,6,7,8]){ let win=0,games=0,spread=[];
  for(let s=0;s<SEEDS;s++){ const seed=(1000003+s*2654435761)>>>0; let w=0,n=0;
    for(let r=0;r<K;r++){ M.setBoardSize(13,10);M.setMove(3,2,2);M.setSeed(seed);
      const meta=M.genMission({archetype:ARCH,podCount:POD,enemyCount:en,cover:0.30,podSpacing:4}); if(!meta)continue;
      M.reseed((seed*40503+r*1013904223)>>>0); const res=sim(14); if(res==="win")w++; n++; }
    win+=w; games+=n; spread.push(Math.round(100*w/Math.max(1,K))); }
  console.log(`EN=${en} | win ${String(Math.round(100*win/Math.max(1,games))).padStart(3)}% | par carte: ${spread.join(",")}`);
}
