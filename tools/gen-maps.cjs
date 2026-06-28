// Régénère les maps de mission pour refléter la DISTORSION PROGRESSIVE de la campagne.
//   - début acte 1 : carrés, peu distordus, quelques sections hexagonales
//   - fin   acte 1 : plus de pentagones (≤20 %), distorsion modérée
//   - acte 2        : mélange + distorsion croissants, plafonnés (critère max) pour rester jouable
// La forme vient de `infl` (sections de carrés/hexa/pentagones) + `dist` (gigue). Le contenu
// (escouade, ennemis, objectif, bonus, butin) est REPRIS de la map existante pour préserver la difficulté.
const fs = require("fs"), path = require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const M = loadMesh();

const lerp = (a,b,t)=>a+(b-a)*t;
const slug = s => s.normalize("NFD").replace(/[̀-ͯ]/g,"").toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/(^-|-$)/g,"")||"region";
const readJSON = f => JSON.parse(fs.readFileSync(f,"utf8"));

// ===== profil de distorsion =====
// progress p ∈ [0,1] : acte 1 occupe [0,0.5], acte 2 occupe [0.5,1].
// Au sein d'un acte, l'étoile de difficulté (1..5) sert d'échelle d'avancée.
function progress(act, star){ const t=(star-1)/4; return act===1 ? t*0.5 : 0.5 + t*0.5; }
// fractions cibles carré/hexa/pentagone (sommes ≈ 1)
function fracs(p){
  if(p<=0.5){ const t=p/0.5; return { sq:lerp(0.80,0.40,t), hx:lerp(0.20,0.40,t), pt:lerp(0.00,0.20,t) }; }
  const t=(p-0.5)/0.5; return { sq:lerp(0.40,0.15,t), hx:lerp(0.40,0.40,t), pt:lerp(0.20,0.45,t) };
}
const DIST_MAX = 48;           // CRITÈRE MAX de gigue (jouabilité) — l'étalon
const PENT_MAX_ACT1 = 0.20;    // contrainte explicite : ≤20 % de pentagones en fin d'acte 1
function distPct(p){ return Math.round(lerp(10, DIST_MAX, p)); }

// champ lisse (basses fréquences) → sections contiguës plutôt que bruit par case
function field(c,r,seed){ const a=Math.sin(c*0.55+seed*1.7)+Math.cos(r*0.6-seed*0.9), b=Math.sin((c+r)*0.4+seed*2.3); return ((a+b)/3+1)/2; }
function buildInfl(cols,rows,p,seed){
  const f=fracs(p); let pt=f.pt;
  if(p<=0.5) pt=Math.min(pt, PENT_MAX_ACT1);   // contrainte explicite acte 1
  // seuils par QUANTILE du champ → fractions exactes tout en gardant des sections contiguës
  // (le champ étant lisse, les valeurs basses se regroupent → une région carrés, etc.)
  const vals=[]; for(let r=0;r<rows;r++)for(let c=0;c<cols;c++) vals.push(field(c,r,seed));
  const sorted=vals.slice().sort((a,b)=>a-b); const q=t=>sorted[Math.min(sorted.length-1,Math.floor(t*sorted.length))];
  const tSq=q(f.sq), tHx=q(1-pt);   // [<tSq]=carré, [<tHx]=hexa, sinon pentagone
  const grid=[];
  for(let r=0;r<rows;r++){ const row=[]; for(let c=0;c<cols;c++){ const n=field(c,r,seed);
    row.push( n<tSq ? "square" : n<tHx ? "hex" : "pentagon" ); } grid.push(row); }
  return grid;
}
function pentFraction(grid){ let n=0,t=0; for(const row of grid)for(const v of row){t++; if(v==="pentagon")n++;} return n/t; }

// ===== connectivité (jouabilité) : toutes les cases passables d'un seul tenant =====
function connectivityOK(){
  const pass=M.cells.filter(c=>M.passable(c.id)).map(c=>c.id); if(!pass.length)return false;
  const seen=new Set([pass[0]]), q=[pass[0]];
  while(q.length){ const id=q.pop(); for(const nb of M.cells[id].nb){ if(M.passable(nb)&&!seen.has(nb)){ seen.add(nb); q.push(nb); } } }
  return seen.size===pass.length;
}
function centroidsOK(){ return M.cells.every(c=>isFinite(c.cx)&&isFinite(c.cy)&&c.poly.length>=3); }

