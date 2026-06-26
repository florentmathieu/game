const fs=require("fs"),path=require("path");
const {chromium}=require("playwright-core");
const EXE="/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const OUT="/tmp/claude-0/-home-user-game/fc9dfef8-6f8a-5243-95d8-c82e81013118/scratchpad/geo";
const camp=JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8")); camp.start="geo";
// Merry sapeur: Fumigène; Gizzard assassin: Frappe de l'ombre + Estompe; Stiff sergent: Cri de ralliement
const save={roster:[{name:"Stiff",cls:"sergent",xp:12,perks:["se1a","se2a","se3a"]},{name:"Merry",cls:"sapeur",xp:12,perks:["sa1a","sa2a","sa3a"]},{name:"Gizzard",cls:"assassin",xp:7,perks:["as1a","as2a"]}]};
(async()=>{
  const b=await chromium.launch({executablePath:EXE,args:["--no-sandbox"]});
  const ctx=await b.newContext({viewport:{width:780,height:680},deviceScaleFactor:2});
  await ctx.addInitScript(([c,s])=>{localStorage.setItem("mgf_camp_draft_mesh",c);localStorage.setItem("mgf_camp_save_acte-1-prologue",s);localStorage.removeItem("mgf_mesh_draft");},[JSON.stringify(camp),JSON.stringify(save)]);
  const p=await ctx.newPage(); const errs=[]; p.on("console",m=>{if(m.type()==="error")errs.push(m.text());});
  await p.goto("http://localhost:8099/index.html",{waitUntil:"networkidle"}); await p.waitForTimeout(400);
  await p.evaluate(()=>{const x=document.getElementById("title-btn");if(x)x.click();}); await p.waitForTimeout(1000);
  const rect=await p.evaluate(()=>{const c=document.getElementById("board");const r=c.getBoundingClientRect();return{w:r.width,cw:c.width};});
  await p.locator("#board").click({position:{x:476*rect.w/rect.cw,y:302*rect.w/rect.cw}}); await p.waitForTimeout(1200);
  // sélectionne chaque membre via le panneau roster, dump les boutons d'action
  for(const name of ["Merry","Gizzard","Stiff"]){
    await p.evaluate(n=>{ const d=[...document.querySelectorAll("#roster .rost")].find(e=>e.textContent.includes(n)); if(d)d.click(); }, name);
    await p.waitForTimeout(250);
    const acts=await p.evaluate(()=>[...document.querySelectorAll("#acts button")].map(b=>b.title||b.textContent).filter(Boolean));
    console.log(name+" actions:", acts.join(" | "));
  }
  await p.locator("#board").screenshot({path:path.join(OUT,"04-abilities.png")});
  console.log("console errors:", errs.slice(0,4));
  await b.close();
})().catch(e=>{console.error(e.message);process.exit(1);});
