const fs=require("fs"),path=require("path");
const {chromium}=require("playwright-core");
const EXE="/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const OUT="/tmp/claude-0/-home-user-game/fc9dfef8-6f8a-5243-95d8-c82e81013118/scratchpad/geo";
const camp=JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8")); camp.start="geo";
// progression sauvegardée : Stiff Vétéran (2 perks : +3 PV, +20% blocage) -> max 13
const save={roster:[{name:"Stiff",cls:"sergent",xp:9,perks:["se1a","se1b"]},{name:"Merry",cls:"sapeur",xp:5,perks:["sa1a"]},{name:"Gizzard",cls:"assassin",xp:0,perks:[]}]};
(async()=>{
  const b=await chromium.launch({executablePath:EXE,args:["--no-sandbox"]});
  const ctx=await b.newContext({viewport:{width:760,height:660},deviceScaleFactor:2});
  await ctx.addInitScript(([c,s])=>{ localStorage.setItem("mgf_camp_draft_mesh",c); localStorage.setItem("mgf_camp_save_acte-1-prologue",s); localStorage.removeItem("mgf_mesh_draft"); }, [JSON.stringify(camp),JSON.stringify(save)]);
  const p=await ctx.newPage();
  await p.goto("http://localhost:8099/index.html",{waitUntil:"networkidle"}); await p.waitForTimeout(400);
  await p.evaluate(()=>{const x=document.getElementById("title-btn");if(x)x.click();}); await p.waitForTimeout(1000);
  const rect=await p.evaluate(()=>{const c=document.getElementById("board");const r=c.getBoundingClientRect();return{w:r.width,cw:c.width};});
  await p.locator("#board").click({position:{x:476*rect.w/rect.cw,y:302*rect.w/rect.cw}}); await p.waitForTimeout(1200);
  const roster=await p.evaluate(()=>document.getElementById("roster").innerText.replace(/\n+/g," | "));
  console.log("ROSTER PANEL:", roster);
  await b.close();
})().catch(e=>{console.error(e.message);process.exit(1);});