// taille du plateau selon l'étoile : plus c'est dur, plus la carte est grande (place pour plus d'ennemis + meilleure répartition)
function sizeFor(star){ const s=Math.max(1,Math.min(5,star||1)); const cols=10+s; return { cols, rows:Math.max(7,Math.round(cols*0.72)) }; }
// ===== régénère une map en préservant son contenu =====
function regen(oldObj, p, seed0, enemyClasses, star){
  const sz=sizeFor(star); const cols=sz.cols, rows=sz.rows;
  const ou=oldObj.units||[];
  const players=ou.filter(u=>u.team==="player").length||4;
  const enemies=ou.filter(u=>u.team==="enemy").length||5;
  const pods=Math.max(1,new Set(ou.filter(u=>u.team==="enemy").map(u=>u.pod||0)).size);
  const P={ archetype:oldObj.objective||"eliminate", squad:players, enemyCount:enemies, podCount:pods,
            cover:0.30, podSpacing:4, enemyClasses, surviveTurns:oldObj.surviveTurns, extractCount:oldObj.extractCount };
  let meta=null;
  for(let attempt=0; attempt<6; attempt++){ const seed=(seed0 + attempt*1013904223)>>>0;
    M.setMove(3,2,2); M.setBoardSize(cols,rows);
    M.setInfl(buildInfl(cols,rows,p,seed)); M.setDist(distPct(p)); M.setDens(44); M.setSeed(seed);
    try{ meta=M.genMission(P); }catch(e){ meta=null; }
    if(meta && connectivityOK() && centroidsOK()) break; meta=null;
  }
  if(!meta) throw new Error("génération échouée (connectivité) "+oldObj.name);
  const obj=M.exportObj(); obj.name=oldObj.name;
  for(const k of ["bonus","objective","surviveTurns","extractCount","exitZone","protect","fullheal","loot","triggers"])
    if(oldObj[k]!=null) obj[k]=oldObj[k];
  // stress-test : la distorsion runtime ne doit pas casser l'adjacence ni la connectivité
  const lvl=Math.min(1,p+0.3); const before=M.cells.map(c=>c.nb.slice().sort((a,b)=>a-b));
  M.distortTerrain(lvl);
  const adjOK=M.cells.every((c,i)=>{const n=c.nb.slice().sort((a,b)=>a-b); return n.length===before[i].length&&n.every((x,j)=>x===before[i][j]);});
  const stress=adjOK&&connectivityOK()&&centroidsOK();
  return { obj, meta, stress, cells:obj.cells.length, players, enemies, pods };
}

// ===== pilote =====
const ENEMY_A1 = star => star>=4 ? ["garde","archer","brute","shieldbearer"] : ["garde","archer","brute"];
// acte 2 : escalade MODÉRÉE (mage ennemi + porteur de bouclier introduits mais dilués pour
// rester jouable malgré la distorsion max). emage ~1/5 au cœur de l'acte, jamais en tête de liste.
const ENEMY_A2 = star =>
  star>=5 ? ["archer","brute","shieldbearer","emage"] :
  star>=3 ? ["garde","archer","brute","shieldbearer","emage"] :
            ["garde","archer","brute","shieldbearer"];

const report=[]; const listSet=new Map();
function note(o){ report.push(o); }

// — Prologue (mission-1.json) : tout début, p=0 —
try{ const old=readJSON("missions-mesh/mission-1.json"); const r=regen(old,0,7001,["garde","archer"],1);
  fs.writeFileSync("missions-mesh/mission-1.json", JSON.stringify(r.obj)); listSet.set("mission-1.json","Mission 1");
  note({act:0,star:1,name:"Prologue",file:"mission-1.json",p:0,dist:distPct(0),...metaInfo(r)});
}catch(e){ note({err:"mission-1: "+e.message}); }

