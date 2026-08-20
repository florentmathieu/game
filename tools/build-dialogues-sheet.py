#!/usr/bin/env python3
"""Genere le classeur d ecriture des DIALOGUES, pre-rempli depuis le depot.

Trois systemes coexistent dans le jeu, le classeur les couvre tous :
  1. textes narratifs  texts/**.txt   (pages "_", repliques "Nom:", attente "…")
  2. triggers de mission  missions/*.json -> tableau "triggers"
  3. textes du geoscape   texts/geoscape.json

Aller-retour fidele : une ligne du .txt = une ligne du Sheet.
Usage : python3 tools/build-dialogues-sheet.py  ->  /tmp/Dialogues.xlsx
"""
import json, glob, os, re
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

F='Arial'
H1  =Font(name=F,size=14,bold=True,color='FFFFFF')
HSEC=Font(name=F,size=11,bold=True,color='FFFFFF')
HCOL=Font(name=F,size=10,bold=True)
BODY=Font(name=F,size=10)
MUTE=Font(name=F,size=9,italic=True,color='666666')
KEYF=Font(name=F,size=10,bold=True,color='7A3E9D')
GOLD=Font(name=F,size=10,bold=True,color='9A6B00')
FILL_T =PatternFill('solid',fgColor='4A2E63')
FILL_S =PatternFill('solid',fgColor='8A6DB5')
FILL_C =PatternFill('solid',fgColor='EFE7F6')
FILL_IN=PatternFill('solid',fgColor='FFF9D6')
FILL_LK=PatternFill('solid',fgColor='EEEEEE')
FILL_BR=PatternFill('solid',fgColor='F0F4F8')   # brief (# ...)
thin=Side(style='thin',color='D8CCE6'); BOX=Border(left=thin,right=thin,top=thin,bottom=thin)
WRAP=Alignment(wrap_text=True,vertical='top')

wb=Workbook(); wb.remove(wb.active)

def title(ws,text,span=6):
    ws.merge_cells(start_row=1,start_column=1,end_row=1,end_column=span)
    c=ws.cell(1,1,text); c.font=H1; c.fill=FILL_T; ws.row_dimensions[1].height=26
def section(ws,r,text,span=6):
    ws.merge_cells(start_row=r,start_column=1,end_row=r,end_column=span)
    c=ws.cell(r,1,text); c.font=HSEC; c.fill=FILL_S; return r+1
def heads(ws,r,hs):
    for i,h in enumerate(hs,1):
        c=ws.cell(r,i,h); c.font=HCOL; c.fill=FILL_C; c.border=BOX; c.alignment=WRAP
    return r+1

# ---------- 1. textes narratifs ----------
def parse_txt(path):
    """-> liste de dict {page, qui, texte} ; les lignes '#' deviennent qui='#'."""
    out=[]; page=1
    for raw in open(path,encoding='utf-8').read().replace('\r','').split('\n'):
        line=raw.rstrip()
        if line.strip()=='_':      page+=1; continue
        if not line.strip():       continue
        if line.lstrip().startswith('#'):
            out.append({'page':page,'qui':'#','texte':line.lstrip().lstrip('#').strip()}); continue
        # REGEX DU MOTEUR (index.html, parseLines) : nom de 1 a 18 caracteres, deux-points, UNE espace.
        m=re.match(r"^([\w\u00C0-\u00FF '.\-]{1,18}):\s(.*)$", line)
        if m: out.append({'page':page,'qui':m.group(1).strip(),'texte':m.group(2).strip()})
        else: out.append({'page':page,'qui':'','texte':line.strip()})
    return out

