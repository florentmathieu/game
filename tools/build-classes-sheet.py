import json
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

d = json.load(open('/tmp/classes.json'))
CL, PK = d['CLASSES'], d['PERKS']

F = 'Arial'
H1   = Font(name=F, size=14, bold=True, color='FFFFFF')
HSEC = Font(name=F, size=11, bold=True, color='FFFFFF')
HCOL = Font(name=F, size=10, bold=True)
BODY = Font(name=F, size=10)
MUTE = Font(name=F, size=9, italic=True, color='666666')
KEYF = Font(name=F, size=10, bold=True, color='7A3E9D')

FILL_T  = PatternFill('solid', fgColor='4A2E63')   # titre
FILL_S  = PatternFill('solid', fgColor='8A6DB5')   # section
FILL_C  = PatternFill('solid', fgColor='EFE7F6')   # entêtes de colonnes
FILL_IN = PatternFill('solid', fgColor='FFF9D6')   # à remplir
FILL_LK = PatternFill('solid', fgColor='EEEEEE')   # ne pas modifier
thin = Side(style='thin', color='D8CCE6')
BOX = Border(left=thin, right=thin, top=thin, bottom=thin)
WRAP = Alignment(wrap_text=True, vertical='top')

ABILS = "smoke breach shadowstrike rally vanish taunt holdline wall protect blast heal frost shove charge".split()
EFFETS = ["+X pv","+X dégât","+X visée","+X portée","+X déplacement","+X blocage %",
          "+X parade %","+X grenade","+X précision de jet","+X déplacement gratuit"]

wb = Workbook(); wb.remove(wb.active)

def title(ws, text, span=7):
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=span)
    c = ws.cell(1,1,text); c.font = H1; c.fill = FILL_T
    c.alignment = Alignment(vertical='center'); ws.row_dimensions[1].height = 26

def section(ws, r, text, span=7):
    ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=span)
    c = ws.cell(r,1,text); c.font = HSEC; c.fill = FILL_S
    return r+1

def kv(ws, r, label, value, lock=False, note=None):
    a = ws.cell(r,1,label); a.font = HCOL; a.fill = FILL_LK; a.border = BOX
    b = ws.cell(r,2,value); b.font = KEYF if lock else BODY
    b.fill = FILL_LK if lock else FILL_IN; b.border = BOX; b.alignment = WRAP
    if note:
        n = ws.cell(r,3,note); n.font = MUTE; n.alignment = WRAP
    return r+1

def colheads(ws, r, heads):
    for i,h in enumerate(heads,1):
        c = ws.cell(r,i,h); c.font = HCOL; c.fill = FILL_C; c.border = BOX; c.alignment = WRAP
    return r+1

# ---------- traduction des données moteur ----------
CAMP = {}
for k,v in CL.items():
    CAMP[k] = 'civil' if v.get('civ') else ('ennemi' if v.get('enemyOnly') else 'joueur')

WEIGHTS = {'archer':3,'emage':2,'brute':2,'shieldbearer':1,'rival':0,'contact':0}

EFF_LABEL = {'hp':'pv','dmg':'dégât','aim':'visée','range':'portée','mob':'déplacement',
             'shieldBlock':'blocage %','parry':'parade %','crackers':'grenade',
             'scatter':'précision de jet','freeMp':'déplacement gratuit'}

# Une classe soumise a une VOIE ne pioche dans son arbre qu aux niveaux 1, 2, 3 et 5.
NIV_VOIE   = [4, 6, 7]
DISPENSEES = {'mage'}

def turn_ending(p):
    """Ce que le moteur sait aujourd hui d une paire : un perk a `mod` est passif, un perk a
    `abil` est actif. Le cout exact vient des exec* et n est pas lisible ici : on laisse la
    cellule a remplir plutot que d y ecrire une valeur inventee."""
    if not p: return ''
    return '' if p.get('abil') else ('N/A' if p.get('mod') else '')

def cd_of(p):
    return '' if not p else ('' if p.get('abil') else ('N/A' if p.get('mod') else ''))

def perk_effect(p):
    if p.get('abil'): return p['abil']
    m = p.get('mod') or {}
    return ' · '.join(f"+{v} {EFF_LABEL.get(kk,kk)}" for kk,v in m.items()) or ''



TABS = {  # key -> nom d'onglet
 'soldat':'Enforcer','sapeur':'Sapper','assassin':'Stinger','mage':'Siphoner',
 'archer':'Irregular','brute':'Wrecker','shieldbearer':'Barricade','emage':'WildSiphoner',
 'rival':'Counterparty'}