// — Acte 1 : régénère en place (mêmes fichiers, refs geoscape inchangées) —
const a1=readJSON("geoscapes-mesh/acte1.json");
a1.cells.forEach((c,i)=>{ if(!(c.content&&c.content.kind==="mission"))return; const ref=c.content.ref, star=c.diff||1, p=progress(1,star);
  try{ const old=readJSON(path.join("missions-mesh",ref)); const r=regen(old,p,9001+i*131,ENEMY_A1(star),star);
    fs.writeFileSync(path.join("missions-mesh",ref), JSON.stringify(r.obj)); listSet.set(ref,c.name);
    note({act:1,star,name:c.name,file:ref,p:+p.toFixed(3),dist:distPct(p),...metaInfo(r)});
  }catch(e){ note({err:"A1 "+c.name+": "+e.message}); }
});

// — Acte 2 : fichiers PROPRES (plus distordus), repointe le geoscape —
const a2=readJSON("geoscapes-mesh/acte2.json");
a2.cells.forEach((c,i)=>{ if(!(c.content&&c.content.kind==="mission"))return; const star=c.diff||1, p=progress(2,star);
  const oldref=c.content.ref; const isCoeur=(c.name||"").toLowerCase().includes("ur de la faille");
  const newref= isCoeur ? "terr-faille-coeur.json" : "terr-faille-"+slug(c.name)+".json";
  try{ const old=readJSON(path.join("missions-mesh",oldref)); const r=regen(old,p,21001+i*149,ENEMY_A2(star),star);
    fs.writeFileSync(path.join("missions-mesh",newref), JSON.stringify(r.obj));
    c.content.ref=newref; listSet.set(newref,c.name);
    note({act:2,star,name:c.name,file:newref,p:+p.toFixed(3),dist:distPct(p),...metaInfo(r)});
  }catch(e){ note({err:"A2 "+c.name+": "+e.message}); }
});
fs.writeFileSync("geoscapes-mesh/acte2.json", JSON.stringify(a2));

// — list.json : conserve mission-1 en tête, ajoute tout le reste —
const existing=readJSON("missions-mesh/list.json");
for(const e of existing) if(!listSet.has(e.file)) listSet.set(e.file, e.name);
const list=[...listSet.entries()].map(([file,name])=>({file,name}));
list.sort((a,b)=>a.file==="mission-1.json"?-1:b.file==="mission-1.json"?1:a.file.localeCompare(b.file));
fs.writeFileSync("missions-mesh/list.json", JSON.stringify(list));

function metaInfo(r){ return { cells:r.cells, sq_hx_pt:fracStr(r.obj.form.infl), J:r.players, E:r.enemies, pods:r.pods, stress:r.stress?"ok":"KO" }; }
function fracStr(grid){ let s=0,h=0,p=0,t=0; for(const row of grid)for(const v of row){t++; if(v==="square")s++;else if(v==="hex")h++;else p++;} return `${Math.round(100*s/t)}/${Math.round(100*h/t)}/${Math.round(100*p/t)}`; }

// ===== rapport =====
console.log("acte | ★ | p     | dist | cellules | carré/hex/pent | J/E/pods | stress | map");
for(const o of report){ if(o.err){ console.log("  !! "+o.err); continue; }
  console.log(`  ${o.act}  | ${o.star} | ${String(o.p).padEnd(5)} |  ${String(o.dist).padStart(2)}  |   ${String(o.cells).padStart(3)}    |    ${o.sq_hx_pt.padEnd(8)}   | ${o.J}/${o.E}/${o.pods}    |  ${o.stress.padEnd(2)}   | ${o.name} (${o.file})`); }
const errs=report.filter(o=>o.err).length, koStress=report.filter(o=>o.stress==="KO").length;
const a1pent=report.filter(o=>o.act===1).map(o=>+o.sq_hx_pt.split("/")[2]);
console.log(`\n${report.filter(o=>!o.err).length} maps régénérées | erreurs:${errs} | stress KO:${koStress} | pent max acte1: ${a1pent.length?Math.max(...a1pent):0}%`);
