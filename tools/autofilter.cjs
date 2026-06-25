// Boucle d'auto-filtrage : génère des missions, les fait jouer (IA-vs-IA, jugées par OBJECTIF),
// et ne garde que celles dont le taux de victoire estimé tombe dans la fenêtre jouable.
// Rejette les dégénérées (sans ennemis, joueur muré) et les déséquilibrées (trop faciles/dures).
const fs = require("fs"), path = require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh(); const actUnit = makeActUnit(M);

const ARCH  = process.env.ARCH  || "eliminate";
const POD   = +(process.env.POD || 2);
const BOARD = (process.env.BOARD|| "13x10").split("x").map(Number);
const COVER = +(process.env.COVER|| 0.30);
const N     = +(process.env.N   || 16);          // candidats
const K     = +(process.env.K   || 7);           // parties / candidat
const LO    = +(process.env.LO  || 0.35);        // fenêtre basse
const HI    = +(process.env.HI  || 0.70);        // fenêtre haute
const MAXT  = +(process.env.MAXT|| 14);
const OUT   = process.env.OUT   || "/tmp/claude-0/-home-user-game/fc9dfef8-6f8a-5243-95d8-c82e81013118/scratchpad/accepted";
const SAVE  = process.env.SAVE !== "0";
if(SAVE){ fs.mkdirSync(OUT, {recursive:true}); }

function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function genSame(seed){ M.setBoardSize(BOARD[0],BOARD[1]); M.setMove(3,2,2); M.setSeed(seed);
  try{ return M.genMission({archetype:ARCH,podCount:POD,cover:COVER,podSpacing:4}); }catch(e){ return null; } }
function sim(maxT){ M.mode="play"; M.over=false; M.lastOutcome=null; M.turn="player"; M.turnNum=1; let turns=0,side="player";
  while(turns<maxT && !M.over){ if(side==="player"){ M.turnNum=turns+1; M.checkEnd(); if(M.over)break; }
    refreshAP(side);
    for(const u of M.units.slice()){ if(M.over)break; if(u.team!==side||u.hp<=0)continue; if(side==="enemy"&&!M.enemyActive(u))continue; M.refresh(); actUnit(u); M.checkEnd(); if(M.over)break; }
    if(side==="enemy")turns++; side=side==="player"?"enemy":"player"; }
  return M.over ? (M.lastOutcome||"loss") : "timeout"; }

const tally={accepted:0,easy:0,hard:0,degenerate:0,noisy:0}; const kept=[];
for(let i=0;i<N;i++){ const seed=1000003+i*2654435761>>>0;
  const meta=genSame(seed); if(!meta){ tally.degenerate++; continue; }
  if(!M.units.some(u=>u.team==="enemy")){ tally.degenerate++; continue; }
  const obj=M.exportObj(); obj.name=`${ARCH}_p${POD}_${seed}`;
  let w=0,l=0,t=0;
  for(let r=0;r<K;r++){ genSame(seed); M.reseed((seed*40503 + r*1013904223)>>>0); const res=sim(MAXT); if(res==="win")w++;else if(res==="loss")l++;else t++; }
  const win=w/K, to=t/K;
  let verdict;
  if(to>0.34){ verdict="noisy"; tally.noisy++; }
  else if(win>HI){ verdict="easy"; tally.easy++; }
  else if(win<LO){ verdict="hard"; tally.hard++; }
  else { verdict="ACCEPT"; tally.accepted++; kept.push(obj);
    if(SAVE) fs.writeFileSync(path.join(OUT,obj.name+".json"), JSON.stringify(obj)); }
  console.log(`#${String(i).padStart(2)} seed ${String(seed).padEnd(11)} win ${(win*100).toFixed(0).padStart(3)}% to ${(to*100).toFixed(0).padStart(3)}% | ${meta.cells}c J${obj.units.filter(u=>u.team==="player").length} E${obj.units.filter(u=>u.team==="enemy").length} -> ${verdict}`);
}
console.log(`\n${ARCH} pod${POD} board ${BOARD.join("x")} cover ${COVER} · fenêtre [${LO}-${HI}] · ${K} parties/candidat`);
console.log(`accepté ${tally.accepted}/${N} | trop facile ${tally.easy} · trop dur ${tally.hard} · bruité ${tally.noisy} · dégénéré ${tally.degenerate}`);
if(SAVE&&kept.length) console.log(`→ ${kept.length} missions écrites dans ${OUT}`);
