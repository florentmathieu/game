// Charge le moteur « maillage » de index.html en Node (stubs DOM), et expose ses
// fonctions internes pour la simulation IA-vs-IA et le banc d'essai de génération.
const fs = require("fs");
const path = require("path");

function loadMesh(htmlPath){
  const html = fs.readFileSync(htmlPath || path.join(__dirname, "..", "index.html"), "utf8");
  const m = html.match(/<script>([\s\S]*?)<\/script>/);
  if (!m) throw new Error("script introuvable dans index.html");
  let src = m[1];

  const EXPORT = `
  ;globalThis.__mesh = {
    get units(){return units}, set units(v){units=v},
    get cells(){return cells},
    get walls(){return walls}, set walls(v){walls=v},
    get over(){return over}, set over(v){over=v},
    get turn(){return turn}, set turn(v){turn=v},
    get mode(){return mode}, set mode(v){mode=v},
    get W(){return W}, get H(){return H}, get COLS(){return COLS}, get ROWS(){return ROWS},
    get AP_MAX(){return AP_MAX}, get MOB(){return MOB}, get FREE_MP(){return FREE_MP},
    setMove(mob,ap,free){ if(mob!=null)MOB=mob; if(ap!=null)AP_MAX=ap; if(free!=null)FREE_MP=free; },
    reseed(s){ RND=mk((s>>>0)||1); },
    setSeed(s){ seed=(s>>>0); },
    genMission, applyMissionObj, exportObj, startGame, setBoardSize, genMesh, buildAdj,
    U, CLASSES, reach, moveAlong, doAttack, inRange, hops, los, passable, occ, adjacent,
    apForMove, budget, bestEnemyTarget, nearestOpposing, wakePod, wakeEnemy, checkEnd, refresh, computeEVis,
    hostile, uAt, enemyActive, shotFrom, pathTo,
    get lastOutcome(){return lastOutcome}, set lastOutcome(v){lastOutcome=v},
    get curMission(){return curMission}, set curMission(v){curMission=v},
    get turnNum(){return turnNum}, set turnNum(v){turnNum=v},
    get geoPlay(){return geoPlay}, set geoPlay(v){geoPlay=v},
    get campRun(){return campRun}, set campRun(v){campRun=v},
    geoMissionEnd, awardXp, applyAttrition, applyMortal, applyRecruit, checkMortalConditions, pendingPromotions, gradeFromXp, applyPerkMods, deployRoster,
    setupBonus, checkBonus, grantBonus, applyReward, maybeOfferExtra, launchMini, miniMissionEnd,
    get PERKS(){return PERKS}, get GRADES(){return GRADES},
    setAutoPromote(fn){ autoPromote=fn; }, saveRosterProgress, loadRosterProgress, clearRosterProgress,
    get smoke(){return smoke},
    execSmoke, execBreach, execShadow, execRally, execVanish, execTaunt, execHoldline, execWall,
  };
  `;
  src = src.replace(/\}\)\(\);\s*$/, EXPORT + "\n})();");

  // ---- stubs DOM / environnement (pas de rAF/performance : fx & anims = no-op) ----
  const noop = () => {};
  const ctx = new Proxy({}, { get: (t,k)=> (k in t ? t[k] : noop) });
  ctx.setTransform = noop;
  const VALS = { dens:"44", dist:"28", bw:"10", bh:"8", "gen-cover":"28", "gen-diff":"moyen", "gen-arch":"eliminate",
    "gh-branch":"", "gh-repo":"", "gh-token":"", "geo-n":"12", "geo-aspect":"3:2", "geo-name":"" };
  const els = {};
  function makeEl(id){ return {
    id, style:{}, value:(id in VALS?VALS[id]:""), textContent:"", innerHTML:"", dataset:{}, files:[], checked:false,
    width:720, height:560, onclick:null, oninput:null, onchange:null,
    addEventListener:noop, removeEventListener:noop, appendChild:noop, removeChild:noop, after:noop, append:noop,
    prepend:noop, insertBefore:noop, replaceChild:noop, setAttribute:noop, getAttribute:()=>null, focus:noop, blur:noop, cloneNode(){return makeEl("_");},
    querySelector:()=>makeEl("_"), querySelectorAll:()=>[],
    classList:{ toggle:noop, add:noop, remove:noop, contains:()=>false },
    getContext:()=>ctx, getBoundingClientRect:()=>({left:0,top:0,width:720,height:560}),
    nextElementSibling:null, parentNode:null, appendChild:noop,
  }; }
  const getEl = (id)=> els[id] || (els[id]=makeEl(id));
  const sandbox = {
    document:{
      getElementById:getEl, querySelector:()=>makeEl("_"), querySelectorAll:()=>[],
      createElement:()=>makeEl("_"), body:{ classList:{ add:noop, remove:noop, contains:()=>false } },
      addEventListener:noop,
    },
    window:{ addEventListener:noop, removeEventListener:noop, devicePixelRatio:1 },
    location:{ search:"" }, navigator:{ userAgent:"node" },
    localStorage:(()=>{ const m=new Map(); return { getItem:k=>m.has(k)?m.get(k):null, setItem:(k,v)=>m.set(k,String(v)), removeItem:k=>m.delete(k), clear:()=>m.clear() }; })(),
    setTimeout:noop, clearTimeout:noop, setInterval:noop, clearInterval:noop,
    fetch:()=>Promise.reject(new Error("no fetch")),
    URLSearchParams, alert:noop, prompt:()=>null, confirm:()=>true,
    Math, JSON, Set, Map, Array, Object, String, Number, Boolean, console, Date, isNaN, parseInt, parseFloat, Infinity, NaN,
  };
  const fn = new Function(...Object.keys(sandbox), "globalThis", src + "\nreturn globalThis.__mesh;");
  return fn(...Object.values(sandbox), globalThis);
}
module.exports = { loadMesh };
