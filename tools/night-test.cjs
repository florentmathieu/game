// Mandat nocturne : joue des campagnes Acte 1 en boucle (IA des deux camps), gagne des niveaux,
// enchaîne 2-3 parties (progression persistée), puis recommence (lignée neuve). Vérifie que tout roule.
const fs=require("fs"), path=require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh(); const actUnit = makeActUnit(M);

// politique de promotion auto : survie d'abord (PV/blocage), puis offensive
M.setAutoPromote((m,grade,pair)=>{ const s=p=>{const x=(p&&p.mod)||{};return (x.hp||0)+(x.shieldBlock||0)*0.06+(x.parry||0)*0.06+(x.dmg||0)*1.3+(x.aim||0)*0.07+(x.mob||0)*1.6+(x.range||0)*1.3+(x.crackers||0);}; return s(pair.A)>=s(pair.B)?"A":"B"; });

const geo0 = JSON.parse(fs.readFileSync("geoscapes-mesh/acte1.json","utf8"));
const camp = JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8"));
const geoNode = camp.nodes.find(n=>n.type==="geoscape");
const loadMission = ref => JSON.parse(fs.readFileSync(path.join("missions-mesh",ref),"utf8"));

const alive=t=>M.units.some(u=>u.team===t&&u.hp>0);
function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function simMission(maxT){ M.mode="play"; M.over=false; M.lastOutcome=null; M.turn="player"; M.turnNum=1; let turns=0,side="player";
  while(turns<maxT && !M.over){ if(side==="player"){ M.turnNum=turns+1; M.checkEnd(); if(M.over)break; }
    refreshAP(side);
    for(const u of M.units.slice()){ if(M.over)break; if(u.team!==side||u.hp<=0)continue; if(side==="enemy"&&!M.enemyActive(u))continue; if(side==="player")M.refresh(); actUnit(u); M.checkEnd(); if(M.over)break; }
    if(side==="enemy")turns++; side=side==="player"?"enemy":"player"; }
  return M.over ? (M.lastOutcome||"loss") : "timeout"; }

let ERRORS=[];
function buildRun(){ const roster=(camp.roster||[]).map(m=>({name:m.name,cls:m.cls,xp:m.xp||0,perks:[]}));
  const saved=M.loadRosterProgress(camp.name); if(saved)for(const m of roster){ const s=saved.find(x=>x.name===m.name&&x.cls===m.cls); if(s){ m.xp=s.xp||0; m.perks=(s.perks||[]).slice(); } }
  const cr={ camp:{name:camp.name,nodes:camp.nodes}, carry:{}, roster, geoStates:{}, potions:0, seen:new Set(), nodeId:geoNode.id };
  cr.geoStates[geoNode.id]=geo0.cells.map(c=>c.state||"locked"); return cr; }

function runOnce(tag){ const cr=buildRun(); M.campRun=cr; M.curMission=null;
  M.geoPlay={ node:{id:geoNode.id,map:geoNode.map,endWhen:geoNode.endWhen,next:geoNode.next}, map:JSON.parse(JSON.stringify(geo0)), inMission:false };
  let missions=0,wins=0,losses=0,to=0,guard=0;
  while(guard++<30){ const st=cr.geoStates[geoNode.id];
    const avail=geo0.cells.map((c,i)=>({c,i})).filter(x=>x.c.content&&x.c.content.kind==="mission"&&st[x.i]==="available");
    if(!avail.length) break; avail.sort((a,b)=>(a.c.diff||9)-(b.c.diff||9)); const pick=avail[0];
    try{
      M.applyMissionObj(loadMission(pick.c.content.ref)); M.deployRoster();
      M.mode="play"; M.startGame();
      for(const u of M.units)if(u.team==="player"){ const c=cr.carry[u.name]; if(c!=null)u.hp=Math.max(1,Math.min(u.max,c)); }   // applyCarry
      cr.geoReturn={nodeId:geoNode.id,cellId:pick.i}; M.geoPlay.inMission=true;
      if(process.env.TRACE)console.log("    play",pick.c.name,"diff",pick.c.diff,"cells",M.cells.length,"J",M.units.filter(u=>u.team==="player").length,"E",M.units.filter(u=>u.team==="enemy").length); const res=simMission(+(process.env.MAXT||36));
      missions++; if(res==="win")wins++; else if(res==="loss")losses++; else to++;
      if(!M.over) M.geoMissionEnd("Défaite");   // timeout : l'IA n'a pas conclu -> on force ; sinon le moteur (end->campEnd->geoMissionEnd) a déjà géré le retour
    }catch(e){ ERRORS.push(`[${tag} cell ${pick.c.name}] ${e.message}`); if(process.env.TRACE)console.log(e.stack); break; }
    if(M.geoPlay===null) break;   // acte terminé (Bastion pris)
  }
  const saved=M.loadRosterProgress(camp.name)||[];
  return { missions,wins,losses,to, actEnded:M.geoPlay===null,
    roster: saved.map(m=>`${m.name} g${(m.perks||[]).length}(xp${m.xp})`).join(", ") }; }

const CYCLES=+(process.env.CYCLES||3), RUNS=+(process.env.RUNS||3);
let totMis=0,totWin=0,totLoss=0,totTo=0,acts=0;
for(let c=0;c<CYCLES;c++){ M.clearRosterProgress(camp.name);   // nouvelle lignée
  console.log(`\n=== Cycle ${c+1} (lignée neuve) ===`);
  let prevXp=-1;
  for(let r=0;r<RUNS;r++){ const o=runOnce(`c${c+1}r${r+1}`);
    totMis+=o.missions; totWin+=o.wins; totLoss+=o.losses; totTo+=o.to; if(o.actEnded)acts++;
    console.log(`  run ${r+1}: ${o.missions} missions (${o.wins}W ${o.losses}L ${o.to}T)${o.actEnded?" — ACTE TERMINÉ":""} | ${o.roster}`);
    const xpSum=(M.loadRosterProgress(camp.name)||[]).reduce((a,m)=>a+(m.xp||0),0);
    if(xpSum<prevXp) ERRORS.push(`[c${c+1}r${r+1}] régression XP (${xpSum}<${prevXp})`); prevXp=xpSum;
  }
}
console.log(`\n==== BILAN ====`);
console.log(`runs: ${CYCLES*RUNS} | missions: ${totMis} (${totWin}W ${totLoss}L ${totTo}T) | actes terminés: ${acts}`);
console.log(`timeouts: ${totTo}${totTo?"  <-- À INVESTIGUER":""}`);
console.log(`erreurs: ${ERRORS.length}`); ERRORS.slice(0,20).forEach(e=>console.log("  ! "+e));