def text_tab(name, files):
    ws=wb.create_sheet(name)
    title(ws,f"{name} — textes narratifs")
    ws.cell(2,1,"Une ligne = une ligne du fichier. « page » : incremente = saut de page (« _»). « qui » : nom affiche en gras dore ; « # » = commentaire de brief, jamais joue. Texte « … » = page d attente.").font=MUTE
    r=4; r=heads(ws,r,["fichier","page","qui","texte","note"])
    for path in files:
        rel=path.replace('\\','/')
        rows=parse_txt(path)
        c=ws.cell(r,1,rel); c.font=KEYF; c.fill=FILL_LK; c.border=BOX
        ws.merge_cells(start_row=r,start_column=1,end_row=r,end_column=5); r+=1
        for it in rows:
            vals=[ '', it['page'], it['qui'], it['texte'], '' ]
            for i,v in enumerate(vals,1):
                c=ws.cell(r,i,v); c.font=MUTE if it['qui']=='#' else BODY
                c.border=BOX; c.alignment=WRAP
                c.fill=FILL_BR if it['qui']=='#' else (FILL_IN if i>=3 else FILL_LK)
                if i==3 and it['qui'] not in ('','#'): c.font=GOLD
            r+=1
        r+=1
    for col,w in zip("ABCDE",[34,7,16,88,26]): ws.column_dimensions[col].width=w
    ws.freeze_panes='A5'; return ws

root=[p for p in sorted(glob.glob('texts/*.txt')) if os.path.basename(p)!='README.txt']
a1=sorted(glob.glob('texts/acte1/*.txt')); a2=sorted(glob.glob('texts/acte2/*.txt'))
text_tab('Acte 1',a1); text_tab('Acte 2',a2); text_tab('Prototype',root)

# ---------- 2. triggers de mission ----------
ws=wb.create_sheet('Triggers')
title(ws,"Triggers — repliques declenchees en mission",span=10)
ws.cell(2,1,"Une ligne = UNE REPLIQUE. Plusieurs repliques d un meme trigger partagent son numero « n » ; seule la premiere porte les colonnes de reglage. « conditions » : ex. actor=Gizzard ; result=miss ; first=true.").font=MUTE
r=4; r=heads(ws,r,["mission","n","on","conditions","qui","replique","une fois","priorite","id","requiert","interdit","actions"])
def fmt_val(v):
    if isinstance(v,bool): return "true" if v else "false"       # meme ecriture que le JSON du moteur
    if isinstance(v,(dict,list)): return json.dumps(v,ensure_ascii=False)
    return str(v)
def fmt_match(m):
    return " ; ".join(f"{k}={fmt_val(v)}" for k,v in (m or {}).items())
def split_lines(t):
    """-> [(qui, texte), ...] : une replique par element, jamais de saut de ligne en cellule."""
    ls=t.get('lines') or ([t['say']] if t.get('say') else [])
    out=[]
    for l in ls:
        if isinstance(l,dict): out.append((l.get('who',''), l.get('text','')))
        elif isinstance(l,list) and len(l)>=2: out.append((str(l[0]), str(l[1])))
        else: out.append(('', str(l)))
    return out or [('','')]
def fmt_actions(t):
    a=[]
    for k in ('wake','open','close','spawn'):
        if t.get(k) is not None: a.append(f"{k}={json.dumps(t[k],ensure_ascii=False)}")
    return " ; ".join(a)
n=0
for path in sorted(glob.glob('missions/*.json'))+sorted(glob.glob('missions-mesh/*.json')):
    try: d=json.load(open(path,encoding='utf-8'))
    except Exception: continue
    if not isinstance(d,dict): continue
    for t in (d.get('triggers') or []):
        n+=1
        reps=split_lines(t)
        for j,(qui,txt) in enumerate(reps):
            meta = (j==0)
            vals=[path if meta else '', n, t.get('on','') if meta else '',
                  fmt_match(t.get('match')) if meta else '', qui, txt,
                  ('oui' if t.get('once',True) else 'non') if meta else '',
                  t.get('priority',0) if meta else '',
                  t.get('id','') if meta else '', t.get('requires','') if meta else '',
                  t.get('forbids','') if meta else '', fmt_actions(t) if meta else '']
            for i,v in enumerate(vals,1):
                c=ws.cell(r,i,v if not isinstance(v,(list,dict)) else json.dumps(v,ensure_ascii=False))
                c.font=BODY; c.border=BOX; c.alignment=WRAP
                c.fill=FILL_LK if i in (1,2) else FILL_IN
                if i==5 and v: c.font=GOLD
            r+=1
