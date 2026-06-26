const fs=require("fs"), path=require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh(); const actUnit = makeActUnit(M); M.setAutoPromote((m,g,p)=>"A");
const geo0=JSON.parse(fs.readFileSync("geoscapes-mesh/acte1.json","utf8"));
const camp=JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8"));
const geoNodes=camp.nodes.filter(n=>n.type==="geoscape");
const loadMission=ref=>JSON.parse(fs.readFileSync(path.join("missions-mesh",ref),"utf8"));
function refreshAP(t){for(const u of M.units)if(u.team===t&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function sim(maxT){M.mode="play";M.over=false;M.lastOutcome=null;M.turn="player";M.turnNum=1;let t=0,side="player";
  const live=()=>M.geoPlay&&M.geoPlay.inMission;
  while(t<maxT&&live()){if(side==="player"){M.turnNum=t+1;M.checkEnd();if(!live())break;}refreshAP(side);
    for(const u of M.units.slice()){if(!live())break;if(u.team!==side||u.hp<=0)continue;if(side==="enemy"&&!M.enemyActive(u))continue;if(side==="player")M.refresh();else M.computeEVis();actUnit(u);if(live())M.checkEnd();if(!live())break;}
    if(side==="enemy")t++;side=side==="player"?"enemy":"player";}
  if(live())M.geoMissionEnd("Défaite");return M.lastOutcome||"timeout";}
const show=()=>M.campRun.roster.map(m=>`${m.name}${m.dead?"✝":""} g${(m.perks||[]).length}/xp${m.xp}`).join("  ");
// campRun (Acte 1)
const cr={camp:{name:camp.name,nodes:camp.nodes},carry:{},winCount:0,roster:camp.roster.map(m=>({name:m.name,cls:m.cls,xp:0,perks:[],stress:0,fatigue:0,special:m.special!==false,mortalAfter:m.mortalAfter||null,dead:false})),geoStates:{},potions:0,seen:new Set()};
M.campRun=cr;
function playAct(node,label){ cr.geoStates[node.id]=geo0.cells.map(c=>c.state||"locked");
  M.geoPlay={node:{id:node.id,map:node.map,endWhen:node.endWhen,next:node.next},map:JSON.parse(JSON.stringify(geo0)),inMission:false};
  let n=0,W=0,L=0;
  while(n++<20){ const st=cr.geoStates[node.id];
    const avail=geo0.cells.map((c,i)=>({c,i})).filter(x=>x.c.content&&x.c.content.kind==="mission"&&(st[x.i]==="available"||st[x.i]==="lost"));
    if(!avail.length)break; avail.sort((a,b)=>(a.c.diff||9)-(b.c.diff||9)); const pick=avail[0];
    M.applyMissionObj(loadMission(pick.c.content.ref)); M.deployRoster(); if(!M.units.some(u=>u.team==="player"))break;
    M.mode="play"; M.startGame(); for(const u of M.units)if(u.team==="player"){const c=cr.carry[u.name];if(c!=null)u.hp=c>0?Math.min(u.max,c):u.max;}
    cr.geoReturn={nodeId:node.id,cellId:pick.i}; M.geoPlay.inMission=true;
    const res=sim(40); if(res==="win")W++;else L++;
    if(M.geoPlay===null)break;   // acte terminé (clé nettoyée)
  }
  console.log(`${label}: ${W}W ${L}L | roster: ${show()}`); return M.geoPlay===null; }
const a1=playAct(geoNodes[0],"ACTE 1");
const xpAfter1=cr.roster.reduce((s,m)=>s+(m.xp||0),0), dead1=cr.roster.filter(m=>m.dead).length;
// transition vers Acte 2 : MÊME campRun/roster, nouveau nœud geoscape -> territoire frais
const a2=playAct(geoNodes[1],"ACTE 2");
const xpAfter2=cr.roster.reduce((s,m)=>s+(m.xp||0),0), dead2=cr.roster.filter(m=>m.dead).length;
console.log(`\nPersistance : XP roster ${xpAfter1} -> ${xpAfter2} (continue:${xpAfter2>=xpAfter1}) | morts ${dead1} -> ${dead2} (conservées:${dead2>=dead1})`);
console.log(`Territoire Acte 2 frais : geoStates distincts (acte1:${cr.geoStates[geoNodes[0].id].filter(s=>s==="cleared").length} nettoyées, acte2:${cr.geoStates[geoNodes[1].id].filter(s=>s==="cleared").length} nettoyées)`);
