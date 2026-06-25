// IA tactique partagée pour le banc d'essai. Principe : TOUJOURS agir.
// 1) énumère les cases atteignables d'où l'on peut tirer en gardant >=1 PA, et choisit
//    le tir de meilleure espérance (chance réelle × dégâts × priorité au kill, + hauteur) ;
// 2) sinon, avance vers l'ennemi le plus proche en finissant sur couvert/hauteur à distance égale.
// Pas de pénalité qui ferait REFUSER le contact (l'erreur de sim-smart.cjs).
function makeActUnit(M){
  const modes = (u)=>{ const ms=[]; if(u.w.ranged&&(u.clip===undefined||u.ammo>0))ms.push("ranged"); if(u.w.melee)ms.push("melee"); return ms; };
  const avgDmg = (u,m)=>{ const w=u.w[m]; let d=(w.dmgMin+w.dmgMax)/2; if(u.team==="enemy")d=Math.max(1,d-1); return d; };
  const coverProxy = (c)=> M.cells[c].nb.filter(n=>!M.passable(n)).length;
  return function actUnit(u){
    let guard=0;
    while(u.hp>0 && !M.over && u.ap>0 && guard++<6){
      const d=M.reach(u); d[u.cell]=0;
      let bestAtk=null;
      for(const cs in d){ const c=+cs; const apCost=M.apForMove(u,d[c]); if(apCost>=u.ap)continue;   // garder >=1 PA pour tirer
        for(const m of modes(u)){ for(const t of M.units){ if(!M.hostile(u,t)||t.hp<=0)continue;
          const ch=M.shotFrom(c,u,t.cell,m); if(ch<=0)continue;
          const dmg=avgDmg(u,m), kill=dmg>=t.hp;
          const score=(ch/100)*dmg*(kill?2.5:1) - apCost*0.15 + (M.cells[c].elev||0)*0.2;
          if(!bestAtk||score>bestAtk.score)bestAtk={c,t,m,score}; } } }
      if(bestAtk){ if(bestAtk.c!==u.cell)M.moveAlong(u,bestAtk.c); if(u.ap>0)M.doAttack(u,bestAtk.t,bestAtk.m); return; }
      const foe=M.nearestOpposing(u); if(!foe)return;
      let best=null,bk=Infinity;
      for(const cs in d){ const c=+cs; if(M.apForMove(u,d[c])>u.ap)continue;
        const k=M.hops(c,foe.cell)*10 - (M.cells[c].elev||0)*2 - coverProxy(c);
        if(k<bk){bk=k;best=c;} }
      if(best==null||best===u.cell)return;
      M.moveAlong(u,best);
    }
  };
}
module.exports = { makeActUnit };
