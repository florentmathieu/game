import json,statistics as st,math,collections
rows=[json.loads(l) for l in open('/tmp/balayage2.ndjson') if l.strip()]
rows=[r for r in rows if 'erreur' not in r and r.get('pods')]
for r in rows:
    r['parPod']=r['cellules']/r['pods']
    r['videPct']=100*r['toursSansContact']/max(1,r['tours'])
bornes=[0,60,90,130,200,10**9]
print(f"{'cel/pod':>10} | {'n':>4} | {'moyenne':>8} | {'médiane':>8} | {'tours (méd.)':>13}")
for a,b in zip(bornes,bornes[1:]):
    v=[r for r in rows if a<=r['parPod']<b]
    lab=f"{a}–{b}" if b<10**8 else f"{a}+"
    print(f"{lab:>10} | {len(v):>4} | {st.mean(r['videPct'] for r in v):>7.0f}% | {st.median(r['videPct'] for r in v):>7.0f}% | {st.median(r['tours'] for r in v):>13.0f}")
c=collections.defaultdict(list)
for r in rows: c[(r['forme'],r['bw'])].append(r['cellules'])
print()
K={}
for f in ['rect','L','S','croix','sablier','anneau','diag']:
    xs=[bw for (ff,bw) in c if ff==f]; ys=[st.mean(c[(f,bw)]) for bw in xs]
    K[f]=sum(x*x*y for x,y in zip(xs,ys))/sum(x**4 for x in xs)
print("k par forme :", {f:round(K[f],2) for f in K})
print()
print(f"{'forme':<9}"+"".join(f"{str(p)+' pods':>12}" for p in [2,3,4,5]))
for f in K:
    print(f"{f:<9}"+"".join(f"{str(round(math.sqrt(80*p/K[f])))+'x'+str(round(math.sqrt(80*p/K[f])*0.8)):>12}" for p in [2,3,4,5]))
print()
print("Défaut actuel : rect 20x16 = 806 cellules, 4 pods -> %.0f cellules/pod" % (806/4))
print("Pour tenir 80 cel/pod à 20x16 en rect, il faudrait %d pods (soit %d ennemis à 3/pod)." % (round(806/80), round(806/80)*3))