for k in range(6):
    for i in range(1,13):
        c=ws.cell(r,i,''); c.border=BOX; c.fill=FILL_LK if i in (1,2) else FILL_IN
    r+=1
for col,w in zip("ABCDEFGHIJKL",[26,5,12,32,14,58,9,9,12,14,14,24]): ws.column_dimensions[col].width=w
ws.freeze_panes='A5'
TRIG_N=n

# ---------- 3. geoscape ----------
ws=wb.create_sheet('Geoscape')
title(ws,"Geoscape — messages systeme et narration par acte",span=5)
ws.cell(2,1,"Le geoscape est PROCEDURAL : la narration y est par ACTE, pas par region nommee.").font=MUTE
r=4; r=heads(ws,r,["section","cle","page","texte","note"])
geo=json.load(open('texts/geoscape.json',encoding='utf-8'))
def walk(prefix,obj):
    global r
    if isinstance(obj,dict):
        for k,v in obj.items():
            if k=='_comment': continue
            walk(prefix+[k],v)
    elif isinstance(obj,list):
        for i,v in enumerate(obj): walk(prefix+[str(i)],v)
    else:
        page=1; first=True
        for line in str(obj).replace('\r','').split('\n'):
            if line.strip()=='_': page+=1; continue
            vals=[(prefix[0] if prefix else '') if first else '',
                  (".".join(prefix[1:])) if first else '', page, line.strip(), '']
            for i,v in enumerate(vals,1):
                c=ws.cell(r,i,v); c.font=BODY; c.border=BOX; c.alignment=WRAP
                c.fill=FILL_IN if i>=3 else FILL_LK
            r+=1; first=False
        if first:
            vals=[prefix[0] if prefix else '', ".".join(prefix[1:]), 1, '', '']
            for i,v in enumerate(vals,1):
                c=ws.cell(r,i,v); c.font=BODY; c.border=BOX; c.alignment=WRAP
                c.fill=FILL_IN if i>=3 else FILL_LK
            r+=1
walk([],geo)
GEO_N=r-5
for col,w in zip("ABCDE",[16,30,7,86,22]): ws.column_dimensions[col].width=w
ws.freeze_panes='A5'

# ---------- REFERENCE ----------
ws=wb.create_sheet('RÉFÉRENCE',0)
title(ws,"RÉFÉRENCE — format du lecteur et evenements disponibles",span=4)
r=3
r=section(ws,r,"FORMAT DU LECTEUR DE TEXTE",span=4)
for k,v in [("colonne « page »","Quand le numero augmente, le jeu passe a la page suivante (equivaut a une ligne « _ » dans le .txt)."),
            ("colonne « qui »","Un nom -> la replique s affiche avec le nom en gras dore. Vide -> texte de narration. « # » -> commentaire de brief, jamais joue."),
            ("texte « … »","Page d attente / silence, sautable par le joueur."),
            ("[...]","Marqueur d ecriture : passage a remplacer.")]:
    a=ws.cell(r,1,k); a.font=HCOL; a.fill=FILL_LK; a.border=BOX
    b=ws.cell(r,2,v); b.font=BODY; b.border=BOX; b.alignment=WRAP
    ws.merge_cells(start_row=r,start_column=2,end_row=r,end_column=4); r+=1
r+=1
r=section(ws,r,"EVENEMENTS DE TRIGGER (colonne « on ») ET LEUR CONTEXTE",span=4)
r=heads(ws,r,["on","champs utilisables dans « conditions »"])
for k,v in [("start","(aucun)"),("turn","turn (numero)"),
  ("attack","actor, target, weapon, result (hit/miss/blocked), killed, dmg, reaction, first, actorTeam"),
  ("kill","actor, target, weapon"),
  ("wounded","target, by, hp, maxHp, hpPct (0-100), killed"),
  ("cracker","actor, enemiesHit, alliesHit, killed, first"),
  ("friendlyfire","actor, target, targetTeam, weapon, dmg, killed"),
  ("move","actor, col, row, steps"),("enter","actor, zone, col, row"),
  ("spotted","pod, actorTeam (enemy/neutral), by (sight/noise)"),
  ("discovered","pod, actorTeam"),("win / lose","(fin de partie)")]:
    a=ws.cell(r,1,k); a.font=KEYF; a.border=BOX
    b=ws.cell(r,2,v); b.font=BODY; b.border=BOX; b.alignment=WRAP
    ws.merge_cells(start_row=r,start_column=2,end_row=r,end_column=4); r+=1
