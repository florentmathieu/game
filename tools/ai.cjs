// ⚠ LIMITE CONNUE : le déplacement d'ESCOUADE (4 unités) souffre d'agglutination
// (cooperative pathfinding) — les unités se bloquent mutuellement à un anneau de distance
// et n'atteignent pas l'ennemi -> beaucoup de timeouts. Confirmé par captures (terrain ouvert,
// pas de mur/falaise). L'IA naïve de sim-mesh.cjs engage ~50% ; celle-ci moins. À retravailler
// avec une vraie résolution coopérative (réservation de cases / yield) ou des duels 1v-pod.
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
    while(u.hp>0 && !M.over && (u.ap>0||u.freeAvail) && guard++<8){
      const d=M.reach(u); d[u.cell]=0;
      let bestAtk=null;
      for(const cs in d){ const c=+cs; const apCost=M.apForMove(u,d[c]); if(apCost>=u.ap)continue;   // garder >=1 PA pour tirer
        for(const m of modes(u)){ for(const t of M.units){ if(!M.hostile(u,t)||t.hp<=0)continue;
          const ch=M.shotFrom(c,u,t.cell,m); if(ch<=0)continue;
          const dmg=avgDmg(u,m), kill=dmg>=t.hp;
          const score=(ch/100)*dmg*(kill?2.5:1) - apCost*0.15 + (M.cells[c].elev||0)*0.2;
          if(!bestAtk||score>bestAtk.score)bestAtk={c,t,m,score}; } } }
      if(bestAtk){ if(bestAtk.c!==u.cell)M.moveAlong(u,bestAtk.c); if(u.ap>0)M.doAttack(u,bestAtk.t,bestAtk.m); return; }
      // pas de tir : avancer vers la case ATTEIGNABLE la plus proche de l'ennemi (sauts) — simple et robuste
      const foe=M.nearestOpposing(u); if(!foe)return;
      const cur=M.hops(u.cell,foe.cell);
      let best=null,bk=cur;                                            // n'accepter qu'un STRICT rapprochement (anti-oscillation)
      for(const cs in d){ const c=+cs; if(c===u.cell)continue; const h=M.hops(c,foe.cell); if(h<bk){bk=h;best=c;} }
      if(best==null)return;                                            // bloqué (cases avant occupées) : tenir, laisser passer les autres
      M.moveAlong(u,best);
    }
  };
}
module.exports = { makeActUnit };
