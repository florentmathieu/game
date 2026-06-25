// Balayages CROISÉS (interactions) : nombre de pods × taille de map, et × couvert.
// But : trouver, pour chaque difficulté (nb de pods), la taille/couvert qui donne une
// fenêtre de victoire jouable — d'où une règle de génération (la map grandit avec la difficulté).
const { loadMesh } = require("./mesh-engine.cjs");
const M = loadMesh();
const RUNS = +(process.env.RUNS||10);

function rangeOf(u,m){const w=u.w[m];return w?(w.range||1):1;}
function pickMode(u){if(u.w.ranged&&(u.clip===undefined||u.ammo>0))return "ranged";if(u.w.melee)return "melee";return u.w.ranged?"ranged":"melee";}
function nearestFoe(u){let b=null,bd=1e9;for(const p of M.units){if(!M.hostile(u,p)||p.hp<=0)continue;const d=M.hops(u.cell,p.cell);if(d<bd){bd=d;b=p;}}return b;}
function actUnit(u){let g=0;while(u.hp>0&&!M.over&&g++<8&&(u.ap>0||u.freeAvail)){const t=nearestFoe(u);if(!t)return;const m=pickMode(u);if(M.inRange(u,t,m)){M.doAttack(u,t,m);return;}const d=M.reach(u);let best=null,bs=1e18;for(const k in d){const c=+k,ap=M.apForMove(u,d[k]);const hit=m==="ranged"?(M.hops(c,t.cell)<=rangeOf(u,m)&&M.los(c,t.cell)):M.adjacent(c,t.cell);const sc=hit?ap:100+M.hops(c,t.cell);if(sc<bs){bs=sc;best=c;}}if(best==null||best===u.cell)return;M.moveAlong(u,best);}}
const alive=t=>M.units.some(u=>u.team===t&&u.hp>0);
function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function simulate(maxTurns){
  M.mode="play";M.over=false;M.turn="player";
  let turns=0,side="player";
  while(turns<maxTurns&&!M.over&&alive("player")&&alive("enemy")){
    refreshAP(side);
    for(const u of M.units.slice()){if(M.over)break;if(u.team!==side||u.hp<=0)continue;if(side==="enemy"&&!M.enemyActive(u))continue;actUnit(u);}
    if(side==="enemy")turns++; side=side==="player"?"enemy":"player";
  }
  return !alive("enemy")?"win":!alive("player")?"loss":"timeout";
}
function cell(P){ let win=0,degen=0;
  for(let r=0;r<RUNS;r++){ if(P.board)M.setBoardSize(P.board[0],P.board[1]); M.setMove(3,2,2);
    M.setSeed(900900+r*1013904223); let meta; try{meta=M.genMission(P);}catch(e){degen++;continue;} if(!meta){degen++;continue;}
    M.reseed(5732843+r*40503+1); if(simulate(45)==="win")win++; }
  return Math.round(100*win/RUNS); }

function matrix(title, rows, cols, mk){
  console.log(`\n=== ${title} (win%, ${RUNS} parties/case) ===`);
  console.log("pods\\"+title.split(" ").pop()+" | "+cols.map(c=>String(JSON.stringify(c)).padStart(8)).join(" "));
  for(const rW of rows){ const line=cols.map(c=>String(cell(mk(rW,c))).padStart(8)).join(" "); console.log(String("pods="+rW).padEnd(8)+"| "+line); }
}

const boards=[[10,7],[13,10],[17,12],[22,15]];
const covers=[0.15,0.25,0.35,0.45];
const pods=[1,2,3,4];

matrix("podCount x board", pods, boards, (p,b)=>({podCount:p, board:b, cover:0.30, podSpacing:4, diff:"moyen"}));
matrix("podCount x cover", pods, covers, (p,c)=>({podCount:p, board:[13,10], cover:c, podSpacing:4, diff:"moyen"}));

console.log("\n(win% = borne basse : IA joueur naïve. Lire les tendances.)");
