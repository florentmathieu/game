# Campagnes

Une **campagne** enchaîne des **textes** (cutscenes plein écran, comme l'ouverture)
et des **missions** (`missions/*.json`), avec des branchements *victoire* / *défaite*.

## Éditeur visuel

Ouvre `?campaign` (ou le bouton **🎬 Éditeur de campagne** dans la colonne) :

- **＋ Texte** / **＋ Mission** ajoutent un nœud sur le plan de travail.
- **Glisse** un nœud pour le ranger.
- **Tire un fil** depuis la pastille du bas vers un autre nœud pour l'enchaîner :
  - **→** (bleu) : suite d'un nœud *texte* ;
  - **✓** (vert) : nœud joué après une *victoire* de mission ;
  - **✕** (rouge) : nœud joué après une *défaite* (sans cible = on rejoue la mission).
  - Lâcher le fil dans le vide **coupe** le lien.
- Clique un nœud pour l'éditer : un nœud **texte** sélectionne un **fichier `.txt`**
  (listé dans `texts/list.json`), un nœud **mission** choisit la mission. Marque le
  nœud de départ avec **★ départ**.
- Un nœud **mission** peut aussi avoir un **texte d'intro** : un `.txt` joué *sous la
  carte* au lancement de la mission (comme la Scène 1 d'origine), avant de rendre la main.
- **💾 Enregistrer dans le dépôt** publie `campaigns/<nom>.json` + met à jour `campaigns/list.json`
  (token GitHub fine-grained, `Contents: write`). La campagne apparaît dans le menu **▶ Jouer**.

## Persistance des PV

Pendant une campagne, les **points de vie** de l'escouade sont **conservés** d'une mission à
la suivante (mémorisés à chaque victoire). Une nouvelle campagne repart escouade au complet.

## Format

```json
{
  "name": "Campagne",
  "start": "intro",
  "nodes": [
    { "id": "intro", "type": "text", "title": "...", "file": "Opening.txt", "next": "m1", "x": 40, "y": 40 },
    { "id": "m1", "type": "mission", "mission": "mission-1.json", "name": "Mission 1", "intro": "Scene1.txt", "win": "fin", "lose": null, "x": 40, "y": 160 },
    { "id": "fin", "type": "text", "text": "Stiff: ...", "next": null, "x": 300, "y": 160 }
  ]
}
```

Jouable directement via `?playcampaign=demo.json`.
