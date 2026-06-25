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
  return function actUnit(u){
    let guard=0;
    const extracting = u.team==="player" && M.curMission && M.curMission.objective==="extract";
    while(u.hp>0 && !M.over && (u.ap>0||u.freeAvail) && guard++<8){
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