r+=1
r=section(ws,r,"ACTIONS POSSIBLES (colonne « actions »)",span=4)
for k,v in [("wake","reveille un pod : 0, 1, … ou \"all\""),
            ("open / close","ouvre ou ferme un passage : nom de zone"),
            ("spawn","renforts : [{\"cls\":\"brute\",\"team\":\"enemy\",\"col\":8,\"row\":2}]")]:
    a=ws.cell(r,1,k); a.font=KEYF; a.border=BOX
    b=ws.cell(r,2,v); b.font=BODY; b.border=BOX; b.alignment=WRAP
    ws.merge_cells(start_row=r,start_column=2,end_row=r,end_column=4); r+=1
r+=1
r=section(ws,r,"REGLES A CONNAITRE",span=4)
for t in ["Ne pas renommer les en-tetes de colonnes : c est ce qui permet de relire le classeur.",
          "Ne pas modifier la colonne « fichier » : elle dit dans quel .txt la ligne sera reecrite.",
          "Une ligne « # » est un brief d ecriture : elle n est jamais jouee, garde-la ou supprime-la.",
          "Cellules jaunes = a ecrire. Cellules grises = structure.",
          "Les repliques d un trigger : une par ligne dans la cellule, forme « Nom: texte ».",
          "PIEGE FR : le moteur lit toute ligne « Mot: texte » (nom de 1 a 18 signes) comme une REPLIQUE. Donc « Resolution : on etouffe… » affiche « Resolution » en nom dore. Pour de la prose, evite les deux-points apres un mot court en debut de ligne."]:
    c=ws.cell(r,1,"• "+t); c.font=BODY; c.alignment=WRAP
    ws.merge_cells(start_row=r,start_column=1,end_row=r,end_column=4); r+=1
for col,w in zip("ABCD",[24,60,20,20]): ws.column_dimensions[col].width=w

# ---------- INDEX ----------
ws=wb.create_sheet('INDEX',0)
title(ws,"INDEX — ecriture des dialogues",span=5)
ws.cell(2,1,"Pre-rempli depuis le depot. Cellules jaunes = a ecrire. Voir l onglet RÉFÉRENCE pour le format.").font=MUTE
r=4; r=heads(ws,r,["onglet","contenu","source","lignes","etat"])
rows=[("Acte 1","textes narratifs de l acte 1","texts/acte1/*.txt",len(a1),"a reecrire"),
      ("Acte 2","textes narratifs de l acte 2","texts/acte2/*.txt",len(a2),"a reecrire"),
      ("Prototype","anciens textes du prototype (reference de ton)","texts/*.txt",len(root),"reference"),
      ("Triggers","repliques declenchees en mission","missions/*.json",TRIG_N,"a etoffer"),
      ("Geoscape","messages systeme + narration par acte","texts/geoscape.json",GEO_N,"a reecrire")]
for t in rows:
    for i,v in enumerate(t,1):
        c=ws.cell(r,i,v); c.font=BODY if i>1 else KEYF; c.border=BOX; c.alignment=WRAP
        if i==5: c.fill=FILL_IN
    r+=1
ws.cell(r+1,1,"Les fichiers .txt gardent leurs briefs en commentaire (lignes « # ») : ils indiquent role narratif, beat et persos suggeres.").font=MUTE
for col,w in zip("ABCDE",[16,44,26,10,18]): ws.column_dimensions[col].width=w
ws.freeze_panes='A5'

wb.save('/tmp/Dialogues.xlsx')
print("onglets :", ", ".join(wb.sheetnames))
print("acte1:",len(a1),"fichiers · acte2:",len(a2),"· prototype:",len(root),"· triggers:",TRIG_N,"· geoscape:",GEO_N,"lignes")
