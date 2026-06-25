const fs=require("fs");
const {loadMesh}=require("./mesh-engine.cjs"); const M=loadMesh();
const geo=JSON.parse(fs.readFileSync("geoscapes-mesh/acte1.json","utf8"));
const node={id:"geo",map:"acte1.json",endWhen:{kind:"key",name:"Bastion"},next:"fin"};
function setup(){ M.campRun={camp:{nodes:[node,{id:"fin",type:"text",text:"Fin",next:null}]},nodeId:"geo",from:"play",geoStates:{geo:geo.cells.map(c=>c.state||"locked")},carry:{},roster:[],potions:0,seen:new Set()};
  M.geoPlay={node,map:JSON.parse(JSON.stringify(geo)),inMission:true}; M.curMission={loot:1}; M.units=[]; M.over=true; }
const idx=name=>geo.cells.findIndex(c=>(c.name||"")===name);
const missionCells=()=>geo.cells.filter(c=>c.content&&c.content.kind==="mission");

setup(); const cBois=idx("Bois brule")<0?idx("Bois brûlé"):idx("Bois brûlé");
M.campRun.geoReturn={nodeId:"geo",cellId:cBois}; M.geoMissionEnd("Victoire !");
let st=M.campRun.geoStates.geo;
console.log("[region] Bois brule:", st[cBois], "| geoPlay actif:", M.geoPlay!==null, "| inMission:", M.geoPlay&&M.geoPlay.inMission,
  "| dispo restantes:", st.filter((s,i)=>geo.cells[i].content&&geo.cells[i].content.kind==="mission"&&s==="available").length);

setup(); const cGue=idx("Gué de l'aval"); M.campRun.geoReturn={nodeId:"geo",cellId:cGue}; M.geoMissionEnd("Defaite");
console.log("[defaite] Gue:", M.campRun.geoStates.geo[cGue], "| geoPlay actif:", M.geoPlay!==null);

setup(); const cBas=idx("Bastion"); M.campRun.geoReturn={nodeId:"geo",cellId:cBas}; M.geoMissionEnd("Victoire !");
console.log("[Bastion] state:", M.campRun.geoStates.geo[cBas], "| acte termine (geoPlay null):", M.geoPlay===null);
