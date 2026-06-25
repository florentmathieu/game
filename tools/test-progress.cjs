const {loadMesh}=require("./mesh-engine.cjs"); const M=loadMesh();
// parse OK if we got here
console.log("engine loaded OK; classes:", Object.keys(M.PERKS).join(","));
// XP award + grade detection
M.campRun={roster:[{name:"Stiff",cls:"sergent",xp:0,perks:[]},{name:"Merry",cls:"sapeur",xp:0,perks:[]}],carry:{}};
M.units=[{team:"player",name:"Stiff",hp:5,kills:2},{team:"player",name:"Merry",hp:5,kills:0},{team:"enemy",name:"x",hp:0}];
M.awardXp();
console.log("after 1 win: Stiff xp", M.campRun.roster[0].xp, "(grade", M.gradeFromXp(M.campRun.roster[0].xp)+")", "| Merry xp", M.campRun.roster[1].xp);
let promos=M.pendingPromotions();
console.log("pending promotions:", promos.map(p=>p.m.name+"@g"+p.grade).join(", ")||"none");
// choose perks
for(const p of promos){ const pair=M.PERKS[p.m.cls][p.grade]; p.m.perks.push(pair.A.id); }
console.log("Stiff perks:", M.campRun.roster[0].perks.join(","));
// second win -> more xp -> next grade
M.units=[{team:"player",name:"Stiff",hp:5,kills:3},{team:"player",name:"Merry",hp:5,kills:2},{team:"enemy",name:"x",hp:0}];
M.awardXp();
console.log("after 2 wins: Stiff xp", M.campRun.roster[0].xp, "grade", M.gradeFromXp(M.campRun.roster[0].xp), "| Merry xp", M.campRun.roster[1].xp, "grade", M.gradeFromXp(M.campRun.roster[1].xp));
promos=M.pendingPromotions(); console.log("pending now:", promos.map(p=>p.m.name+"@g"+p.grade).join(", ")||"none");
// perk effect on deploy: build two sergents, one with Cuirasse(+3hp), one plain
M.setBoardSize(8,6); M.setMove(3,2,2); M.setSeed(5); M.genMesh && M.genMesh();
const base=M.U("player","sergent",0,{name:"plain"});
const buffed=M.U("player","sergent",1,{name:"buff"}); M.applyPerkMods(buffed,["se1a","se2b"]);  // +3hp +4hp
console.log("perk effect: plain max", base.max, "vs buffed max", buffed.max, "(attendu +7 =", base.max+7+")");