ORDER = ['soldat','sapeur','assassin','mage','archer','brute','shieldbearer','emage','rival']

# nouvelles pistes (univers Ore) — onglets vierges
NOUVELLES = [
 ('seer','Seer','ennemi',"Ore-touché. Voit à travers le brouillard et le décor, et tire dessus. Aveugle au corps à corps."),
 ('relay','Relay','ennemi',"Ore-touché. Ne t'attaque pas : il alimente les autres (portée/dégâts). Cible prioritaire, sans défense."),
 ('kindler','Kindler','ennemi',"Ore-touché. Brûle sa réserve pour un burst énorme, puis s'effondre. Le suicide économique en un tour."),
 ('vessel','Vessel','ennemi',"Ore-touché. Peau minéralisée, encaisse énormément. Lent, et l'Ore le tue lentement."),
 ('poacher','Poacher','ennemi',"Non augmenté. Pose pièges et mines avant ton arrivée : la lande est à eux."),
 ('leech','Leech','ennemi',"Ore-touché. Draine l'Ore ou l'équipement de tes soldats. Le vol te vole."),
]

def build_class_tab(key, tabname, data, perks, blank=False):
    ws = wb.create_sheet(tabname)
    title(ws, f"{data.get('name',tabname)}   —   {CAMP.get(key,'ennemi')}")
    r = 3
    r = section(ws, r, "IDENTITÉ")
    r = kv(ws, r, "key", key, lock=True, note="identifiant moteur — NE JAMAIS MODIFIER")
    r = kv(ws, r, "nom affiché", data.get('name',''), note="la désignation officielle de l'État")
    r = kv(ws, r, "vrai nom", data.get('trueName',''), note="pour la bascule de fin (revealTruth)")
    r = kv(ws, r, "camp", CAMP.get(key,'ennemi'), note="joueur / ennemi / civil")
    r += 1
    r = section(ws, r, "STATS")
    r = kv(ws, r, "pv", '' if blank else data.get('hp',''))
    r = kv(ws, r, "déplacement", '' if blank else data.get('mob',''))
    r = kv(ws, r, "blocage %", '' if blank else data.get('shieldBlock',0))
    r = kv(ws, r, "parade %", '' if blank else data.get('parry',0))
    r = kv(ws, r, "furtif", '' if blank else ('oui' if data.get('stealth') else 'non'))
    r = kv(ws, r, "poids génération", '' if blank else WEIGHTS.get(key,''),
           note="0 = n'apparaît que si la campagne l'invoque")
    r += 1
    r = section(ws, r, "ARMES")
    r = colheads(ws, r, ["emplacement","type","nom","visée","dmg min","dmg max","portée","chargeur","notes"])
    w = data.get('w') or {}
    rows = []
    if not blank:
        if w.get('ranged'):
            x = w['ranged']; rows.append(["arme %d"%(len(rows)+1),"distance",data.get('wname',''),x.get('aim'),x.get('dmgMin'),x.get('dmgMax'),x.get('range'),x.get('clip') or '—',''])
        if w.get('melee'):
            x = w['melee']; fl = x.get('flank') or {}
            note = f"flanc dos +{fl['back']} / côté +{fl['side']}" if fl else ''
            rows.append(["arme %d"%(len(rows)+1),"contact",'',x.get('aim'),x.get('dmgMin'),x.get('dmgMax'),'—','',note])
        if w.get('cracker'):
            x = w['cracker']; rows.append(["arme %d"%(len(rows)+1),"jet",'charge',' ',x.get('dmgMin'),x.get('dmgMax'),x.get('range'),data.get('crackers',''),f"rayon {x.get('radius')} · dispersion {x.get('scatter')}"])
    while len(rows) < 3: rows.append([f"arme {len(rows)+1}",'','','','','','','',''])
    for row in rows:
        for i,v in enumerate(row,1):
            c = ws.cell(r,i,v); c.font = BODY; c.border = BOX
            c.fill = FILL_IN if i>1 else FILL_LK
            c.alignment = WRAP
        r += 1
    r += 1
    r = section(ws, r, "CAPACITÉS")
    r = colheads(ws, r, ["nom","description (langage naturel)","moteur"])
    abil = [] if blank else (data.get('abil') or [])
    caps = [[a, '', a] for a in abil]
    while len(caps) < 4: caps.append(['','',''])
    for row in caps:
        for i,v in enumerate(row,1):
            c = ws.cell(r,i,v); c.font = BODY; c.border = BOX; c.fill = FILL_IN; c.alignment = WRAP
        ws.cell(r,2).alignment = WRAP
        r += 1
    n = ws.cell(r,1,"« moteur » = un identifiant existant (voir RÉFÉRENCE) ou À CODER si la capacité n'existe pas encore.")
    n.font = MUTE; r += 2

    if CAMP.get(key) == 'joueur':
        # Sept niveaux, dont trois viennent de la VOIE (4, 6, 7) : une classe soumise à la voie ne
        # choisit dans son arbre qu'aux niveaux 1, 2, 3 et 5 — quatre lignes, pas sept. Le mage,
        # dispensé de voie, garde les sept. La colonne « grade » numérote les CHOIX, pas les niveaux.
        niv = list(range(1,8)) if key in DISPENSEES else [l for l in range(1,8) if l not in NIV_VOIE]
        r = section(ws, r, f"ARBRE DE COMPÉTENCES  —  {len(niv)} choix de classe, A ou B, irréversible",
                    span=11)
        r = colheads(ws, r, ["grade","A : nom","A : description","A : effet","A : turn-ending","A : Cooldown",
                                     "B : nom","B : description","B : effet","B : turn-ending","B : Cooldown"])
        for g,lvl in enumerate(niv):
            p = perks[g] if perks and g < len(perks) else None
            A = (p or {}).get('A') or {}; B = (p or {}).get('B') or {}
            vals = [g+1, A.get('name',''), A.get('desc',''), perk_effect(A), turn_ending(A), cd_of(A),
                          B.get('name',''), B.get('desc',''), perk_effect(B), turn_ending(B), cd_of(B)]
            for i,v in enumerate(vals,1):
                c = ws.cell(r,i,v); c.font = BODY; c.border = BOX; c.alignment = WRAP
                c.fill = FILL_LK if i==1 else FILL_IN
            ws.row_dimensions[r].height = 28
            r += 1
        n = ws.cell(r,1,f"Les {len(niv)} lignes doivent être remplies : une ligne vide bloque la montée "
                        f"du personnage. « grade » = le RANG du choix — le rang {len(niv)} est le niveau {niv[-1]}."
                        + ("" if key in DISPENSEES else f"  Les niveaux {', '.join(map(str,NIV_VOIE))} viennent de la voie (Officier / Vétéran), pas d'ici."))
        n.font = MUTE
        r += 1
        n = ws.cell(r,1,"« turn-ending » : Yes = termine le tour · No (1AP) / No (0AP) = coût en PA · "
                        "N/A = perk passif (rien à activer).   « Cooldown » : nombre de tours, 0 ou N/A si aucun.")
        n.font = MUTE
    else:
        n = ws.cell(r,1,"Classe ennemie : pas d'arbre de compétences (les perks ne concernent que les classes joueur).")
        n.font = MUTE

    for col,wid in zip("ABCDEFGHIJK",[20,30,34,16,14,11,26,34,16,14,11]):
        ws.column_dimensions[col].width = wid
    ws.freeze_panes = 'A3'
    return ws

