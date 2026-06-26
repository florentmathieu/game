// Joue des campagnes avec un roster DÉJÀ gradé (toutes les capacités A) et compte les activations.
const fs=require("fs"), path=require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const { makeActUnit } = require("./ai.cjs");
const M = loadMesh(); const actUnit = makeActUnit(M);
M.setAutoPromote((m,g,pair)=>"A");   // toujours la capacité

const geo0=JSON.parse(fs.readFileSync("geoscapes-mesh/acte1.json","utf8"));
const camp=JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8"));
const geoNode=camp.nodes.find(n=>n.type==="geoscape");
const loadMission=ref=>JSON.parse(fs.readFileSync(path.join("missions-mesh",ref),"utf8"));
// roster pré-gradé couvrant toutes les classes/capacités
const ROSTER=[ {name:"Stiff",cls:"sergent",xp:99,perks:["se1a","se2a","se3a"]},   // rally, taunt, holdline
               {name:"Merry",cls:"sapeur",xp:99,perks:["sa1a","sa2a","sa3a"]},     // smoke, breach, artificier
               {name:"Gizzard",cls:"assassin",xp:99,perks:["as1a","as2a"]},        // shadowstrike, vanish
               {name:"Bma",cls:"garde",xp:99,perks:["ga1a","ga2a"]} ];             // protect, wall

const COUNT={smoke:0,breach:0,shadow:0,rally:0,vanish:0,taunt:0,holdline:0,wall:0};
for(const k of ["Smoke","Breach","Shadow","Rally","Vanish","Taunt","Holdline","Wall"]){ const fn="exec"+k, orig=M[fn]; M[fn]=(...a)=>{ const r=orig(...a); if(r)COUNT[k.toLowerCase()]++; return r; }; }
const origDA=M.doAttack; // protect : compte les interceptions via le log "protège"
const origLog=null;

function refreshAP(team){for(const u of M.units)if(u.team===team&&u.hp>0){u.ap=M.AP_MAX;u.freeAvail=true;u.overwatch=false;u.reacted=false;u.bracing=false;}}
function sim(maxT){ M.mode="play"; M.over=false; M.lastOutcome=null; M.turn="player"; M.turnNum=1; let t=0,side="player";
  const live=()=>M.geoPlay&&M.geoPlay.inMission;
  while(t<maxT && live()){ if(side==="player"){M.turnNum=t+1;M.checkEnd();if(!live())break;} refreshAP(side);
    for(const u of M.units.slice()){ if(!live())break; if(u.team!==side||u.hp<=0)continue; if(side==="enemy"&&!M.enemyActive(u))continue; if(side==="player")M.refresh(); else M.computeEVis(); actUnit(u); if(live())M.checkEnd(); if(!live())break; }
    if(side==="enemy")t++; side=side==="player"?"enemy":"player"; }
  if(live())M.geoMissionEnd("Défaite");
  return M.lastOutcome||"timeout"; }

let ERR=[],totM=0,W=0,L=0,TO=0;
const RUNS=+(process.env.RUNS||4);
for(let run=0;run<RUNS;run++){
  const roster=ROSTER.map(m=>({name:m.name,cls:m.cls,xp:m.xp,perks:m.perks.slice()}));
  const cr={camp:{name:camp.name,nodes:camp.nodes},carry:{},roster,geoStates:{},potions:0,seen:new Set(),nodeId:geoNode.id};
  cr.geoStates[geoNode.id]=geo0.cells.map(c=>c.state||"locked"); M.campRun=cr;
  M.geoPlay={node:{id:geoNode.id,map:geoNode.map,endWhen:geoNode.endWhen,next:geoNode.next},map:JSON.parse(JSON.stringify(geo0)),inMission:false};
  let g=0;
  while(g++<30){ const st=cr.geoStates[geoNode.id];
    const avail=geo0.cells.map((c,i)=>({c,i})).filter(x=>x.c.content&&x.c.content.kind==="mission"&&st[x.i]==="available");
    if(!avail.length)break; avail.sort((a,b)=>(a.c.diff||9)-(b.c.diff||9)); const pick=avail[0];
    try{ M.applyMissionObj(loadMission(pick.c.content.ref)); M.deployRoster(); M.mode="play"; M.startGame();
      for(const u of M.units)if(u.team==="player"){const c=cr.carry[u.name];if(c!=null)u.hp=c>0?Math.min(u.max,c):u.max;}
      cr.geoReturn={nodeId:geoNode.id,cellId:pick.i}; M.geoPlay.inMission=true;
      const res=sim(40); totM++; if(res==="win")W++;else if(res==="loss")L++;else TO++;
    }catch(e){ ERR.push(`run${run} ${pick.c.name}: ${e.message}`); break; }
    if(M.geoPlay===null)break;
  }
}
console.log(`${RUNS} campagnes · ${totM} missions : ${W}W ${L}L ${TO}T · erreurs ${ERR.length}`);
console.log("activations de capacités :", JSON.stringify(COUNT));
ERR.slice(0,8).forEach(e=>console.log("  ! "+e));
