// Trace une partie : ordre des régions (facile->dur), résultat, et grade du roster au moment d'attaquer.
const fs=require("fs"), path=require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh(); const actUnit = makeActUnit(M);
M.setAutoPromote((m,g,pair)=>{ const s=p=>{const x=(p&&p.mod)||{};return (x.hp||0)+(x.dmg||0)*1.3+(x.mob||0)*1.6+(x.range||0)*1.3+(x.aim||0)*0.07+(x.shieldBlock||0)*0.06+(x.parry||0)*0.06+(x.crackers||0);}; return s(pair.A)>=s(pair.B)?"A":"B"; });
const geo0=JSON.parse(fs.readFileSync("geoscapes-mesh/acte1.json","utf8"));
const camp=JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8"));
const geoNode=camp.nodes.find(n=>n.type==="geoscape");
const loadMission=ref=>JSON.parse(fs.readFileSync(path.join("missions-mesh",ref),"utf8"));
const alive=t=>M.units.some(u=>u.team===t&&u.hp>0);
function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function sim(maxT){ M.mode="play";M.over=false;M.lastOutcome=null;M.turn="player";M.turnNum=1;let t=0,side="player";
  while(t<maxT&&!M.over){ if(side==="player"){M.turnNum=t+1;M.checkEnd();if(M.over)break;} refreshAP(side);
    for(const u of M.units.slice()){if(M.over)break;if(u.team!==side||u.hp<=0)continue;if(side==="enemy"&&!M.enemyActive(u))continue;if(side==="player")M.refresh();else M.computeEVis();actUnit(u);M.checkEnd();if(M.over)break;}
    if(side==="enemy")t++;side=side==="player"?"enemy":"player";}
  return M.over?(M.lastOutcome||"loss"):"timeout"; }

M.clearRosterProgress(camp.name);
for(let run=1;run<=2;run++){
  const roster=(camp.roster||[]).map(m=>({name:m.name,cls:m.cls,xp:m.xp||0,perks:[]}));
  const saved=M.loadRosterProgress(camp.name); if(saved)for(const m of roster){const s=saved.find(x=>x.name===m.name&&x.cls===m.cls);if(s){m.xp=s.xp||0;m.perks=(s.perks||[]).slice();}}
  const cr={camp:{name:camp.name,nodes:camp.nodes},carry:{},roster,geoStates:{},potions:0,seen:new Set(),nodeId:geoNode.id};
  cr.geoStates[geoNode.id]=geo0.cells.map(c=>c.state||"locked"); M.campRun=cr;
  M.geoPlay={node:{id:geoNode.id,map:geoNode.map,endWhen:geoNode.endWhen,next:geoNode.next},map:JSON.parse(JSON.stringify(geo0)),inMission:false};
  console.log(`\n--- Partie ${run} (grades au départ: ${roster.map(m=>"g"+(m.perks||[]).length).join("/")}) ---`);
  let guard=0;
  while(guard++<30){ const st=cr.geoStates[geoNode.id];
    const avail=geo0.cells.map((c,i)=>({c,i})).filter(x=>x.c.content&&x.c.content.kind==="mission"&&st[x.i]==="available");
    if(!avail.length)break; avail.sort((a,b)=>(a.c.diff||9)-(b.c.diff||9)); const pick=avail[0];
    const grades=cr.roster.map(m=>"g"+(m.perks||[]).length).join("/");
    M.applyMissionObj(loadMission(pick.c.content.ref)); M.deployRoster(); M.mode="play"; M.startGame();
    for(const u of M.units)if(u.team==="player"){const c=cr.carry[u.name];if(c!=null)u.hp=c>0?Math.min(u.max,c):u.max;}
    cr.geoReturn={nodeId:geoNode.id,cellId:pick.i}; M.geoPlay.inMission=true;
    const res=sim(40); if(!M.over)M.geoMissionEnd("Défaite");
    console.log(`  ${"★".repeat(pick.c.diff||0).padEnd(5)} ${(pick.c.name+"").padEnd(16)} roster ${grades} -> ${res.toUpperCase()}`);
    if(M.geoPlay===null){console.log("  >>> ACTE TERMINÉ (Bastion pris)");break;}
  }
}
