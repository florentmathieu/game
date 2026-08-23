#!/usr/bin/env python3
"""Lit le Google Sheet « Classes » et en sort les donnees moteur.

Usage :
  1. lire le Sheet avec read_file_content (Google Drive) ; la sortie est
     enregistree dans un fichier tool-results/*.txt
  2. python3 tools/import-classes.py <ce-fichier.txt> [-o /tmp/import.json]

Sorties :
  - un JSON  {classes:{...}, perks:{...}, todo:[...]}  (option -o)
  - sur la sortie standard, un RAPPORT : ce qui est pret a coller, et ce qui
    demande du code.

Le Sheet est la SOURCE ; le depot n en est que le reflet. Ce script ne modifie
jamais index.html : il produit le bloc a coller et la liste de ce qui manque.
Voir tools/sheet-diff.py pour comparer sans importer.
"""
import json, re, sys, argparse

# ---------------------------------------------------------------- lecture brute
def fix_mojibake(t):
    """L export Drive decode mal l UTF-8 sur 4 octets (les emoji arrivent en latin-1)."""
    def rep(m):
        seq = m.group(0)
        try: out = seq.encode("latin-1").decode("utf-8")
        except Exception: return seq
        return out if len(out) == 1 and ord(out) > 0xFFFF else seq
    return re.sub(r"[\u00c0-\u00f4][\u0080-\u00bf]{1,3}", rep, t)

def clean(c):
    c = c.strip()
    c = re.sub(r"^\\\[merged\\\]\s*", "", c)
    c = c.replace("\\<", "<").replace("\\>", ">").replace("\\[", "[").replace("\\]", "]")
    c = re.sub(r"\\(.)", r"\1", c)
    return c.strip()

def parse_rows(block):
    """Une ligne du Sheet = une liste de cellules, POSITIONS CONSERVEES.

    sheet-diff.py fusionne les cellules identiques consecutives ; ici c est
    interdit : « Run and gun » a une description et un effet identiques, et les
    fusionner decalerait toute la ligne d une colonne."""
    rows = []
    for l in block.split("\n"):
        if not l.startswith("|"): continue
        if re.match(r"^\|[\s:\-|]+\|$", l): continue        # separateur markdown
        cells = [clean(x) for x in l.strip().strip("|").split("|")]
        if any(cells): rows.append(cells)
    return rows

def banner(row):
    """Ligne de titre / de section : toutes les cellules non vides sont identiques."""
    nz = [c for c in row if c]
    return nz[0] if nz and len(set(nz)) == 1 and len(nz) > 1 else None

# ---------------------------------------------------------------- vocabulaire
# turn-ending : ce que le joueur ecrit -> ce que le moteur retient
#   Yes        -> la capacite termine le tour (ap = 0)
#   No (1AP)   -> coute 1 PA
#   No (0AP)   -> gratuite (declencheur, posture)
#   N/A / vide -> perk PASSIF (un bonus chiffre, rien a activer)
def parse_turn_ending(v):
    s = (v or "").strip().lower()
    if s in ("", "n/a", "na", "-", "—"): return None                    # passif
    if s.startswith("y") or s in ("oui", "o"): return {"endsTurn": True, "cost": None}
    m = re.search(r"(\d+)\s*ap", s)
    if s.startswith("n") or s.startswith("no"):
        return {"endsTurn": False, "cost": int(m.group(1)) if m else 1}
    return {"endsTurn": False, "cost": int(m.group(1)) if m else 1, "flou": v}

def parse_cd(v):
    """Rend (tours, charges). « 3 » = trois tours d attente ; « 1 charge » = une utilisation
    par combat, ce qui n est PAS un cooldown et se code autrement."""
    s = (v or "").strip().lower()
    if s in ("", "n/a", "na", "-", "—"): return (None, None)
    m = re.search(r"\d+", s)
    n = int(m.group(0)) if m else None
    if re.search(r"charge", s): return (None, n or 1)
    return (n or None, None)