# ---------- onglets de classes ----------
for k in ORDER:
    build_class_tab(k, TABS[k], CL[k], PK.get(k))
for key, tab, camp, _ in NOUVELLES:
    CAMP[key] = camp
    build_class_tab(key, tab, {'name':tab,'trueName':'','w':{}}, None, blank=True)

# ---------- MODÈLE ----------
CAMP['<clé>'] = 'joueur'
mod = build_class_tab('<clé>', 'MODÈLE', {'name':'<nom affiché>','trueName':'','w':{}}, None, blank=True)
mod.cell(2,1,"Onglet vierge à dupliquer pour toute nouvelle classe. Remplace <clé> par un identifiant court sans accent.").font = MUTE

# ---------- RÉFÉRENCE ----------
ws = wb.create_sheet('RÉFÉRENCE', 0)
title(ws, "RÉFÉRENCE — ce que le moteur sait déjà faire", span=4)
r = 3
r = section(ws, r, "CAPACITÉS EXISTANTES (à mettre en colonne « moteur »)", span=4)
desc = {'smoke':'Voile la ligne de vue (zone, 2 tours)','breach':'Détruit un rocher / muret, ouvre un passage',
 'shadowstrike':'Bond vers le flanc ou le dos d’un ennemi + dégâts','rally':'Rend 1 PA à un allié adjacent',
 'vanish':'Redevient indétectable un tour (1×/combat)','taunt':'Les ennemis te ciblent en priorité',
 'holdline':'Vigilance au profit des alliés adjacents','wall':'Donne un couvert aux alliés adjacents','protect':'Intercepte un coup destiné à un allié adjacent (passif)',
 'blast':'Explosion de zone (dégâts de souffle)','heal':'Soigne un allié à distance',
 'frost':'Ralentit un ennemi (−1 PA à son tour)','shove':'Repousse d’une case (50 % étourdi)',
 'charge':'Course puis attaque ; impact selon la distance parcourue'}
