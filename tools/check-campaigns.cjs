// Vérifie que les maps régénérées (distorsion progressive) restent JOUABLES :
// joue des campagnes complètes acte 1 → acte 2 (IA des deux camps, roster qui monte en niveau,
// distorsion runtime active), et rapporte win%, timeouts, erreurs par acte.
const fs=require("fs"), path=require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh(); const actUnit = makeActUnit(M);

M.setAutoPromote((m,grade,pair)=>{ if(m.cls==="mage")return "A";
  const s=p=>{const x=(p&&p.mod)||{};return (x.hp||0)+(x.shieldBlock||0)*0.06+(x.parry||0)*0.06+(x.dmg||0)*1.3+(x.aim||0)*0.07+(x.mob||0)*1.6+(x.freeMp||0)*2.2+(x.range||0)*1.3+(x.crackers||0);}; return s(pair.A)>=s(pair.B)?"A":"B"; });

const camp = JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8"));
const loadMission = ref => JSON.parse(fs.readFileSync(path.join("missions-mesh",ref),"utf8"));
const loadGeo = map => JSON.parse(fs.readFileSync(path.join("geoscapes-mesh",map),"utf8"));
const geoNodes = camp.nodes.filter(n=>n.type==="geoscape");

const alive=t=>M.units.some(u=>u.team===t&&u.hp>0);
function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;if(u.stunned){u.ap=0;u.freeAvail=false;u.stunned=false;}} M.tickCd(team);}
function simMission(maxT){ M.mode="play"; M.over=false; M.lastOutcome=null; M.turn="player"; M.turnNum=1; let turns=0,side="player";
  const live=()=>M.geoPlay&&M.geoPlay.inMission;
  while(turns<maxT && live()){ if(side==="player"){ M.turnNum=turns+1; M.checkEnd(); if(!live())break; }
    refreshAP(side);
    for(const u of M.units.slice()){ if(!live())break; if(u.team!==side||u.hp<=0)continue; if(side==="enemy"&&!M.enemyActive(u))continue; if(side==="player")M.refresh(); else M.computeEVis(); actUnit(u); if(live())M.checkEnd(); if(!live())break; }
    if(side==="enemy")turns++; side=side==="player"?"enemy":"player"; }
  if(live())M.geoMissionEnd("Défaite");
  return M.lastOutcome||"timeout"; }

let ERRORS=[];
function buildRoster(){ const roster=(camp.roster||[]).map(m=>({name:m.name,cls:m.cls,xp:m.xp||0,perks:[],stress:0,fatigue:0,special:m.special!==false,dead:false}));
  const saved=M.loadRosterProgress(camp.name); if(saved)for(const m of roster){ const s=saved.find(x=>x.name===m.name&&x.cls===m.cls); if(s){ m.xp=s.xp||0; m.perks=(s.perks||[]).slice(); m.stress=s.stress||0; m.fatigue=s.fatigue||0; m.special=s.special!==false; m.dead=!!s.dead; } }
  return roster; }