# capacites DEJA CODEES : lues dans index.html pour que ce script ne mente jamais
# sur ce qui existe (l ancien format de Sheet met l identifiant moteur en « effet »).
def abils_du_moteur(path="index.html"):
    try: src = open(path, encoding="utf-8").read()
    except OSError: return set()
    m = re.search(r"const ABIL=\{(.*?)\n  \};", src, re.S)
    ids = set(re.findall(r"^\s*(\w+):\{", m.group(1), re.M)) if m else set()
    # certaines capacites sont des PASSIFS : elles n ont pas d entree dans ABIL (pas de bouton)
    # mais applyPerks les reconnait — « protect » par exemple. Elles comptent comme codees.
    return ids | set(re.findall(r'p\.abil===?"(\w+)"', src))
ABILS = abils_du_moteur()

# effets chiffres reconnus : le reste demande du code
EFFETS = [
    (r"^\+?(\d+)\s*(?:pv|hp)\b",                      "hp"),
    (r"^(?:pv|hp)\s*\+(\d+)",                          "hp"),
    (r"^\+?(\d+)\s*(?:d[ée]g[âa]ts?|damage)\b",        "dmg"),
    (r"^(?:d[ée]g[âa]ts?|damage)\s*\+(\d+)",           "dmg"),
    (r"^\+?(\d+)\s*(?:vis[ée]e|aim)\b",                "aim"),
    (r"^(?:vis[ée]e|aim)\s*\+(\d+)",                   "aim"),
    (r"^\+?(\d+)\s*(?:port[ée]e|range)\b",             "range"),
    (r"^(?:port[ée]e|range)\s*\+(\d+)",                "range"),
    # « déplacement gratuit » AVANT « déplacement » : sinon le second avale le premier
    (r"^\+?(\d+)\s*(?:d[ée]placement gratuit|free mo(?:ve|vement)(?: point)?)",  "freeMp"),
    (r"^\+?(\d+)\s*(?:d[ée]placement|mob(?:ility)?)\s*$", "mob"),
    (r"^\+?(\d+)\s*(?:d[ée]placement|mob(?:ility)?)\b(?! gratuit)", "mob"),
    (r"^\+?(\d+)\s*%?\s*(?:blocage|block)",            "shieldBlock"),
    (r"^\+?(\d+)\s*%?\s*(?:parade|parry)",             "parry"),
    (r"^\+?(\d+)\s*(?:grenades?|crackers?)\b",         "crackers"),
    (r"^\+?(\d+)\s*(?:pr[ée]cision de jet|scatter)\b", "scatter"),
]
def parse_effet(v):
    """Rend {mod:{...}} si l effet tient dans une stat existante, sinon None."""
    s = (v or "").strip()
    if not s: return None
    mod = {}
    for part in re.split(r"\s*[·,;]\s*", s):
        p = part.strip()
        hit = False
        for pat, key in EFFETS:
            m = re.match(pat, p, re.I)
            if m: mod[key] = int(m.group(1)); hit = True; break
        if not hit: return None      # un seul morceau non reconnu = tout l effet est a coder
    return mod or None

# ---------------------------------------------------------------- niveaux
# Une classe soumise a une VOIE ne pioche dans son arbre qu aux niveaux 1, 2, 3
# et 5 (les niveaux 4, 6 et 7 viennent de la voie). Le Sheet numerote ses lignes
# « grade 1..n » de facon continue : c est le RANG du choix, pas le niveau.
NIV_VOIE   = [4, 6, 7]
NIV_MAX    = 7
DISPENSEES = {"mage"}
def niveaux_de_classe(key):
    if key in DISPENSEES: return list(range(1, NIV_MAX + 1))
    return [l for l in range(1, NIV_MAX + 1) if l not in NIV_VOIE]

PREFIXE = {"soldat":"se","sapeur":"sa","assassin":"as","garde":"ga","mage":"mg",
           "sergent":"se","brute":"br"}

# ---------------------------------------------------------------- lecture d un onglet
LIG_ID = {"key":"key","nom affiché":"name","vrai nom":"trueName","camp":"camp"}
LIG_ST = {"pv":"hp","déplacement":"mob","blocage %":"shieldBlock","parade %":"parry",
          "furtif":"stealth","poids génération":"weight"}

