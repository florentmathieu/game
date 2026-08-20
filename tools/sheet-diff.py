#!/usr/bin/env python3
"""Compare le Google Sheet de conception des classes a la reference du depot.

Usage :
  1. lire le Sheet avec read_file_content (Google Drive) ; la sortie est
     enregistree dans un fichier tool-results/*.txt
  2. python3 tools/sheet-diff.py <ce-fichier.txt>

Neutralise les artefacts de l export Markdown (echappements \\+, cellules
fusionnees, formules deja evaluees) pour ne montrer que les vraies
modifications. Reference : tools/classes-baseline.json
"""
import json, re, difflib

import sys
F=sys.argv[1] if len(sys.argv)>1 else sys.exit("usage: sheet-diff.py <fichier-resultat-read_file_content.txt>")
raw = json.load(open(F, encoding="utf-8"))["fileContent"]

def _fix_mojibake(t):
    """L export Drive decode mal l UTF-8 sur 4 octets : les emoji arrivent en latin-1.
    On repare uniquement les suites qui redonnent un caractere hors BMP (decodage strict),
    ce qui laisse intacts les accents et les guillemets francais."""
    def rep(m):
        seq = m.group(0)
        try:
            out = seq.encode("latin-1").decode("utf-8")
        except Exception:
            return seq
        return out if len(out) == 1 and ord(out) > 0xFFFF else seq
    return re.sub(r"[\u00c0-\u00f4][\u0080-\u00bf]{1,3}", rep, t)

raw = _fix_mojibake(raw)

def clean(c):
    c = c.strip()
    c = re.sub(r"^\\\[merged\\\]\s*", "", c)
    c = c.replace("\\<","<").replace("\\>",">").replace("\\[","[").replace("\\]","]")
    c = re.sub(r"\\(.)", r"\1", c)   # desechappe l export Markdown
    return c.strip()

def parse_rows(block):
    rows=[]
    for l in block.split("\n"):
        if not l.startswith("|"): continue
        if re.match(r"^\|[\s:\-|]+\|$", l): continue           # ligne de séparation markdown
        cells=[clean(x) for x in l.strip().strip("|").split("|")]
        ded=[]                                                  # collapse des cellules fusionnées répétées
        for c in cells:
            if ded and c and c==ded[-1]: continue
            ded.append(c)
        while ded and ded[-1]=="": ded.pop()
        if any(ded): rows.append(ded)
    return rows

blocks=[b for b in raw.split("\n\n") if b.strip()]
cur={}
for b in blocks:
    rows=parse_rows(b)
    key=None
    for r in rows:
        if r and r[0]=="key" and len(r)>1: key=r[1]; break
    title=rows[0][0] if rows else "?"
    name=title.split("—")[0].strip() if "—" in title else title
    cur[key or name]={"titre":title,"rows":rows}

BASE=sys.argv[2] if len(sys.argv)>2 else "tools/classes-baseline.json"   # 2e argument : autre reference (ex. tools/dialogues-baseline.json)
base_doc=json.load(open(BASE,encoding="utf-8"))
bt=base_doc["onglets"]
base={}
for tab,rows in bt.items():
    norm=[[str(c).strip() for c in r] for r in rows]
    for r in norm:
        while r and r[-1]=="": r.pop()
    norm=[r for r in norm if any(r)]
    key=None
    for r in norm:
        if r and r[0]=="key" and len(r)>1: key=r[1]
    base[key or tab]={"onglet":tab,"rows":norm}

def sig(rows): return ["|".join(("<calc>" if str(c).startswith("=") else c) for c in r if c) for r in rows]

print("Référence :",len(base),"onglets   ·   Sheet :",len(cur),"onglets\n")
missing=[k for k in base if k not in cur]
added=[k for k in cur if k not in base]
if missing: print("❌ ABSENTS du Sheet :", ", ".join(f"{base[k]['onglet']} (key={k})" for k in missing))
if added:   print("➕ NOUVEAUX onglets :", ", ".join(f"{cur[k]['titre']} (key={k})" for k in added))
print()

def known(tab,l):
    if tab=="RÉFÉRENCE" and l.startswith("protect"): return True
    if tab in ("Cleaner","Wrecker","Barricade") and re.match(r"^arme [12]\|",l): return True
    return False

n=0
for k in cur:
    if k not in base: continue
    a,b = sig(base[k]["rows"]), sig(cur[k]["rows"])
    # aligne les cellules calculées : côté Sheet la formule est déjà évaluée
    for idx,(x,y) in enumerate(zip(a,b)):
        if "<calc>" in x:
            parts_a, parts_b = x.split("|"), y.split("|")
            if len(parts_a)==len(parts_b):
                b[idx]="|".join(pa if pa=="<calc>" else pb for pa,pb in zip(parts_a,parts_b))
    tab = base[k]["onglet"]
    if a==b: continue
    chunks=[]
    for op,i1,i2,j1,j2 in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes():
        if op=="equal": continue
        old=[x for x in a[i1:i2] if not known(tab,x)]
        new=[x for x in b[j1:j2] if not known(tab,x)]
        if old or new: chunks.append((old,new))
    if not chunks: continue
    n+=1
    print("="*68); print(f"ONGLET  {tab}   (key={k})"); print("="*68)
    for old,new in chunks:
        for x in old: print("   avant :", x[:190])
        for x in new: print("   APRÈS :", x[:190])
        print()
print(f"→ {n} onglet(s) avec des modifications de contenu." if n else "→ aucune modification de contenu.")
