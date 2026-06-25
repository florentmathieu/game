// Peuple un geoscape : une mission distincte par région, difficulté croissante avec la DISTANCE au
// camp (moins d'ennemis près du camp, plus loin). RIEN n'est verrouillé : tout est disponible, c'est
// juste plus dur en s'éloignant. Étoiles de difficulté ; le « Bastion » reste le pic (★★★★★).
const fs = require("fs"), path = require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const M = loadMesh();

const GEO = process.env.GEO || "geoscapes-mesh/acte1.json";
const geo = JSON.parse(fs.readFileSync(GEO, "utf8"));
const cells = geo.cells;
function cen(poly){let a=0,x=0,y=0;for(let i=0;i<poly.length;i++){const[x1,y1]=poly[i],[x2,y2]=poly[(i+1)%poly.length];const cr=x1*y2-x2*y1;a+=cr;x+=(x1+x2)*cr;y+=(y1+y2)*cr;}a*=0.5;return[x/(6*a),y/(6*a)];}
const isMission = c => c.content && c.content.kind === "mission" && c.type !== "camp";
const slug = s => s.normalize("NFD").replace(/[̀-ͯ]/g,"").toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/(^-|-$)/g,"")||"region";

// distance euclidienne au camp
const campC = cen(cells[geo.camp].poly);
const md = cells.map(c => isMission(c) ? Math.hypot(cen(c.poly)[0]-campC[0], cen(c.poly)[1]-campC[1]) : null);
const ds = md.filter(d=>d!=null); const dmin=Math.min(...ds), dmax=Math.max(...ds);
// étoiles 1..4 par distance (le Bastion est forcé à 5) ; ennemis = 2 + étoiles
function stars(i, isBastion){ if(isBastion) return 5; const t=dmax>dmin?(md[i]-dmin)/(dmax-dmin):0; return Math.max(1,Math.min(4,1+Math.floor(t*3.999))); }

const list = [{file:"mission-1.json", name:"Mission 1"}];
const report = [];
cells.forEach((c,i)=>{
  if(!isMission(c)){ return; }
  const isBastion = (c.name||"").toLowerCase().includes("bastion");
  const st = stars(i, isBastion);
  const en = 2 + st;                       // ★=3 … ★★★★★=7
  const pods = en<=4 ? 2 : 3;
  M.setBoardSize(13,10); M.setMove(3,2,2); M.setSeed(7000 + i*99991);
  let meta; try{ meta = M.genMission({archetype:"eliminate", podCount:pods, enemyCount:en, cover:0.30, podSpacing:4}); }
  catch(e){ console.log("ERR gen", c.name, e.message); return; }
  if(!meta){ console.log("no-mesh", c.name); return; }
  const obj = M.exportObj(); obj.name = c.name;
  const file = "terr-" + slug(c.name) + ".json";
  fs.writeFileSync(path.join("missions-mesh", file), JSON.stringify(obj));
  c.content.ref = file; c.diff = st; c.state = "available"; c.unlockedBy = [];   // RIEN de verrouillé
  list.push({file, name:c.name});
  report.push({d:md[i], line:`  ${"★".repeat(st)}${"·".repeat(5-st)} ${(c.name+"").padEnd(16)} dist ${md[i].toFixed(0).padStart(3)} -> ${meta.enemies} ennemis, ${meta.podCount} pods`});
});

fs.writeFileSync(GEO, JSON.stringify(geo));
fs.writeFileSync("missions-mesh/list.json", JSON.stringify(list));
console.log("Territoire peuplé (rien de verrouillé) :", geo.name);
report.sort((a,b)=>a.d-b.d).forEach(r=>console.log(r.line));
console.log(`\n${report.length} missions, toutes disponibles, difficulté par distance au camp.`);