function runAct(tag, geoNode, geo0, prevMissionN){
  const roster=buildRoster();
  const cr={ camp:{name:camp.name,nodes:camp.nodes}, carry:{}, roster, geoStates:{}, potions:0, seen:new Set(), nodeId:geoNode.id, missionN:prevMissionN||0 };
  cr.geoStates[geoNode.id]=geo0.cells.map(c=>c.state||"locked");
  M.campRun=cr; M.curMission=null;
  M.geoPlay={ node:{id:geoNode.id,map:geoNode.map,endWhen:geoNode.endWhen,next:geoNode.next}, map:JSON.parse(JSON.stringify(geo0)), inMission:false };
  M.geoBuildCells();
  let missions=0,wins=0,losses=0,to=0,guard=0;
  while(guard++<60){ const acc=M.geoAccessibleSet(geoNode.id);   // plafond large : un acte à 20 régions demande beaucoup de missions (+ re-défenses)
    const avail=geo0.cells.map((c,i)=>({c,i})).filter(x=>x.c.content&&x.c.content.kind==="mission"&&acc.has(x.i));
    if(!avail.length) break; avail.sort((a,b)=>(a.c.diff||9)-(b.c.diff||9)); const pick=avail[0];
    try{
      cr.missionN=(cr.missionN||0)+1;
      M.applyMissionObj(loadMission(pick.c.content.ref));
      M.addForgeEnemies();   // ennemis ajustés après les forges libérées
      M.distortTerrain(M.corruptLevel());
      M.deployRoster(); M.mode="play"; M.startGame(); M.applyCarry();
      cr.geoReturn={nodeId:geoNode.id,cellId:pick.i}; M.geoPlay.inMission=true;
      const res=simMission(+(process.env.MAXT||40));
      missions++; if(res==="win")wins++; else if(res==="loss")losses++; else to++;
      if(M.geoPlay) M.runGeoEvents("debrief", ()=>{});   // débriefe : révèle les régions gâtées (ex. le Cœur après N victoires)
    }catch(e){ ERRORS.push(`[${tag} ${pick.c.name}] ${e.message}`); if(process.env.TRACE)console.log(e.stack); break; }
    if(M.geoPlay===null) break;
  }
  return { missions,wins,losses,to, actEnded:M.geoPlay===null, missionN:cr.missionN };
}

const CYCLES=+(process.env.CYCLES||3);
let tot={mis:0,win:0,loss:0,to:0}, perAct={};
for(let c=0;c<CYCLES;c++){ M.clearRosterProgress(camp.name);   // nouvelle lignée
  console.log(`\n=== Campagne ${c+1} (lignée neuve) ===`);
  let mn=0;
  for(let gi=0; gi<geoNodes.length; gi++){ const gn=geoNodes[gi];
    const geo0= gn.proc ? M.genGeoMap({act:gn.proc.act,regions:gn.proc.regions,seed:(7919*(c+1)+gi*104729)>>>0}) : loadGeo(gn.map);   // geoscape procédural par campagne
    const k= gn.proc ? ("acte"+gn.proc.act+" ("+gn.proc.regions+"r)") : gn.map;
    const o=runAct(`c${c+1}/${k}`, gn, geo0, mn); mn=o.missionN;
    tot.mis+=o.missions; tot.win+=o.wins; tot.loss+=o.losses; tot.to+=o.to;
    perAct[k]=perAct[k]||{mis:0,win:0,loss:0,to:0,ended:0,reg:geo0.cells.filter(c=>c.content&&c.content.kind==="mission").length}; perAct[k].mis+=o.missions; perAct[k].win+=o.wins; perAct[k].loss+=o.losses; perAct[k].to+=o.to; if(o.actEnded)perAct[k].ended++;
    console.log(`  ${k.padEnd(14)}: ${o.missions} missions  ${o.wins}W ${o.losses}L ${o.to}T${o.actEnded?"  — ACTE TERMINÉ":""}  (corruption finale ~${(Math.min(1,mn*0.06)).toFixed(2)})`);
  }
}
console.log(`\n==== BILAN ====`);
for(const k in perAct){ const a=perAct[k]; console.log(`  ${k.padEnd(11)}: ${a.mis} missions | ${a.win}W ${a.loss}L ${a.to}T | win ${a.mis?Math.round(100*a.win/a.mis):0}% | actes terminés ${a.ended}/${CYCLES}`); }
console.log(`  TOTAL      : ${tot.mis} missions | win ${tot.mis?Math.round(100*tot.win/tot.mis):0}% | timeouts ${tot.to}`);
console.log(`erreurs: ${ERRORS.length}`); ERRORS.slice(0,20).forEach(e=>console.log("  ! "+e));
console.log(tot.to===0&&ERRORS.length===0 ? "\n✓ maps jouables (0 timeout, 0 erreur)" : "\n⚠ à investiguer");
