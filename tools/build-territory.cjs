// Peuple un geoscape : une mission distincte par région, difficulté croissante avec l'éloignement
// du camp (moins d'ennemis près du camp, plus loin), étoiles de difficulté, déverrouillage en chaîne.
const fs = require("fs"), path = require("path");
const { loadMesh } = require("./mesh-engine.cjs");
const M = loadMesh();

const GEO = process.env.GEO || "geoscapes-mesh/acte1.json";
const geo = JSON.parse(fs.readFileSync(GEO, "utf8"));
const cells = geo.cells;

// --- profondeur depuis le camp via les chaînes de déverrouillage (forward edges A->B si B.unlockedBy contient A) ---
const isMission = c => c.content && c.content.kind === "mission" && c.type !== "camp";
const depth = cells.map(()=>0);
let frontier = [];
cells.forEach((c,i)=>{ if(isMission(c) && c.state==="available"){ depth[i]=1; frontier.push(i); } });
while(frontier.length){ const next=[]; for(const a of frontier){
  cells.forEach((c,j)=>{ if(isMission(c) && (c.unlockedBy||[]).includes(a) && depth[j]===0){ depth[j]=depth[a]+1; next.push(j); } }); }
  frontier=next; }

// --- barème de difficulté par profondeur (calibré : ~E3 facile … E6-7 dur) ---
function tier(d, isBastion){
  if(isBastion) return {en:7, pods:3, stars:5};
  const T=[null,{en:3,pods:2,stars:1},{en:4,pods:2,stars:2},{en:5,pods:3,stars:3},{en:6,pods:3,stars:4}];
  return T[Math.max(1,Math.min(4,d))]; }
const slug = s => s.normalize("NFD").replace(/[̀-ͯ]/g,"").toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/(^-|-$)/g,"")||"region";

const list = [{file:"mission-1.json", name:"Mission 1"}];
const report = [];
cells.forEach((c,i)=>{
  if(!isMission(c)) return;
  const isBastion = (c.name||"").toLowerCase().includes("bastion");
  const t = tier(depth[i]||1, isBastion);
  M.setBoardSize(13,10); M.setMove(3,2,2); M.setSeed(7000 + i*99991);
  let meta; try{ meta = M.genMission({archetype:"eliminate", podCount:t.pods, enemyCount:t.en, cover:0.30, podSpacing:4}); }
  catch(e){ console.log("ERR gen", c.name, e.message); return; }
  if(!meta){ console.log("no-mesh", c.name); return; }
  const obj = M.exportObj(); obj.name = c.name;
  const file = "terr-" + slug(c.name) + ".json";
  fs.writeFileSync(path.join("missions-mesh", file), JSON.stringify(obj));
  c.content.ref = file; c.diff = t.stars;
  list.push({file, name:c.name});
  report.push(`  ${"★".repeat(t.stars)} ${(c.name+"").padEnd(18)} d${depth[i]} -> ${meta.enemies} ennemis, ${meta.podCount} pods, ${meta.cells}c  (${file})`);
});

fs.writeFileSync(GEO, JSON.stringify(geo));
fs.writeFileSync("missions-mesh/list.json", JSON.stringify(list));
console.log("Territoire peuplé :", geo.name);
report.sort().forEach(r=>console.log(r));
console.log(`\n${report.length} missions générées + geoscape mis à jour (${GEO}) + missions-mesh/list.json (${list.length} entrées).`);
