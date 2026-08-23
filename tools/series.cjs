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
  const live=()=>M.geoPlay&&M.geoPlay.inMission;
  while(t<maxT&&live()){if(side==="player"){M.turnNum=t+1;M.checkEnd();if(!live())break;}refreshAP(side);
    for(const u of M.units.slice()){if(!live())break;if(u.team!==side||u.hp<=0)continue;if(side==="enemy"&&!M.enemyActive(u))continue;if(side==="player")M.refresh();else M.computeEVis();actUnit(u);if(live())M.checkEnd();if(!live())break;}
    if(side==="enemy")t++;side=side==="player"?"enemy":"player";}
  if(live())M.geoMissionEnd("Défaite");return M.lastOutcome||"timeout";}
function runCampaign(seedOff){ M.clearRosterProgress(camp.name);
  const cr={camp:{name:camp.name,nodes:camp.nodes},carry:{},roster:camp.roster.map(m=>({name:m.name,cls:m.cls,xp:0,perks:[],stress:0,fatigue:0,special:m.special!==false,dead:false})),geoStates:{},potions:0,seen:new Set(),nodeId:geoNode.id};
  cr.geoStates[geoNode.id]=geo0.cells.map(c=>c.state||"locked"); M.campRun=cr;
  M.geoPlay={node:{id:geoNode.id,map:geoNode.map,endWhen:geoNode.endWhen,next:geoNode.next},map:JSON.parse(JSON.stringify(geo0)),inMission:false};
  let W=0,L=0,n=0; M.reseed(seedOff*2654435761+7);
  while(n++<14){ const st=cr.geoStates[geoNode.id];
    const avail=geo0.cells.map((c,i)=>({c,i})).filter(x=>x.c.content&&x.c.content.kind==="mission"&&st[x.i]==="available");
    if(!avail.length)break; avail.sort((a,b)=>(a.c.diff||9)-(b.c.diff||9)); const pick=avail[0];
    M.applyMissionObj(loadMission(pick.c.content.ref)); M.deployRoster();
    if(!M.units.some(u=>u.team==="player")) break;   // personne de prêt
    M.mode="play"; M.startGame(); for(const u of M.units)if(u.team==="player"){const c=cr.carry[u.name];if(c!=null)u.hp=c>0?Math.min(u.max,c):u.max;}
    cr.geoReturn={nodeId:geoNode.id,cellId:pick.i}; M.geoPlay.inMission=true;
    const res=sim(40); if(res==="win")W++;else L++;
    if(M.geoPlay===null)break;
  }
  const dead=cr.roster.filter(m=>m.dead).map(m=>m.name);
  const alive=cr.roster.filter(m=>!m.dead).map(m=>m.name+(m.special!==false?"*":""));
  return {missions:W+L,W,L,dead,alive,act:M.geoPlay===null}; }
let tDead=0,tMis=0,tW=0;
for(let i=0;i<6;i++){ const o=runCampaign(i+1); tDead+=o.dead.length; tMis+=o.missions; tW+=o.W;
  console.log(`Camp ${i+1}: ${o.missions} missions (${o.W}W ${o.L}L)${o.act?" ACTE TERMINÉ":""} | morts: ${o.dead.length?o.dead.join(", "):"aucune"} | survivants: ${o.alive.join(", ")}`); }
console.log(`\nTotal: ${tMis} missions, ${Math.round(100*tW/tMis)}% victoires, ${tDead} morts sur 6 campagnes (recrues mortelles : 3/campagne).`);
