// Génère un territoire geoscape (polygones Voronoï réels) en répliquant fidèlement
// genMesh() de index.html, puis annote les cellules (camp, régions, missions, états,
// déverrouillages). Sortie : un fichier JSON geoscape prêt à charger.
// Usage : node tools/gen-geoscape.cjs > geoscapes-mesh/acte1.json
'use strict';
const MC = 72;
const mk = s => () => { s|=0; s=s+0x6D2B79F5|0; let t=Math.imul(s^s>>>15,1|s); t=t+Math.imul(t^t>>>7,61|t)^t; return ((t^t>>>14)>>>0)/4294967296; };
function polyCentroid(p){ let A=0,cx=0,cy=0; for(let i=0;i<p.length;i++){const a=p[i],b=p[(i+1)%p.length];const cr=a[0]*b[1]-b[0]*a[1];A+=cr;cx+=(a[0]+b[0])*cr;cy+=(a[1]+b[1])*cr;} A*=0.5;
  if(Math.abs(A)<1e-6){let sx=0,sy=0;for(const v of p){sx+=v[0];sy+=v[1];}return [sx/p.length,sy/p.length];} return [cx/(6*A),cy/(6*A)]; }
// réplique exacte de genMesh (zones "mix" → carré/hexa/pentagone, jitter, Voronoï clippé à la boîte)
function genMesh(W,H,infl,COLS,ROWS,seed,g,distPct){
  const dist=distPct/100, rnd=mk(seed), h=g*0.866, jit=a=>(rnd()*2-1)*a;
  const typeAt=(x,y)=>infl[Math.min(ROWS-1,Math.floor(y/MC))][Math.min(COLS-1,Math.floor(x/MC))];
  const seeds=[];
  for(let j=-1;j*Math.min(g,h)<H+g;j++)for(let i=-1;i*g<W+g;i++){
    let x=i*g,y=j*g; let t=typeAt(Math.max(0,Math.min(W-1,i*g)),Math.max(0,Math.min(H-1,j*g))),amp=dist*g*0.42;
    if(t==="mix"){const pick=Math.floor(rnd()*3);t=["square","hex","pentagon"][pick];}
    if(t==="hex"){x=i*g+(j&1?g/2:0);y=j*h;}else if(t==="pentagon"){x=i*g+(j&1?g/2:0);amp+=g*0.16;}
    x+=jit(amp);y+=jit(amp);
    if(x>-g&&x<W+g&&y>-g&&y<H+g){ const md2=(g*0.5)**2; let ok=true; for(const s of seeds){const dx=s[0]-x,dy=s[1]-y;if(dx*dx+dy*dy<md2){ok=false;break;}} if(ok)seeds.push([x,y]); }
  }
  const box=[[0,0],[W,0],[W,H],[0,H]];
  function clip(poly,p,q){const mx=(p[0]+q[0])/2,my=(p[1]+q[1])/2,nx=p[0]-q[0],ny=p[1]-q[1],ins=v=>(v[0]-mx)*nx+(v[1]-my)*ny>=0,out=[];
    for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],ia=ins(a),ib=ins(b);if(ia)out.push(a);if(ia!==ib){const den=(b[0]-a[0])*nx+(b[1]-a[1])*ny;if(den!==0){const tt=((mx-a[0])*nx+(my-a[1])*ny)/den;out.push([a[0]+tt*(b[0]-a[0]),a[1]+tt*(b[1]-a[1])]);}}}return out;}
  const R=g*2.8; const cells=[];
  for(let i=0;i<seeds.length;i++){const p=seeds[i];let poly=box;for(let k=0;k<seeds.length;k++){if(k===i)continue;const q=seeds[k];if(Math.abs(q[0]-p[0])>R||Math.abs(q[1]-p[1])>R)continue;poly=clip(poly,p,q);if(poly.length<3)break;}
    if(poly.length>=3){const cl=[];for(let v=0;v<poly.length;v++){const a=poly[v],b=cl[cl.length-1];if(!b||Math.hypot(a[0]-b[0],a[1]-b[1])>0.8)cl.push(a);}if(cl.length>=2&&Math.hypot(cl[0][0]-cl[cl.length-1][0],cl[0][1]-cl[cl.length-1][1])<0.8)cl.pop();
      if(cl.length>=3){const ct=polyCentroid(cl);cells.push({poly:cl.map(p=>[Math.round(p[0]),Math.round(p[1])]),cx:ct[0],cy:ct[1]});}}}
  // effet « île » : retire les cellules qui touchent le bord du rectangle
  const EPS=0.6; return cells.filter(c=>!c.poly.some(p=>p[0]<=EPS||p[0]>=W-EPS||p[1]<=EPS||p[1]>=H-EPS));
}

// --- paramètres du territoire de l'Acte 1 ---
const W=720, H=560, COLS=Math.ceil(W/MC), ROWS=Math.ceil(H/MC), seed=20240625, target=10, dist=28;
const infl=Array.from({length:ROWS},()=>Array(COLS).fill("mix"));   // territoire varié (carré/hexa/pentagone)
// espacement ajusté pour viser ~target régions (même logique itérative que l'éditeur)
let g=Math.max(60,Math.round(Math.sqrt(W*H/target)*0.95)), cells;
for(let it=0;it<16;it++){ cells=genMesh(W,H,infl,COLS,ROWS,seed,g,dist); const n=cells.length; if(n>target*1.2)g=Math.round(g*1.1); else if(n<target*0.8)g=Math.round(g*0.9); else break; }

// --- annotation ---
const cx0=W/2, cy0=H/2;
const order=cells.map((c,i)=>({i,d:Math.hypot(c.cx-cx0,c.cy-cy0)})).sort((a,b)=>a.d-b.d);
const campIdx=order[0].i;   // cellule la plus centrale = le camp
const NAMES=["Bois brûlé","Gué de l'aval","Carrière noyée","Hameau muet","Tourbière","Crête venteuse","Vieux moulin","Lisière grise","Ravin","Bastion"];
const regionsByDist=order.slice(1);   // toutes sauf le camp, du plus proche au plus loin
const out={ name:"Acte 1 — Territoire du camp", mesh:{ infl, seed, g, cols:COLS, rows:ROWS }, camp:campIdx,
  cells: cells.map((c,i)=>({ poly:c.poly, name:"", type:"region", content:{kind:"empty",ref:null}, state:"locked", unlockedBy:[] })) };
out.cells[campIdx]={ ...out.cells[campIdx], name:"Le Camp", type:"camp", content:{kind:"empty",ref:null}, state:"available" };
regionsByDist.forEach((o,k)=>{ const cell=out.cells[o.i];
  cell.name=NAMES[k%NAMES.length];
  cell.content={kind:"mission",ref:"mission-1.json"};
  if(k<2){ cell.state="available"; cell.unlockedBy=[]; }                       // 2 régions ouvertes dès l'arrivée
  else { cell.state="locked"; cell.unlockedBy=[ regionsByDist[k-2].i ]; }       // chaîne de déverrouillage en éventail
});
// la région la plus lointaine = "Bastion" (clé de fin d'acte)
const lastIdx=regionsByDist[regionsByDist.length-1].i;
out.cells[lastIdx].name="Bastion";

process.stdout.write(JSON.stringify(out));
