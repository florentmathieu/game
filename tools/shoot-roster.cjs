const fs=require("fs"),path=require("path");
const {chromium}=require("playwright-core");
const EXE="/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const OUT="/tmp/claude-0/-home-user-game/fc9dfef8-6f8a-5243-95d8-c82e81013118/scratchpad/geo";
const camp=JSON.parse(fs.readFileSync("campaigns-mesh/acte1.json","utf8")); camp.start="geo";
// sauvegarde montrant de l'usure et des pertes
const save={roster:[
 {name:"Stiff",cls:"sergent",xp:12,perks:["se1a","se2a","se3a"],fatigue:100,stress:60,special:true,dead:false},
 {name:"Merry",cls:"sapeur",xp:12,perks:["sa1a","sa2a","sa3a"],fatigue:45,stress:80,special:true,dead:false},
 {name:"Gizzard",cls:"assassin",xp:12,perks:["as1a","as2a"],fatigue:20,stress:15,special:true,dead:false},
 {name:"Bma",cls:"garde",xp:7,perks:["ga1a"],fatigue:0,stress:0,special:false,dead:true},
 {name:"Pip",cls:"sapeur",xp:3,perks:[],fatigue:30,stress:25,special:false,dead:false},
 {name:"Vex",cls:"assassin",xp:0,perks:[],fatigue:0,stress:0,special:false,dead:false}]};
(async()=>{
  const b=await chromium.launch({executablePath:EXE,args:["--no-sandbox"]});
  const ctx=await b.newContext({viewport:{width:780,height:720},deviceScaleFactor:2});
  await ctx.addInitScript(([c,s])=>{localStorage.setItem("mgf_camp_draft_mesh",c);localStorage.setItem("mgf_camp_save_acte-1-prologue",s);localStorage.removeItem("mgf_mesh_draft");},[JSON.stringify(camp),JSON.stringify(save)]);
  const p=await ctx.newPage();
  await p.goto("http://localhost:8099/index.html",{waitUntil:"networkidle"}); await p.waitForTimeout(400);
  await p.evaluate(()=>{const x=document.getElementById("title-btn");if(x)x.click();}); await p.waitForTimeout(1100);
  await p.screenshot({path:path.join(OUT,"05-roster.png")});
  await b.close(); console.log("shot ok");
})().catch(e=>{console.error(e.message);process.exit(1);});
