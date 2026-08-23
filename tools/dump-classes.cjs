// Dump des donnees moteur (CLASSES + PERKS) vers /tmp/classes.json, ce que
// tools/build-classes-sheet.py attend en entree.
//   python3 -m http.server 8099   (depuis la racine du depot)
//   node tools/dump-classes.cjs && python3 tools/build-classes-sheet.py
const fs=require("fs");
// playwright-core n'est pas une dependance du depot : on le prend ou il est installe.
const {chromium}=(()=>{ for(const m of ["playwright-core","/tmp/node_modules/playwright-core"])
    try{ return require(m); }catch(e){}
  console.error("playwright-core introuvable — npm i -g playwright-core, ou NODE_PATH=..."); process.exit(1); })();
const EXE=process.env.CHROME||"/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const URL=process.env.URL||"http://localhost:8099/index.html?edit";
(async()=>{
  const b=await chromium.launch({executablePath:EXE,args:["--no-sandbox"]});
  const p=await (await b.newContext()).newPage();
  await p.goto(URL,{waitUntil:"networkidle"});
  const d=await p.evaluate(()=>({CLASSES:JSON.parse(JSON.stringify(window.CLASSES)),
                                 PERKS:JSON.parse(JSON.stringify(window.PROGRESSION.PERKS))}));
  fs.writeFileSync("/tmp/classes.json",JSON.stringify(d));
  console.log("/tmp/classes.json —",Object.keys(d.CLASSES).length,"classes ·",
              Object.keys(d.PERKS).length,"arbres");
  await b.close();
})().catch(e=>{console.error(e);process.exit(1);});
