const { chromium } = require('/tmp/node_modules/playwright-core');
const fs=require('fs');
const FORMES=['rect','L','S','croix','sablier','anneau','diag'];
const TAILLES=[[10,8],[13,10],[16,13],[20,16]];
const PODS=[2,3,4,5];
const REPET=5;
(async()=>{
  const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--no-sandbox']});
  const p=await b.newPage({viewport:{width:1600,height:1200}});
  const errs=[]; p.on('pageerror',e=>errs.push(e.message));
  await p.goto('file:///home/user/game/index.html'); await p.waitForTimeout(600);
  await p.evaluate(()=>{ document.getElementById('title').style.display='none'; document.getElementById('nav-m').click(); });
  await p.waitForTimeout(400);
  const out=fs.createWriteStream('/tmp/balayage2.ndjson');
  let n=0, tot=FORMES.length*TAILLES.length*PODS.length*REPET;
  const t0=Date.now();
  for(const f of FORMES) for(const [w,h] of TAILLES) for(const pods of PODS) for(let r=0;r<REPET;r++){
    let rec;
    try{
      rec=await p.evaluate(a=>window.SIMULER({forme:a.f,bw:a.w,bh:a.h,pods:a.pods,ennemis:a.pods*3,blindes:true,maxTours:120}),{f,w,h,pods});
    }catch(e){ rec={erreur:String(e).slice(0,120),forme:f,bw:w,bh:h,podsDemandes:pods}; }
    rec.podsDemandes=pods; rec.rep=r;
    out.write(JSON.stringify(rec)+'\n');
    n++;
    if(n%16===0) console.log(`${n}/${tot} · ${Math.round((Date.now()-t0)/1000)}s`);
  }
  out.end();
  console.log(`FINI ${n}/${tot} en ${Math.round((Date.now()-t0)/1000)}s`);
  console.log(errs.length?'ERREURS: '+errs.slice(0,3).join(' | '):'aucune erreur JS');
  await b.close();
})();