r = colheads(ws, r, ["identifiant","ce que ça fait"])
for a in ABILS:
    ws.cell(r,1,a).font = KEYF; ws.cell(r,1).border = BOX
    c = ws.cell(r,2,desc[a]); c.font = BODY; c.border = BOX; c.alignment = WRAP
    r += 1
r += 1
r = section(ws, r, "EFFETS CHIFFRÉS DE PERK (colonne « effet »)", span=4)
for e in EFFETS:
    c = ws.cell(r,1,e); c.font = BODY; c.border = BOX; c.fill = FILL_LK; r += 1
r += 1
r = section(ws, r, "RÈGLES À CONNAÎTRE", span=4)
for t in ["La colonne A (les intitulés) ne doit pas être renommée : c'est elle qui me permet de relire les onglets.",
          "La ligne « key » ne doit jamais changer : elle relie la classe à ses perks et aux sauvegardes existantes.",
          "Une classe JOUEUR à voie a besoin de 4 choix × (A et B) — les niveaux 4, 6 et 7 viennent de la voie. Le mage, dispensé, en a 7. Une classe ENNEMIE n'a pas d'arbre.",
          "« turn-ending » : Yes = la capacité termine le tour · No (1AP) ou No (0AP) = son coût en PA · N/A = perk passif.",
          "« Cooldown » : le nombre de tours avant réutilisation. 0 ou N/A = aucun.",
          "Tout effet ou capacité hors des listes ci-dessus est possible, mais demande du code : écris-le et marque À CODER.",
          "Portées de référence : équipe joueur 7 · Irregular 9 · Contact 10. La portée est le levier le plus expressif.",
          "Cellules jaunes = à remplir. Cellules grises = structure, ne pas toucher."]:
    c = ws.cell(r,1,"• "+t); c.font = BODY; c.alignment = WRAP
    ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=4)
    ws.row_dimensions[r].height = 16
    r += 1
for col,wid in zip("ABCD",[26,64,20,20]): ws.column_dimensions[col].width = wid

# ---------- INDEX ----------
ws = wb.create_sheet('INDEX', 0)
title(ws, "INDEX DES CLASSES", span=6)
ws.cell(2,1,"Un onglet par classe. Cellules jaunes = à remplir. Voir l'onglet RÉFÉRENCE pour les capacités et effets disponibles.").font = MUTE
r = 4
r = colheads(ws, r, ["key","onglet","camp","état","grades remplis (auto)","note"])
rows = [(k, TABS[k], CAMP[k], "valeurs actuelles du jeu — à réécrire", "") for k in ORDER]
rows += [(key, tab, camp, "à écrire", "piste proposée (univers Ore)") for key,tab,camp,_ in NOUVELLES]
rows += [(k, "—", "civil", "pas d'onglet : PV/déplacement seulement", "") for k in ('homme','femme','enfant')]
for key, tab, camp, etat, note in rows:
    ws.cell(r,1,key).font = KEYF
    ws.cell(r,2,tab).font = BODY
    ws.cell(r,3,camp).font = BODY
    c = ws.cell(r,4,etat); c.font = BODY; c.fill = FILL_IN
    if camp == 'joueur' and tab != '—':
        ws.cell(r,5,f"=COUNTA('{tab}'!B34:B40)").font = BODY
    else:
        ws.cell(r,5,"—").font = MUTE
    ws.cell(r,6,note).font = MUTE
    for i in range(1,7): ws.cell(r,i).border = BOX; ws.cell(r,i).alignment = WRAP
    r += 1
ws.cell(r+1,1,"« grades remplis » compte les noms de perk du côté A : 4 pour une classe à voie (niveaux 1, 2, 3, 5), 7 pour le mage.").font = MUTE
for col,wid in zip("ABCDEF",[16,18,12,34,22,34]): ws.column_dimensions[col].width = wid
ws.freeze_panes = 'A5'

wb.save('/tmp/Classes.xlsx')
print("écrit — onglets :", len(wb.sheetnames))
print(", ".join(wb.sheetnames))
