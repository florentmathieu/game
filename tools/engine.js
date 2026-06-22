// Charge la logique du jeu (index.html) en environnement Node, avec des stubs DOM,
// et expose ses fonctions internes pour la simulation IA-vs-IA.
const fs = require("fs");
const path = require("path");

function loadEngine(htmlPath){
  const html = fs.readFileSync(htmlPath || path.join(__dirname, "..", "index.html"), "utf8");
  const m = html.match(/<script>([\s\S]*?)<\/script>/);
  if (!m) throw new Error("script introuvable dans index.html");
  let src = m[1];

  // bloc d'export injecté juste avant la fermeture de l'IIFE
  const EXPORT = `
  ;globalThis.__t = {
    get units(){return units}, set units(v){units=v},
    get tiles(){return tiles},
    get walls(){return walls}, set walls(v){walls=v},
    get gameOver(){return gameOver}, set gameOver(v){gameOver=v},
    get visible(){return visible}, get enemyVisible(){return enemyVisible},
    get COLS(){return COLS}, get ROWS(){return ROWS}, LEVELS, VISION, AP_MAX, FREE_MP, MOB_AP, NEI,
    resizeGrid, blankMap, generateElevation, generate, buildUnit, placeUnitsFrom,
    serializeMission, applyMission, recomputeVision, computeReach, buildPath,
    spendMove, executeMove, doAttack, canAttack, hitBreakdown, bestTarget,
    shotChanceFrom, coverPenalty, apForMove, lineOfFire, hexDistUnits, moveCost,
    nearestOpposing, faceTowards, setMode, resolveThrow, checkEnd, neighbors,
    key, offsetToCube, cubeDist, tileAt, hasWall, wallKey, TEMPLATES,
    fieldOfView, enemyActive, enemyCanSee,
  };
  `;
  src = src.replace(/\}\)\(\);\s*$/, EXPORT + "\n})();");

  // ---- stubs DOM / environnement (pas de rAF ni performance : fx/anim no-op) ----
  const noop = () => {};
  const ctx = new Proxy({}, { get: (t, k) => (k in t ? t[k] : noop) });
  ctx.setTransform = noop;
  const el = () => ({
    style:{}, value:"", textContent:"", innerHTML:"", dataset:{}, files:[],
    addEventListener:noop, removeEventListener:noop, appendChild:noop, click:noop,
    classList:{ toggle:noop, add:noop, remove:noop, contains:()=>false },
    querySelectorAll:()=>[], getContext:()=>ctx, getBoundingClientRect:()=>({left:0,top:0}),
    width:300, height:300,
  });
  const canvas = el();
  const sandbox = {
    document:{
      getElementById:(id)=> id==="board" ? canvas : el(),
      querySelector:()=>el(), querySelectorAll:()=>[], createElement:()=>el(),
      body:{ classList:{ add:noop, remove:noop } },
    },
    window:{ addEventListener:noop, devicePixelRatio:1 },
    location:{ search:"" }, navigator:{},
    Math, JSON, Set, Map, Array, Object, console, Date,
  };
  // exécute le script dans un contexte avec ces globals
  const fn = new Function(...Object.keys(sandbox), "globalThis", src + "\nreturn globalThis.__t;");
  const T = fn(...Object.values(sandbox), globalThis);
  return T;
}

module.exports = { loadEngine };
