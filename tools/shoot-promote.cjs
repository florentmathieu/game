const fs=require("fs"),path=require("path");
const {chromium}=require("playwright-core");
const EXE="/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const OUT="/tmp/claude-0/-home-user-game/fc9dfef8-6f8a-5243-95d8-c82e81013118/scratchpad/geo";
(async()=>{
  const b=await chromium.launch({executablePath:EXE,args:["--no-sandbox"]});
  const ctx=await b.newContext({viewport:{width:720,height:460},deviceScaleFactor:2});
  const p=await ctx.newPage();
  await p.goto("http://localhost:8099/index.html",{waitUntil:"networkidle"});
  await p.waitForTimeout(300);
  // rendu de l'écran de promotion avec le vrai catalogue PERKS (aperçu de l'UI réelle)
  await p.evaluate(()=>{
    document.getElementById("promote-hd").innerHTML='<span class="who">Stiff</span> <span class="gr">→ Aguerri</span> — choisis une compétence (définitif)';
    const opts=document.getElementById("promote-opts"); opts.innerHTML="";
    const data=[["A","Cuirasse","+3 PV"],["B","Mur de boucliers","+20% blocage"]];
    for(const [k,n,d] of data){ const el=document.createElement("div"); el.className="perkopt";
      el.innerHTML=`<div class="ab">${k}</div><div class="pn">${n}</div><div class="pd">${d}</div>`; opts.appendChild(el); }
    const t=document.getElementById("title");if(t)t.style.display="none";document.getElementById("promote").classList.add("show");
  });
  await p.waitForTimeout(200);
  await p.screenshot({path:path.join(OUT,"03-promote.png")});
  await b.close(); console.log("shot ok");
})().catch(e=>{console.error(e);process.exit(1);});
