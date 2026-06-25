// Génère des missions avec le générateur actuel et les capture en PNG (mode éditeur = pleine visibilité).
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright-core");
const { loadMesh } = require("./mesh-engine.cjs");

const OUT = process.env.OUT || "/tmp/claude-0/-home-user-game/fc9dfef8-6f8a-5243-95d8-c82e81013118/scratchpad/maps";
fs.mkdirSync(OUT, {recursive:true});
const EXE = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const HTML = "file://" + path.resolve(__dirname, "..", "index.html") + "?edit";

const M = loadMesh();
// jeu de maps à inspecter : pods 1/2/3, 2 graines chacune, board 13x10, couvert 0.30
const specs = [];
for(const pods of [1,2,3]) for(const s of [101, 202]) specs.push({pods, seed:s, board:[13,10], cover:0.30});

const maps = [];
for(const sp of specs){
  M.setBoardSize(sp.board[0], sp.board[1]); M.setMove(3,2,2); M.setSeed(sp.seed);
  let meta; try{ meta = M.genMission({podCount:sp.pods, cover:sp.cover, podSpacing:4}); }catch(e){ continue; }
  if(!meta) continue;
  const obj = M.exportObj();
  obj.name = `pods${sp.pods}_seed${sp.seed}`;
  const np = M.units.filter(u=>u.team==="player").length, ne = M.units.filter(u=>u.team==="enemy").length;
  maps.push({ label:`${sp.pods} pod(s) · seed ${sp.seed} · ${meta.cells} cellules · ${np}v${ne}`, file:obj.name, json:JSON.stringify(obj) });
}
console.log(`généré ${maps.length} maps`);

(async () => {
  const browser = await chromium.launch({ executablePath: EXE, args:["--no-sandbox"] });
  for(const m of maps){
    const ctx = await browser.newContext({ viewport:{width:760, height:620}, deviceScaleFactor:2 });
    await ctx.addInitScript((d)=>{ localStorage.setItem("mgf_mesh_draft", d); localStorage.setItem("mgf_mesh_mname", ""); }, m.json);
    const page = await ctx.newPage();
    await page.goto(HTML, { waitUntil:"networkidle" });
    await page.waitForTimeout(400);
    const out = path.join(OUT, m.file + ".png");
    await page.locator("#board").screenshot({ path: out });
    console.log("  ✔", m.file, "—", m.label);
    await ctx.close();
  }
  await browser.close();
  fs.writeFileSync(path.join(OUT,"index.txt"), maps.map(m=>m.file+".png — "+m.label).join("\n"));
})().catch(e=>{ console.error(e); process.exit(1); });
