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
    // ===== capacites des arbres reecrits (Sheet 2026-08) =====
    // Sans elles l escouade joue a mains nues et toute mesure d equilibrage est fausse : le
    // camp d en face, lui, se sert des siennes. On ne cherche pas le jeu optimal, juste un
    // usage RAISONNABLE — celui d un joueur qui appuie sur ses boutons quand ils servent.
    const dispo=id=>u.abil.includes(id)&&M.abilDispo&&M.abilDispo(u,id);
    const cout=id=>{ const r=M.regleAbil?M.regleAbil(u,id):null; return r?Math.max(r.cost||0,r.endsTurn?1:0):1; };
    const peut=id=>dispo(id)&&u.ap>=cout(id);
    const groupe=(r,portee)=>{ let best=null;   // la case qui prend le plus d ennemis
      for(const p of foes){ if(M.hops(u.cell,p.cell)>portee||!M.los(u.cell,p.cell))continue;
        let c=0; for(const q of foes)if(q.hp>0&&M.hops(p.cell,q.cell)<=r)c++;
        if(!best||c>best.c)best={cell:p.cell,c}; } return best; };
    const proche=(p)=>foes.filter(t=>M.hops(u.cell,t.cell)<=p&&M.los(u.cell,t.cell))
      .sort((a,b)=>a.hp-b.hp)[0];
    const blesse=()=>M.units.filter(a=>a.team===u.team&&a!==u&&a.hp>0&&a.hp<a.max*0.55)
      .sort((a,b)=>(a.hp/a.max)-(b.hp/b.max))[0];

    // --- posture et soutien, d abord : ce qui ne coute pas le tour ---
    if(peut("warcry")&&awakeNear&&adjAlly())M.execWarcry(u);
    if(peut("inspire")){ const a=M.units.find(x=>x.team===u.team&&x!==u&&x.hp>0&&x.ap<=0&&!x.freeAvail&&M.hops(u.cell,x.cell)<=7&&M.los(u.cell,x.cell)); if(a)M.execInspire(u,a); }
    if(peut("evade")){ const a=blesse(); if(a)M.execEvade(u,a); }
    if(peut("replenish")){ const a=M.units.filter(x=>x.team===u.team&&x.hp>0&&x.hp<x.max*0.4).sort((a,b)=>a.hp-b.hp)[0]; if(a)M.execReplenish(u,a); }
    if(peut("fuckit")&&awakeNear&&u.hp>u.max*0.5)M.execFuckIt(u);
    if(peut("rungun")&&awakeNear)M.execRunGun(u);
    if(peut("decide")){ const t=proche(7); if(t&&!t.designeTours)M.execDecide(u,t); }
    if(peut("spirit")&&awakeNear){ const libre=M.cells.filter(c=>M.passable(c.id)&&!M.uAt(c.id)&&M.hops(u.cell,c.id)<=4&&M.los(u.cell,c.id))[0];
      if(libre)M.execSpirit(u,libre.id); }
  }
  // Une capacite OFFENSIVE vaut-elle mieux qu un tir ordinaire ? On les essaie dans l ordre du
  // plus fort au plus faible ; la premiere qui part remplace l attaque.
  function attaqueSpeciale(u){
    if(!u.abil||!u.abil.length)return false;
    const dispo=id=>u.abil.includes(id)&&M.abilDispo&&M.abilDispo(u,id);
    const cout=id=>{ const r=M.regleAbil?M.regleAbil(u,id):null; return r?Math.max(r.cost||0,r.endsTurn?1:0):1; };
    const peut=id=>dispo(id)&&u.ap>=cout(id);
    const foes=M.units.filter(t=>M.hostile(u,t)&&t.hp>0&&(t.team!=="enemy"||M.enemyActive(t)));
    if(!foes.length)return false;
    const zone=(r,portee)=>{ let best=null;
      for(const p of foes){ if(M.hops(u.cell,p.cell)>portee||!M.los(u.cell,p.cell))continue;
        let c=0; for(const q of foes)if(M.hops(p.cell,q.cell)<=r)c++;
        if(!best||c>best.c)best={cell:p.cell,c}; } return best; };
    const vue=p=>foes.filter(t=>M.hops(u.cell,t.cell)<=p&&M.los(u.cell,t.cell)).sort((a,b)=>a.hp-b.hp)[0];
    const adj=()=>foes.find(t=>M.adjacent(u.cell,t.cell));
    // zones d abord, quand elles prennent au moins deux cibles
    if(peut("lifefire")){ const z=zone(1,7); if(z&&z.c>=2&&M.execLifeFire(u,z.cell))return true; }
    if(peut("firecloud")){ const z=zone(3,7); if(z&&z.c>=2&&M.execFireCloud(u,z.cell))return true; }
    if(peut("hammer")){ const z=zone(1,7); if(z&&z.c>=2&&M.execHammer(u,z.cell))return true; }
    if(peut("wave")){ const z=zone(1,5); if(z&&z.c>=2&&M.execWave(u,z.cell))return true; }
    if(peut("fear")){ const z=zone(2,7); if(z&&z.c>=2&&M.execFear(u,z.cell))return true; }
    if(peut("spray")){ const z=zone(1,5); if(z&&z.c>=2&&M.execSpray(u,z.cell))return true; }
    if(peut("boomshell")){ const z=zone(2,7); if(z&&z.c>=2){ const t=M.uAt(z.cell); if(t&&M.execBoomShell(u,t))return true; } }
    if(peut("cusser")&&u.crackers>0){ const z=zone(2,7); if(z&&z.c>=2&&M.execCusser(u,z.cell))return true; }
    // puis les coups simples, du plus fort au plus faible
    const t=vue(8);
    if(t){
      if(peut("burst")&&M.inRange(u,t,"ranged")&&M.execBurst(u,t))return true;
      if(peut("surehit")&&M.inRange(u,t,"ranged")&&M.execSureHit(u,t))return true;
      if(peut("rayoflight")&&M.execRayOfLight(u,t.cell))return true;
      if(peut("precshot")&&!u.aBouge&&M.inRange(u,t,"ranged")&&M.execPrecShot(u,t))return true;
      if(peut("cold")&&M.execCold(u,t))return true;
    }
    const a=adj();
    if(a){
      if(peut("stab")&&M.execStab(u,a))return true;
      if(peut("buttstroke")&&M.execButtstroke(u,a))return true;
    }
    return false; }
  return function actUnit(u){
    let guard=0;
    const extracting = u.team==="player" && M.curMission && M.curMission.objective==="extract";
    if(!extracting)useAbilities(u);
    while(u.hp>0 && !M.over && (u.ap>0||u.freeAvail) && guard++<8){
      // Frappe de l'ombre : l'assassin bondit sur un ennemi proche (remplace l'attaque normale)
      if(u.abil&&u.abil.includes("shadowstrike")&&u.ap>0){ const foe=M.nearestOpposing&&M.nearestOpposing(u); if(foe&&M.hops(u.cell,foe.cell)<=4&&M.execShadow(u,foe))return; }
      // Capacités bouclier : charge longue pour engager (course + impact) ; repousser un ennemi retranché au contact
      if(u.abil&&u.ap>0){
        if(u.abil.includes("charge")&&!M.onCd(u,"charge")){ const foe=M.nearestOpposing&&M.nearestOpposing(u); if(foe){const h=M.hops(u.cell,foe.cell); if(h>=2&&h<=7&&M.los(u.cell,foe.cell)&&M.execCharge(u,foe))return;} }
        if(u.abil.includes("shove")&&!M.onCd(u,"shove")){ const foe=M.units.find(t=>M.hostile(u,t)&&t.hp>0&&M.adjacent(u.cell,t.cell)&&(M.cells[t.cell].elev>M.cells[u.cell].elev||M.cells[t.cell].terr==="cover")); if(foe&&M.execShove(u,foe))return; }
      }
      // Mage (une seule décision spéciale par tour, au 1er passage) : déflagration si ≥2 ennemis groupés (termine le tour),
      // sinon soin d'un allié critique, sinon givre d'une menace ; puis on enchaîne sur un tir avec le PA restant.
      if(guard===1&&u.ap>0&&attaqueSpeciale(u))return;
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
      // CIBLE TENUE. nearestOpposing() rend le plus proche À CET INSTANT : quand deux ennemis
      // alternent, l'unité change d'objectif chaque tour et fait du sur-place. Les deux camps
      // partageant cette IA, deux groupes aveugles l'un à l'autre tournaient en rond
      // indéfiniment — 26 missions ★3 sur 43 ne finissaient jamais, même en 90 tours.
      // On garde la même cible tant qu'elle vit.
      let foe=(u.__cible&&u.__cible.hp>0&&M.hostile(u,u.__cible))?u.__cible:M.nearestOpposing(u);
      if(!foe)return; u.__cible=foe;
      const fc=M.cells[foe.cell];
      const recent=u.__recent||(u.__recent=[]);
      let best=null,bestKey=Infinity;
      const h0=M.hops(u.cell,foe.cell);
      for(const cs in d){ const c=+cs; if(c===u.cell)continue;
        const cc=M.cells[c];
        const h=M.hops(c,foe.cell);
        const eu=Math.hypot(cc.cx-fc.cx,cc.cy-fc.cy);
        // LA PÉNALITÉ NE DOIT PAS BATTRE LA PROGRESSION. À 1e7 contre un terme de distance qui
        // plafonne à 1e6, éviter une case déjà vue l'emportait TOUJOURS sur se rapprocher : deux
        // groupes aveugles tournaient en rond sans fin. On ne pénalise que ce qui ne rapproche pas.
        const pen=(h>=h0&&recent.includes(c))?1e7:0;
        const key=h*1e5 + eu - defValue(c)*30 + pen;                    // à sauts ~égaux, finir abrité/en hauteur (départage seulement)
        if(key<bestKey){bestKey=key;best=c;} }
      // EXPLORER QUAND ON NE PEUT PAS APPROCHER. Le déplacement est borné aux cases VUES : si
      // l'ennemi se tient derrière un obstacle opaque, tout son voisinage est noir et aucune case
      // atteignable ne réduit la distance. Sans repli, l'unité choisit une case à distance égale
      // et fait du sur-place — c'est ce qui figeait 26 missions ★3 sur 43, sans fin.
      // L'IA du jeu, elle, sait « marcher vers la zone jamais vue la plus proche » : on fait pareil,
      // en poussant la frontière de vision du côté de la cible.
      if(best!=null&&M.hops(best,foe.cell)>=h0){
        let expl=null,eb=-Infinity;
        for(const cs in d){ const c=+cs; if(c===u.cell)continue;
          const noir=M.cells[c].nb.filter(n=>!M.visible.has(n)).length;
          if(!noir)continue;
          const score=noir*1000 - M.hops(c,foe.cell)*10 + defValue(c);
          if(score>eb){eb=score;expl=c;} }
        if(expl!=null)best=expl; }
      if(best==null)return;                                            // aucune case libre : tenir, laisser passer les autres
      M.moveAlong(u,best);
      recent.push(u.cell); if(recent.length>9)recent.shift();          // u.cell = destination après moveAlong
    }
  };
}
module.exports = { makeActUnit };