def lire_onglet(rows):
    o = {"titre": None, "armes": [], "capacites": [], "arbre": [], "arbre_cols": None}
    for r in rows:
        b = banner(r)
        if b and o["titre"] is None and re.search(r"\s[-—]\s", b): o["titre"] = b; break
    i, mode = 0, None
    while i < len(rows):
        r = rows[i]; b = banner(r)
        if b:
            u = b.upper()
            mode = ("armes" if u.startswith("ARMES") else "cap" if u.startswith("CAPACIT")
                    else "arbre" if u.startswith("ARBRE") else None)
            i += 1; continue
        lab = r[0] if r else ""
        if lab in LIG_ID and len(r) > 1: o[LIG_ID[lab]] = r[1]
        elif lab in LIG_ST and len(r) > 1: o.setdefault("stats", {})[LIG_ST[lab]] = r[1]
        elif mode == "armes" and lab == "emplacement": o["armes_cols"] = r
        elif mode == "armes" and lab.startswith("arme"):
            cols = o.get("armes_cols") or []
            o["armes"].append({(cols[j] if j < len(cols) and cols[j] else f"c{j}"): v
                               for j, v in enumerate(r) if v})
        elif mode == "cap" and lab == "nom": pass
        elif mode == "cap" and lab and not lab.startswith("«"):
            o["capacites"].append({"nom": lab, "desc": r[1] if len(r) > 1 else "",
                                   "moteur": r[2] if len(r) > 2 else ""})
        elif mode == "arbre" and lab == "grade": o["arbre_cols"] = r
        elif mode == "arbre" and re.fullmatch(r"\d+", lab):
            cols = o["arbre_cols"] or []
            o["arbre"].append({(cols[j] if j < len(cols) else f"c{j}"): v
                               for j, v in enumerate(r)})
        i += 1
    return o

# ---------------------------------------------------------------- construction
def perk(o, ligne, cote, key, rang, todo, niveau=None):
    g = lambda c: (ligne.get(f"{cote} : {c}") or "").strip()
    nom = g("nom")
    if not nom: return None
    # l identifiant suit le NIVEAU, pas le rang : « se5a » reste « se5a » meme s il est 4e de la
    # liste. Ces identifiants sont dans les sauvegardes ; les renumeroter perdrait des perks.
    pid = f"{PREFIXE.get(key, key[:2])}{niveau or rang}{cote.lower()}"
    p = {"id": pid, "name": nom, "desc": g("description")}
    effet, te = g("effet"), parse_turn_ending(g("turn-ending"))
    cd, charges = parse_cd(g("Cooldown") or g("cooldown"))
    mod = parse_effet(effet)
    connue = effet.strip() in ABILS              # ancien format : « effet » = l identifiant moteur
    if te is None and mod:                       # passif chiffre : rien de plus a faire
        p["mod"] = mod
    elif connue:                                 # capacite deja codee : on la relie, c est tout
        p["abil"] = effet.strip()
        if te:
            if te.get("cost") is not None: p["cost"] = te["cost"]
            if te.get("endsTurn"): p["endsTurn"] = True
        if cd: p["cd"] = cd
        if charges: p["charges"] = charges
    else:
        p["abil"] = "A_CODER"                    # actif : il faudra une entree dans ABIL
        if te:
            if te.get("cost") is not None: p["cost"] = te["cost"]
            if te.get("endsTurn"): p["endsTurn"] = True
        if cd: p["cd"] = cd
        if charges: p["charges"] = charges
        if mod: p["mod"] = mod
        p["_effet"] = effet
        todo.append({"classe": key, "rang": rang, "cote": cote, "id": pid, "nom": nom,
                     "effet": effet, "cost": p.get("cost"), "endsTurn": p.get("endsTurn"),
                     "cd": cd, "charges": charges, "flou": (te or {}).get("flou")})
    return p

