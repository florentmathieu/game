# Campagnes

Une **campagne** enchaîne des **textes** (cutscenes plein écran, comme l'ouverture),
des **missions** (`missions/*.json`) et des **choix** de parcours, avec des branchements
*victoire* / *défaite*.

## Éditeur visuel

Ouvre `?campaign` (ou le bouton **🎬 Éditeur de campagne** dans la colonne) :

- **＋ Texte** / **＋ Mission** / **＋ Choix** ajoutent un nœud sur le plan de travail.
- **Glisse** un nœud pour le ranger.
- **Tire un fil** depuis la pastille du bas vers un autre nœud pour l'enchaîner :
  - **→** (bleu) : suite d'un nœud *texte* ;
  - **✓** (vert) : nœud joué après une *victoire* de mission ;
  - **✕** (rouge) : nœud joué après une *défaite* (sans cible = on rejoue la mission) ;
  - **＋** (or) : ajoute une **route** depuis un nœud *Choix* ;
  - Lâcher le fil dans le vide **coupe** le lien.
- Clique un nœud pour l'éditer : un nœud **texte** sélectionne un **fichier `.txt`**
  (listé dans `texts/list.json`), un nœud **mission** choisit la mission. Marque le
  nœud de départ avec **★ départ**.
- Un nœud **mission** peut avoir un **texte d'intro** (`.txt` joué *sous la carte* comme
  la Scène 1), un **texte de fin** (`outro`, joué en bas de l'écran après la victoire, avant
  de continuer) et un **descriptif** affiché au survol dans le menu de parcours.
- **💾 Enregistrer dans le dépôt** publie `campaigns/<nom>.json` + met à jour `campaigns/list.json`
  (token GitHub fine-grained, `Contents: write`). La campagne apparaît dans le menu **▶ Jouer**.

## Choix de parcours (arbre de missions)

Un nœud **Choix** propose **plusieurs routes** (chacune pointant vers une mission, un texte
ou un autre choix). En jeu, quand on l'atteint, un **menu de parcours** s'affiche : l'arbre
de la campagne, les routes proposées en surbrillance. **Survole** une route pour lire son
descriptif, **clique** pour t'y engager (après confirmation). On y branche typiquement la
**victoire** d'une mission vers un Choix. Bouton **👁 Aperçu du parcours** dans l'éditeur
pour prévisualiser le menu (Échap pour revenir).

## Persistance des PV

Pendant une campagne, les **points de vie** de l'escouade sont **conservés** d'une mission à
la suivante (mémorisés à chaque victoire). Une nouvelle campagne repart escouade au complet.

## Format

```json
{
  "name": "Campagne",
  "start": "intro",
  "nodes": [
    { "id": "intro", "type": "text", "title": "...", "file": "texts/Opening.txt", "next": "m1", "x": 40, "y": 40 },
    { "id": "m1", "type": "mission", "mission": "mission-1.json", "name": "Mission 1", "intro": "texts/Scene1.txt", "desc": "blurb au survol", "win": "carrefour", "lose": null, "x": 40, "y": 160 },
    { "id": "carrefour", "type": "choice", "title": "Quelle route ?", "options": ["m2", "m3"], "x": 40, "y": 290 },
    { "id": "m2", "type": "mission", "mission": "mission-2.json", "name": "Voie discrète", "desc": "...", "win": "fin", "lose": null, "x": 250, "y": 420 },
    { "id": "m3", "type": "mission", "mission": "mission-3.json", "name": "Voie directe", "desc": "...", "win": "fin", "lose": null, "x": 470, "y": 420 },
    { "id": "fin", "type": "text", "file": "texts/demo-fin.txt", "next": null, "x": 250, "y": 550 }
  ]
}
```

Jouable directement via `?playcampaign=demo.json`.
