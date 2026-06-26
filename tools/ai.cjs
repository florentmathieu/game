// IA tactique partagée pour le banc d'essai. Principe : TOUJOURS agir.
// 1) énumère les cases atteignables d'où l'on peut tirer en gardant >=1 PA, et choisit
//    le tir de meilleure espérance (chance réelle × dégâts × priorité au kill/cible blessée,
//    + valeur défensive de la case de tir : couvert/hauteur) ;
// 2) sinon, avance vers l'ennemi le plus proche, en préférant à distance égale une case couverte/haute.
// La valeur défensive n'est qu'un DÉPARTAGE (jamais devant un tir possible ni devant le rapprochement) :
// on ne reproduit pas la régression de sim-smart.cjs où la prudence faisait REFUSER le contact.
function makeActUnit(M){
  const modes = (u)=>{ const ms=[]; if(u.w.ranged&&(u.clip===undefined||u.ammo>0))ms.push("ranged"); if(u.w.melee)ms.push("melee"); return ms; };
  const avgDmg = (u,m)=>{ const w=u.w[m]; let d=(w.dmgMin+w.dmgMax)/2; if(u.team==="enemy")d=Math.max(1,d-1); return d; };
  const coverProxy = (c)=> M.cells[c].nb.filter(n=>!M.passable(n)).length;   // rochers/murs adjacents = abri partiel
  const defValue = (c)=>{ const cell=M.cells[c]; let v=(cell.elev||0); if(cell.terr==="cover")v+=1.5; return v+coverProxy(c)*0.4; };
  const nearestExit = (u)=>{ const cm=M.curMission; const z=(cm&&cm.exitZone)||"exit";
    let goal=null,gh=Infinity; for(const c of M.cells){ if(c.zone!==z)continue; const h=M.hops(u.cell,c.id); if(h<gh){gh=h;goal=c.id;} } return {goal,gh}; };
  // ===== sorts du mage (mêmes portées qu'index.html) =====
  const HEAL_R=6, FROST_R=7, BLAST_R=6, BLAST_RAD=1;
  // meilleure cible de Déflagration : la case ennemie qui regroupe le plus d'ennemis dans le rayon (à portée + vue)
  function bestBlast(u){ if(u.ap<=0)return null; let best=null;
    for(const t of M.units){ if(t.team===u.team||t.hp<=0)continue; const center=t.cell;
      if(M.hops(u.cell,center)>BLAST_R||!M.los(u.cell,center))continue;
      let count=0; for(const e of M.units){ if(e.team===u.team||e.hp<=0)continue; if(M.hops(center,e.cell)<=BLAST_RAD)count++; }
      if(!best||count>best.count)best={cell:center,count}; }
    return best; }
  // allié le plus blessé (≥45 % de PV manquants) à portée + vue
  function healTarget(u){ let best=null,bw=0; for(const a of M.units){ if(a.team!==u.team||a.hp<=0||a.hp>=a.max)continue;
    if(M.hops(u.cell,a.cell)>HEAL_R||!M.los(u.cell,a.cell))continue; const w=1-a.hp/a.max; if(w>=0.45&&w>bw){bw=w;best=a;} } return best; }
  // ennemi le plus menaçant à givrer (éveillé, pas déjà ralenti, à portée + vue)
  function frostTarget(u){ let best=null,bs=-1; for(const t of M.units){ if(t.team===u.team||t.hp<=0||t.slowed)continue; if(t.team==="enemy"&&!M.enemyActive(t))continue;
    if(M.hops(u.cell,t.cell)>FROST_R||!M.los(u.cell,t.cell))continue; const threat=(M.shotFrom(t.cell,t,u.cell,t.wtype)>0?2:0)+(1-t.hp/t.max); if(threat>bs){bs=threat;best=t;} } return best; }
  // utilisation OPPORTUNISTE des capacités spéciales (unités joueur perkées) — pour exercer les perks au banc d'essai
  function useAbilities(u){
    if(!u.abil||!u.abil.length)return;
    const foes=M.units.filter(t=>M.hostile(u,t)&&t.hp>0);
    const awakeNear=foes.some(t=>(t.team!=="enemy"||M.enemyActive(t))&&M.hops(u.cell,t.cell)<=6);
    const adjAlly=()=>M.units.find(a=>a.team===u.team&&a!==u&&a.hp>0&&M.adjacent(a.cell,u.cell));
    if(u.abil.includes("rally")&&u.ap>0){ const a=M.units.find(x=>x.team===u.team&&x!==u&&x.hp>0&&x.ap<=0&&!x.freeAvail&&M.adjacent(u.cell,x.cell)); if(a)M.execRally(u,a); }
    if(u.abil.includes("taunt")&&u.ap>0&&!u.taunt&&awakeNear&&u.hp>=u.max*0.6)M.execTaunt(u);
    if(u.abil.includes("wall")&&u.ap>0&&!u.wallStance&&awakeNear&&adjAlly())M.execWall(u);
    if(u.abil.includes("vanish")&&u.ap>0&&!u.vanishUsed&&u.hp<u.max*0.4&&awakeNear)M.execVanish(u);
  }
  return function actUnit(u){
    let guard=0;
    const extracting = u.team==="player" && M.curMission && M.curMission.objective==="extract";
    if(!extracting)useAbilities(u);
    while(u.hp>0 && !M.over && (u.ap>0||u.freeAvail) && guard++<8){
      // Frappe de l'ombre : l'assassin bondit sur un ennemi proche (remplace l'attaque normale)
      if(u.abil&&u.abil.includes("shadowstrike")&&u.ap>0){ const foe=M.nearestOpposing&&M.nearestOpposing(u); if(foe&&M.hops(u.cell,foe.cell)<=4&&M.execShadow(u,foe))return; }
      // Mage (une seule décision spéciale par tour, au 1er passage) : déflagration si ≥2 ennemis groupés (termine le tour),
      // sinon soin d'un allié critique, sinon givre d'une menace ; puis on enchaîne sur un tir avec le PA restant.
      if(u.abil&&guard===1&&u.ap>0){
        if(u.abil.includes("blast")){ const bl=bestBlast(u); if(bl&&bl.count>=2&&M.execBlast(u,bl.cell))return; }
        if(u.abil.includes("heal")){ const a=healTarget(u); if(a&&M.execHeal(u,a))continue; }
        if(u.abil.includes("frost")){ const t=frostTarget(u); if(t&&M.execFrost(u,t))continue; }
      }
      const d=M.reach(u); d[u.cell]=0;
      // OBJECTIF EXTRACTION : foncer vers la zone de sortie (le combat est secondaire) ; on s'arrête une fois dessus.
      if(extracting){ const {goal,gh}=nearestExit(u); if(goal==null){ /* pas de zone : repli combat */ }
        else { if(gh===0)return; const gc=M.cells[goal]; const recent=u.__recent||(u.__recent=[]);
          let best=null,bestKey=Infinity;
          for(const cs in d){ const c=+cs; if(c===u.cell)continue; const cc=M.cells[c];
            const h=M.hops(c,goal), eu=Math.hypot(cc.cx-gc.cx,cc.cy-gc.cy), pen=recent.includes(c)?1e7:0;
            const key=h*1e5+eu+pen; if(key<bestKey){bestKey=key;best=c;} }
          if(best==null)return; M.moveAlong(u,best); recent.push(u.cell); if(recent.length>5)recent.shift(); continue; }
      }
      let bestAtk=null;
      for(const cs in d){ const c=+cs; const apCost=M.apForMove(u,d[c]); if(apCost>=u.ap)continue;   // garder >=1 PA pour tirer
        for(const m of modes(u)){ for(const t of M.units){ if(!M.hostile(u,t)||t.hp<=0)continue;
          const ch=M.shotFrom(c,u,t.cell,m); if(ch<=0)continue;
          const dmg=avgDmg(u,m), kill=dmg>=t.hp, wounded=1-t.hp/t.max;
          const score=(ch/100)*dmg*(kill?2.5:1) - apCost*0.15 + defValue(c)*0.25 + wounded*0.5;   // focus-fire + case de tir abritée
          if(!bestAtk||score>bestAtk.score)bestAtk={c,t,m,score}; } } }
      if(bestAtk){ if(bestAtk.c!==u.cell)M.moveAlong(u,bestAtk.c); if(u.ap>0)M.doAttack(u,bestAtk.t,bestAtk.m); return; }
      // Fumigène : pas de tir et exposé au feu ennemi -> on se voile (sur place) pour casser la ligne de vue
      if(u.abil&&u.abil.includes("smoke")&&u.ap>0){ const exposed=M.units.some(t=>t.team==="enemy"&&t.hp>0&&M.enemyActive(t)&&M.shotFrom(t.cell,t,u.cell,t.wtype)>0); if(exposed&&M.execSmoke(u,u.cell))continue; }
      // NB : la vigilance (overwatch) a été essayée ici mais, l'IA étant SYMÉTRIQUE (les deux camps
      // l'utilisent), elle s'annule et ne fait qu'allonger les parties — aucun gain de win%. C'est un
      // outil pour un HUMAIN vs IA (le joueur assaille des pods endormis), pas un levier de sim. Retiré.
      // pas de tir : avancer vers l'ennemi le plus proche.
      // On choisit la case ATTEIGNABLE qui minimise (sauts vers l'ennemi, puis distance physique).
      // hops ignore le brouillard : viser la frontière de vision la plus proche de l'ennemi fait
      // progresser même quand le chemin contourne un rocher (pas besoin d'un STRICT rapprochement,
      // sinon l'unité se fige dans une poche). Mémoire courte anti-va-et-vient.
      const foe=M.nearestOpposing(u); if(!foe)return;
      const fc=M.cells[foe.cell];
      const recent=u.__recent||(u.__recent=[]);
      let best=null,bestKey=Infinity;
      for(const cs in d){ const c=+cs; if(c===u.cell)continue;
        const cc=M.cells[c];
        const h=M.hops(c,foe.cell);
        const eu=Math.hypot(cc.cx-fc.cx,cc.cy-fc.cy);
        const pen=recent.includes(c)?1e7:0;                            // éviter de revenir sur ses pas
        const key=h*1e5 + eu - defValue(c)*30 + pen;                    // à sauts ~égaux, finir abrité/en hauteur (départage seulement)
        if(key<bestKey){bestKey=key;best=c;} }
      if(best==null)return;                                            // aucune case libre : tenir, laisser passer les autres
      M.moveAlong(u,best);
      recent.push(u.cell); if(recent.length>5)recent.shift();          // u.cell = destination après moveAlong
    }
  };
}
module.exports = { makeActUnit };