def js_perk(p):
    """Un perk en litteral JS, dans l ordre des champs deja utilise par index.html."""
    out = [f'id:"{p["id"]}"', f'name:{json.dumps(p["name"], ensure_ascii=False)}',
           f'desc:{json.dumps(p.get("desc",""), ensure_ascii=False)}']
    if p.get("abil"): out.append(f'abil:"{p["abil"]}"')
    if p.get("mod"):  out.append("mod:{" + ",".join(f"{k}:{v}" for k, v in p["mod"].items()) + "}")
    if p.get("cost") is not None: out.append(f'cost:{p["cost"]}')
    if p.get("endsTurn"): out.append("endsTurn:true")
    if p.get("cd"): out.append(f'cd:{p["cd"]}')
    if p.get("charges"): out.append(f'charges:{p["charges"]}')
    return "{" + ", ".join(out) + "}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fichier"); ap.add_argument("-o", "--out")
    ap.add_argument("--js", action="store_true",
                    help="ecrit sur la sortie standard le bloc PERKS a coller dans index.html")
    a = ap.parse_args()
    raw = fix_mojibake(json.load(open(a.fichier, encoding="utf-8"))["fileContent"])

    onglets = {}
    for block in raw.split("\n\n"):
        rows = parse_rows(block)
        if not rows: continue
        o = lire_onglet(rows)
        k = o.get("key")
        if k and k != "<clé>": onglets[k] = o

    classes, perks, todo, alertes = {}, {}, [], []
    for key, o in onglets.items():
        st = o.get("stats", {})
        num = lambda v: (int(v) if re.fullmatch(r"-?\d+", (v or "").strip()) else None)
        c = {"name": o.get("name", ""), "camp": o.get("camp", "")}
        if o.get("trueName"): c["trueName"] = o["trueName"]
        for k2 in ("hp", "mob", "shieldBlock", "parry"):
            v = num(st.get(k2)); c[k2] = v if v is not None else 0
        c["stealth"] = (st.get("stealth", "").lower().startswith("o"))
        c["armes"] = o["armes"]; c["capacites"] = o["capacites"]
        titre = re.split(r"\s[-—]\s", o.get("titre") or "")[0].strip()
        if titre and c["name"] and titre != c["name"]:
            alertes.append(f"{key}: l onglet s appelle « {titre} » mais « nom affiché » dit « {c['name']} »")
        classes[key] = c

        if c["camp"] != "joueur" or not o["arbre"]: continue
        cols = o["arbre_cols"] or []
        neuf = any("turn-ending" in x for x in cols)
        niv = niveaux_de_classe(key)
        # LA COLONNE « grade » NE VEUT PAS DIRE LA MEME CHOSE DANS LES DEUX FORMATS.
        #   ancien (7 lignes, sans turn-ending) : la ligne est un NIVEAU. Les niveaux de voie
        #     (4, 6, 7) y trainent encore des paires de classe que le moteur n a jamais servies :
        #     on les jette, exactement comme l a fait la compaction des arbres.
        #   nouveau (<= 4 lignes, avec turn-ending) : la ligne est un RANG de choix, deja debarrasse
        #     des niveaux de voie. La ligne 4 est donc le niveau 5.
        arbre = []
        for n, ligne in enumerate(o["arbre"], 1):
            if neuf:
                niveau = niv[n-1] if n <= len(niv) else None
            else:
                niveau = n if n in niv else None
            A = perk(o, ligne, "A", key, n, todo, niveau); B = perk(o, ligne, "B", key, n, todo, niveau)
            if A or B: arbre.append({"rang": n, "niveau": niveau, "A": A, "B": B})
        jetes = [p for p in arbre if p["niveau"] is None]
        if jetes:
            quoi = ("rangs au-delà des %d niveaux de classe" % len(niv) if neuf
                    else "lignes posées sur des niveaux de VOIE (%s)" % ", ".join(map(str, NIV_VOIE)))
            alertes.append(f"{key}: {len(jetes)} ligne(s) ignorée(s) — {quoi} : "
                           + ", ".join(str(p["rang"]) for p in jetes))
        arbre = [p for p in arbre if p["niveau"] is not None]
        if arbre: perks[key] = {"format": "colonnes 2026-08" if neuf else "ancien", "paires": arbre}
        if len(arbre) < len(niv):
            alertes.append(f"{key}: {len(arbre)}/{len(niv)} rangs remplis "
                           f"(niveaux de classe attendus : {', '.join(map(str, niv))})")

    # UN ONGLET SUPPRIME NE SE VOIT PAS TOUT SEUL : le Sheet etant la source, une classe que le
    # moteur connait mais que le classeur n a plus est soit un abandon volontaire, soit une fausse
    # manoeuvre. Dans les deux cas ca se dit, ca ne se devine pas.
    try:
        src = open("index.html", encoding="utf-8").read()
        m = re.search(r"const CLASSES=\{(.*?)\n  \};", src, re.S)
        connues = set(re.findall(r"^\s*(\w+):\{", m.group(1), re.M)) if m else set()
        civiles = set(re.findall(r"(\w+):\{[^\n]*\bciv:true", src))
        orphelines = sorted(connues - civiles - set(onglets) - {"sergent"})
        if orphelines:
            alertes.append("classes du moteur SANS onglet dans le Sheet : "
                           + ", ".join(orphelines) + " — onglet supprimé ou classe abandonnée ?")
    except OSError:
        pass

    # ---------------- rapport
    print(f"Onglets lus : {len(onglets)}   ·   classes joueur avec arbre : {len(perks)}\n")
    for key, tree in perks.items():
        print("=" * 68); print(f"{key}   ({tree['format']})"); print("=" * 68)
        for p in tree["paires"]:
            print(f"  rang {p['rang']}  ->  " + (f"NIVEAU {p['niveau']}" if p["niveau"]
                  else "IGNORÉ (au-delà des niveaux de classe)"))
            for cote in "AB":
                x = p[cote]
                if not x: print(f"     {cote} : —"); continue
                q = ("passif" if "mod" in x and "abil" not in x
                     else "à coder" if x.get("abil") == "A_CODER" else "actif")
                d = []
                if x.get("cost") is not None: d.append(f"{x['cost']} PA")
                if x.get("endsTurn"): d.append("termine le tour")
                if x.get("cd"): d.append(f"cd {x['cd']}")
                if x.get("charges"): d.append(f"{x['charges']} charge(s)")
                if x.get("mod"): d.append(json.dumps(x["mod"], ensure_ascii=False))
                print(f"     {cote} : {x['name']:24} [{q}] {' · '.join(d)}")
        print()
    if alertes:
        print("⚠  À VÉRIFIER"); [print("   ·", x) for x in alertes]; print()
    if todo:
        print(f"🔧 À CODER — {len(todo)} capacité(s) sans équivalent moteur :")
        for t in todo:
            bits = [f"{t['cost']} PA" if t["cost"] is not None else "coût ?",
                    "termine le tour" if t["endsTurn"] else "ne termine pas le tour",
                    f"cd {t['cd']}" if t["cd"] else
                    (f"{t['charges']} charge(s) — PAS un cooldown" if t["charges"] else "sans cooldown")]
            print(f"   {t['id']:6} {t['classe']:9} {t['nom']:24} {' · '.join(bits)}")
            print(f"          effet : {t['effet']}")
            if t["flou"]: print(f"          ⚠ turn-ending illisible : « {t['flou']} »")
        print()
    if a.js:
        print("=" * 68); print("BLOC PERKS — a coller dans index.html"); print("=" * 68)
        for key, tree in perks.items():
            print(f"    {key}:[", end="")
            lignes = []
            for p in tree["paires"]:
                if p["niveau"] is None: continue      # rang au-dela des niveaux de classe
                lignes.append("{" + ", ".join(f"{c}:{js_perk(p[c])}" for c in "AB" if p[c]) + "}")
            print(" " + (",\n              ".join(lignes)) + " ],")
        print()
    if a.out:
        json.dump({"classes": classes, "perks": perks, "todo": todo, "alertes": alertes},
                  open(a.out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("→", a.out)

if __name__ == "__main__": main()
