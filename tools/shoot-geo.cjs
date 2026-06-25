const fs=require("fs"), path=require("path");
const { chromium } = require("playwright-core");
const EXE="/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const BASE="http://localhost:8099/index.html";
const OUT=process.env.OUT||"/tmp/claude-0/-home-user-game/fc9dfef8-6f8a-5243-95d8-c82e81013118/scratchpad/geo";
fs.mkdirSync(OUT,{recursive:true});
// campagne acte1, mais on démarre directement au nœud geoscape
const camp=JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8")); camp.start="geo";

(async()=>{
  const browser=await chromium.launch({executablePath:EXE,args:["--no-sandbox"]});
  const ctx=await browser.newContext({viewport:{width:760,height:660},deviceScaleFactor:2});
  await ctx.addInitScript((d)=>{ localStorage.setItem("mgf_camp_draft_mesh", d); localStorage.removeItem("mgf_mesh_draft"); localStorage.removeItem("mgf_gh"); localStorage.removeItem("mgf_gh_token"); }, JSON.stringify(camp));
  const page=await ctx.newPage();
  const errs=[]; page.on("console",m=>{ if(m.type()==="error")errs.push(m.text()); });
  await page.goto(BASE,{waitUntil:"networkidle"});
  await page.waitForTimeout(400);
  // démarrer la campagne (clic sur le titre)
  await page.evaluate(()=>{ const b=document.getElementById("title-btn"); if(b)b.click(); });
  await page.waitForTimeout(1200);
  const inGeo=await page.evaluate(()=>document.body.classList.contains("geomap"));
  console.log("entered geoscape:", inGeo);
  await page.locator("#board").screenshot({path:path.join(OUT,"01-geoscape.png")});
  // lancer une mission : clic sur Bois brûlé (476,302) en coords internes -> CSS
  const rect=await page.evaluate(()=>{ const c=document.getElementById("board"); const r=c.getBoundingClientRect(); return {w:r.width,h:r.height,cw:c.width,ch:c.height}; });
  const sx=rect.w/rect.cw, sy=rect.h/rect.ch;
  await page.locator("#board").click({position:{x:476*sx,y:302*sy}});
  await page.waitForTimeout(1400);
  const st=await page.evaluate(()=>({geomap:document.body.classList.contains("geomap"), playing:document.body.classList.contains("view-play")}));
  console.log("after region click:", JSON.stringify(st));
  await page.locator("#board").screenshot({path:path.join(OUT,"02-mission.png")});
  console.log("console errors:", errs.slice(0,5));
  await browser.close();
})().catch(e=>{console.error(e);process.exit(1);});
