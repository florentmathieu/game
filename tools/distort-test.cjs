// Vérifie que la distorsion du terrain préserve l'adjacence (les arêtes partagées restent jointes)
// et que los/reach fonctionnent toujours sur un maillage tordu.
const { loadMesh } = require("./mesh-engine.cjs");
const M = loadMesh();

function snapshotAdj(){ return M.cells.map(c=>c.nb.slice().sort((a,b)=>a-b)); }
function sameAdj(a,b){ if(a.length!==b.length)return false;
  for(let i=0;i<a.length;i++){ if(a[i].length!==b[i].length)return false;
    for(let j=0;j<a[i].length;j++)if(a[i][j]!==b[i][j])return false; } return true; }

let fails=0;
for(const L of [0.18, 0.5, 1.0]){
  M.setSeed(1234); M.setBoardSize(); M.genMesh(M.cells); // regen pas dispo : on régénère via genMission
  M.genMission({}); // construit un maillage propre
  const before=snapshotAdj();
  const n=M.cells.length;
  // distorsion
  M.set_dummy; // no-op
  M.distortTerrain(L);
  const after=snapshotAdj();
  const preserved=sameAdj(before,after);
  // los/reach toujours fonctionnels ?
  let losOk=true, reachOk=true;
  try{ const a=0, b=Math.min(n-1, 5); M.los(a,b); }catch(e){ losOk=false; }
  try{ const u=M.units.find(x=>x.hp>0); if(u){ const d=M.reach(u); reachOk = d && typeof d==="object"; } }catch(e){ reachOk=false; }
  // centroïdes recalculés (pas de NaN)
  const nanC=M.cells.some(c=>!isFinite(c.cx)||!isFinite(c.cy));
  console.log(`L=${L}: cells=${n} adjPreserved=${preserved} losOk=${losOk} reachOk=${reachOk} nanCentroid=${nanC}`);
  if(!preserved||!losOk||!reachOk||nanC)fails++;
}
console.log(fails?`\n!! ${fails} échec(s)`:"\nOK — distorsion sûre");
process.exit(fails?1:0);
