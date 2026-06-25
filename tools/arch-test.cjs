const { loadMesh } = require("./mesh-engine.cjs");
const M = loadMesh();
const archs=["eliminate","assassinate","rescue","defend","survive","extract"];
for(const a of archs){
  M.setBoardSize(13,10); M.setMove(3,2,2); M.setSeed(424242);
  let meta; try{meta=M.genMission({archetype:a,podCount:2,cover:0.30,podSpacing:4});}catch(e){console.log(a,"ERR",e.message);continue;}
  const U=M.units;
  const pl=U.filter(u=>u.team==="player").length;
  const en=U.filter(u=>u.team==="enemy").length;
  const hvt=U.filter(u=>u.hvt).length;
  const host=U.filter(u=>u.team==="neutral"&&u.hostage).length;
  const vip=U.filter(u=>u.team==="neutral"&&u.civ===false).length;
  const exitCells=M.cells.filter(c=>c.zone==="exit").length;
  const cm=M.curMission;
  console.log(`${a.padEnd(11)} | J${pl} E${en} hvt:${hvt} otage:${host} vip:${vip} exit:${exitCells} | obj=${cm&&cm.objective} surv=${cm&&cm.surviveTurns||"-"} extN=${cm&&cm.extractCount||"-"}`);
}
