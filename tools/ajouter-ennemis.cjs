// Ajoute des ennemis à une mission écrite, en plaçant chacun sur une case VALIDE : praticable,
// libre, proche d'un ennemi existant (il rejoint sa poche) et invisible depuis les cases de
// déploiement au tour 1 — la même contrainte que la génération procédurale.
//   node tools/ajouter-ennemis.cjs <mission.json> <n> [classe]
const fs=require("fs"), path=require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const M=loadMesh();
const [,,ref,nStr,clsArg]=process.argv;
if(!ref){ console.error("usage: ajouter-ennemis.cjs <missions-mesh/x.json> <n> [classe]"); process.exit(1); }
const n=+(nStr||1);
const p=ref.includes("/")?ref:path.join("missions-mesh",ref);
const m=JSON.parse(fs.readFileSync(p,"utf8"));
M.applyMissionObj(m);
const occup=new Set((m.units||[]).map(u=>u.cell));
const ennemis=(m.units||[]).filter(u=>u.team==="enemy");
const joueurs=(m.units||[]).filter(u=>u.team==="player").map(u=>u.cell);
const zonesDep=(Array.isArray(m.deployZone)?m.deployZone:[]).concat(joueurs);
const vuAuDepart=id=>zonesDep.some(d=>M.hops(d,id)<=8&&M.los(d,id));
const ajoutes=[];
for(let k=0;k<n;k++){
  // on part de l'ennemi le moins entouré pour ne pas empiler la même poche
  const src=ennemis.concat(ajoutes).sort((a,b)=>
    (ajoutes.filter(x=>M.hops(x.cell,a.cell)<=2).length)-(ajoutes.filter(x=>M.hops(x.cell,b.cell)<=2).length))[0];
  let cible=null;
  for(let r=1;r<=4&&cible==null;r++)
    for(const c of M.cells){
      if(M.hops(src.cell,c.id)!==r)continue;
      if(!M.passable(c.id)||occup.has(c.id))continue;
      if(vuAuDepart(c.id))continue;
      cible=c.id; break; }
  if(cible==null){ console.error("  ⚠ pas de case libre et cachée pour le n°"+(k+1)); break; }
  const cls=clsArg||src.cls;
  const u={team:"enemy",cls,cell:cible};
  if(src.pod!==undefined)u.pod=src.pod;
  if(src.asleep)u.asleep=true;
  m.units.push(u); occup.add(cible); ajoutes.push(u);
}
fs.writeFileSync(p, JSON.stringify(m));
console.log(`${path.basename(p)} : +${ajoutes.length} (${ajoutes.map(u=>u.cls+"@"+u.cell).join(", ")}) → ${m.units.filter(u=>u.team==="enemy").length} ennemis`);
