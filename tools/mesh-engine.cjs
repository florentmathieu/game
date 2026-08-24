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
    get ESCOUADE_BASE(){return ESCOUADE_BASE}, set ESCOUADE_BASE(v){ESCOUADE_BASE=v}, aUnOfficier,
    // déplace les niveaux de voie sans toucher au fichier : TRACK_LEVELS est un const mais son
    // contenu est mutable, et les clés de TRACK_PERKS suivent
    setTrackLevels(arr){ const av=TRACK_LEVELS.slice();
      for(const tk in TRACK_PERKS){ const old=TRACK_PERKS[tk], neuf={};
        av.forEach((L,i)=>{ if(old[L])neuf[arr[i]]=old[L]; }); TRACK_PERKS[tk]=neuf; }
      TRACK_LEVELS.length=0; for(const x of arr)TRACK_LEVELS.push(x); },
    get TRACK_LEVELS(){return TRACK_LEVELS},
    setXp(mis,kill){ if(mis!=null)XP_MISSION=mis; if(kill!=null)XP_KILL=kill; },
    get XP_THRESH(){return XP_THRESH},
    setMove(mob,ap,free){ if(mob!=null)MOB=mob; if(ap!=null)AP_MAX=ap; if(free!=null)FREE_MP=free; },
    reseed(s){ RND=mk((s>>>0)||1); },
    setSeed(s){ seed=(s>>>0); },
    genMission, applyMissionObj, exportObj, startGame, setBoardSize, genMesh, buildAdj,
    U, CLASSES, reach, moveAlong, doAttack, inRange, hops, los, passable, occ, adjacent,
    apForMove, budget, bestEnemyTarget, nearestOpposing, wakePod, wakeEnemy, checkEnd, refresh, computeEVis,
    hostile, uAt, enemyActive, shotFrom, pathTo, cellAtXY, opaque, murCoupe, wallSeg, wkey,
    get lastOutcome(){return lastOutcome}, set lastOutcome(v){lastOutcome=v},
    get curMission(){return curMission}, set curMission(v){curMission=v},
    get turnNum(){return turnNum}, set turnNum(v){turnNum=v},
    get geoPlay(){return geoPlay}, set geoPlay(v){geoPlay=v},
    get campRun(){return campRun}, set campRun(v){campRun=v},
    geoMissionEnd, awardXp, applyAttrition, applyMortal, applyRecruit, checkMortalConditions, pendingPromotions, gradeFromXp, applyPerkMods, deployRoster,
    setupBonus, checkBonus, grantBonus, applyReward, maybeOfferExtra, launchMini, miniMissionEnd,
    applyCarry, saveCarry, memMaxHp, memDeployHp,
    runGeoEvents, geoRegionCleared, geoRevealRegion, applyGeoEvent, saveFiredEvents, loadFiredEvents,
    primeInit, primeDecay, geoBuildCells, geoAccessibleSet, geoPathTo, drawGeoPlay,
    genGeoMap, genGeoMarche, addForgeEnemies, maybeAttackRegion,
    saveCampRun, loadCampRunSave, clearCampRunSave,
    get PERKS(){return PERKS}, get GRADES(){return GRADES}, get TRACK_PERKS(){return TRACK_PERKS},
    setAutoPromote(fn){ autoPromote=fn; }, saveRosterProgress, loadRosterProgress, clearRosterProgress,
    get smoke(){return smoke},
    execSmoke, execBreach, execShadow, execRally, execVanish, execTaunt, execHoldline, execWall,
    execBlast, execHeal, execFrost, execShove, execCharge, onCd, setCd, tickCd, enemyUseAbil,
    // capacités des arbres réécrits (Sheet 2026-08) : sans elles le banc d'essai fait jouer
    // l'escouade à mains nues, et toute mesure d'équilibrage est fausse
    execButtstroke, execSpray, execRunGun, execPrecShot, execSureHit, execBurst, execBoomShell,
    execSmoker, execCusser, execRaiseWall, execRemoveWall,
    execStab, execLure, execFear, execBait,
    execLifeFire, execHammer, execEvade, execTeleport, execRayOfLight, execUnwall, execWave,
    execSpirit, execReplenish, execHaven, execRequiem, execSolstice, execBiscuit,
    execWarcry, execInspire, execInsult, execExfil, execBruise, execDecide, execFuckIt,
    execFireCloud, execCold, execColdArmor, opportunite,
    abilDispo, regleAbil, chargesRestantes, tourDesEsprits, tickBrulures, tickBoosts,
    corruptLevel, distortTerrain, polyCentroid,
    get infl(){return infl}, setInfl(v){ infl=v; ROWS=infl.length; COLS=(infl[0]&&infl[0].length)||COLS; W=COLS*MC; H=ROWS*MC; },
    get wallSeg(){return wallSeg}, get murs(){return murs}, get portes(){return portes},
    murBetween, enterCost, edgeCell, get visible(){return visible}, get evisible(){return evisible},
    setDist(p){ distEl.value=String(p); }, setDens(g){ dens.value=String(g); },
    get MC(){return MC},
    // contexte stratégique de la mission (acte + étoiles) : sans lui le banc d'essai tire
    // toujours dans la réserve d'un milieu d'acte 1, et n'affronte jamais les ennemis tardifs
    get CTX(){return CTX_MISSION}, setCtx(a,e){ if(a&&typeof a==="object"){ CTX_MISSION={acte:a.acte||1,etoiles:a.etoiles||3}; return; } CTX_MISSION={acte:a||1,etoiles:e||3}; },
    get REGLES(){return REGLES_ENNEMIS}, classesPourMission, rangDiff,
    // leviers d'équilibrage
    get CLS(){return CLASSES},
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
  // LES CASES COCHÉES DU DOCUMENT. Le stub les rendait TOUTES décochées : « auto size » passait
  // pour éteinte, et genMission gardait le plateau par défaut au lieu de le dimensionner sur le
  // nombre de poches. Toutes les mesures d'équilibrage se jouaient donc sur la même carte, quelle
  // que soit la difficulté. On lit l'état réel des cases dans le HTML.
  const COCHEES = new Set();
  for(const m of html.matchAll(/<input\b[^>]*>/g)){
    const t = m[0]; if(!/\bchecked\b/.test(t)) continue;
    const id = /id="([^"]+)"/.exec(t); if(id) COCHEES.add(id[1]);
  }
  function makeEl(id){ return {
    id, style:{}, value:(id in VALS?VALS[id]:""), textContent:"", innerHTML:"", dataset:{}, files:[], checked:COCHEES.has(id),
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
    // le moteur a gagné de la musique et des effets depuis l'écriture de ce banc : on les rend muets
    Audio: function(){ return { loop:false, preload:"", volume:0, paused:true, src:"", currentTime:0,
      play(){ return Promise.resolve(); }, pause:noop, addEventListener:noop }; },
    requestAnimationFrame:noop, cancelAnimationFrame:noop,
    performance:{ now:()=>0 },
    TextEncoder, TextDecoder, btoa:s=>Buffer.from(s,"binary").toString("base64"),
    atob:s=>Buffer.from(s,"base64").toString("binary"),
    fetch:()=>Promise.reject(new Error("no fetch")),
    URLSearchParams, alert:noop, prompt:()=>null, confirm:()=>true,
    Math, JSON, Set, Map, Array, Object, String, Number, Boolean, console, Date, isNaN, parseInt, parseFloat, Infinity, NaN,
  };
  const fn = new Function(...Object.keys(sandbox), "globalThis", src + "\nreturn globalThis.__mesh;");
  return fn(...Object.values(sandbox), globalThis);
}
module.exports = { loadMesh };
