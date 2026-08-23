const fs=require("fs"), path=require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh(); const actUnit = makeActUnit(M); M.setAutoPromote((m,g,p,quoi)=>quoi==="track"?(m.cls==="soldat"?"officer":"veteran"):"A");
const geo0=JSON.parse(fs.readFileSync("geoscapes-mesh/acte1.json","utf8"));
const camp=JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8"));
const geoNode=camp.nodes.find(n=>n.type==="geoscape");
const loadMission=ref=>JSON.parse(fs.readFileSync(path.join("missions-mesh",ref),"utf8"));
function refreshAP(t){for(const u of M.units)if(u.team===t&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function sim(maxT){M.mode="play";M.over=false;M.lastOutcome=null;M.turn="player";M.turnNum=1;let t=0,side="player";
  const live=()=>M.geoPlay&&M.geoPlay.inMission;   // le moteur clôt la mission tout seul (end->campEnd->geoMissionEnd)
  while(t<maxT&&live()){if(side==="player"){M.turnNum=t+1;M.checkEnd();if(!live())break;}refreshAP(side);
    for(const u of M.units.slice()){if(!live())break;if(u.team!==side||u.hp<=0)continue;if(side==="enemy"&&!M.enemyActive(u))continue;if(side==="player")M.refresh();else M.computeEVis();actUnit(u);if(live())M.checkEnd();if(!live())break;}
    if(side==="enemy")t++;side=side==="player"?"enemy":"player";}
  if(live())M.geoMissionEnd("Défaite");   // timeout
  return M.lastOutcome||"timeout";}

M.clearRosterProgress(camp.name);
// build run (comme startCampaign)
const cr={camp:{name:camp.name,nodes:camp.nodes},carry:{},roster:camp.roster.map(m=>({name:m.name,cls:m.cls,xp:0,perks:[],stress:0,fatigue:0,special:m.special!==false,dead:false})),geoStates:{},potions:0,seen:new Set(),nodeId:geoNode.id};
cr.geoStates[geoNode.id]=geo0.cells.map(c=>c.state||"locked"); M.campRun=cr;
M.geoPlay={node:{id:geoNode.id,map:geoNode.map,endWhen:geoNode.endWhen,next:geoNode.next},map:JSON.parse(JSON.stringify(geo0)),inMission:false};
const show=()=>cr.roster.map(m=>`${m.name}${m.special?"*":""} ${m.dead?"✝":"F"+Math.round(m.fatigue)+"/S"+Math.round(m.stress)+((m.fatigue>=100||m.stress>=100)?"⛔":"")}`).join("  ");
console.log("départ:", show());
let n=0;
while(n++<12){ const st=cr.geoStates[geoNode.id];
  const avail=geo0.cells.map((c,i)=>({c,i})).filter(x=>x.c.content&&x.c.content.kind==="mission"&&st[x.i]==="available");
  if(!avail.length){console.log("(plus de régions disponibles)");break;}
  avail.sort((a,b)=>(a.c.diff||9)-(b.c.diff||9)); const pick=avail[0];
  M.applyMissionObj(loadMission(pick.c.content.ref)); M.deployRoster();
  const deployed=M.units.filter(u=>u.team==="player").map(u=>u.name);
  if(!deployed.length){console.log(`mission ${n} (${pick.c.name}) : AUCUN soldat prêt — repli`); break;}
  M.mode="play"; M.startGame(); for(const u of M.units)if(u.team==="player"){const c=cr.carry[u.name];if(c!=null)u.hp=c>0?Math.min(u.max,c):u.max;}
  cr.geoReturn={nodeId:geoNode.id,cellId:pick.i}; M.geoPlay.inMission=true;
  const res=sim(40);
  console.log(`#${n} ${("★".repeat(pick.c.diff||0)).padEnd(5)} ${(pick.c.name).padEnd(15)} [${deployed.join(",")}] -> ${res.toUpperCase()}`);
  console.log("    ", show());
  if(M.geoPlay===null){console.log(">>> acte terminé");break;}
}
