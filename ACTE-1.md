# Concept — Acte 1 / Prologue

_Spécification de l'Acte 1, première brique jouable de la campagne. Traduit la direction (`DIRECTION.md`) et le thème en structure concrète. Sert de plan de construction._

> **Pitch.** On appartient à un **camp** dont dépend un petit **territoire**, découpé en **~12 régions** (cellules de maillage) : c'est le **geoscape de départ**. L'acte ouvre sur une **mission d'intro** (elle pose les personnages et le ton, cf. `Opening.txt` — **texte à réécrire** : il porte encore l'ancien thème de la réalité distordue), puis le joueur arrive sur le **geoscape**, voit sa carte, et **choisit** par où continuer.

**La boucle de l'acte :**

```
Intro (mission)  →  GEOSCAPE (voir la carte, choisir une région)  →  Mission de région
                         ↑                                                  │
                         └──────────────  retour (win ET lose)  ◄───────────┘
   … jusqu'à la condition de fin d'acte  →  Acte 2 / interlude
```

---

## 1. Le territoire (la carte geoscape)

- **~12 cellules.** Une = **le camp** (le hub dont dépend le territoire, point de retour). Les autres = **régions**.
- Chaque cellule porte : `nom`, `type` (camp | région), `contenu` (mission liée | événement | vide), `état` (verrouillé | disponible | nettoyé | perdu/menacé), et ses `voisins` (= l'adjacence naturelle du maillage).
- **Géométrie :** maillage **grossier généré** (seed) via `genMesh`, puis cellules **nommées/annotées à la main**.
- **Choix réel dès l'intro** (pilier A3) : à la sortie de l'intro, **≥ 2-3 régions disponibles** simultanément — sinon « choisir » est factice.

---

## 2. Les pièces à construire (architecture décidée)

### A. Format de donnée geoscape *(nouveau — dossier `geoscapes-mesh/`)*
Le maillage réutilise le `form` des missions (`infl`/`dens`/`seed`) ; on annote les cellules :

```
{
  "name": "Acte 1 — Territoire du camp",
  "mesh": { "form": { "infl": [...], "dens": 90, "seed": 1234 } },
  "camp": "c0",
  "cells": [
    { "id": "c0", "name": "Le Camp", "type": "camp",
      "content": { "kind": "empty" }, "state": "available" },
    { "id": "c3", "name": "Bois brûlé", "type": "region",
      "content": { "kind": "mission", "ref": "mission-1.json" },
      "state": "available", "unlockedBy": [] },
    { "id": "c7", "name": "Gué de l'aval", "type": "region",
      "content": { "kind": "mission", "ref": "mission-2.json" },
      "state": "locked", "unlockedBy": ["c3"] }
  ]
}
```
*(les `voisins` sont dérivés de la géométrie, pas stockés à la main)*

### B. Nœud `geoscape` dans le graphe de campagne *(extension de l'éditeur)*
Un nouveau `type` de nœud, à côté de `text` et `mission` :

```
{ "id": "g1", "type": "geoscape", "map": "acte1.json",
  "endWhen": { "cleared": ["c11"] },   // condition de fin d'acte
  "next": "n_acte2",                    // où aller quand endWhen est vrai
  "x": ..., "y": ... }
```
- L'intro `win → g1`.
- À l'entrée de `g1` : on **affiche la carte**. Le joueur clique une région `disponible` → lance la mission liée (`content.ref`).
- La mission de région `win/lose →` **revient à `g1`** (et met à jour les états : `cleared`, déverrouillage des voisins…).
- **Échec qui fait avancer (C4) :** `lose` revient aussi à `g1`, mais marque la région `perdu`/monte une menace — **jamais** un reload.
- Quand `endWhen` est satisfait → `next` (Acte 2 / interlude).

### C. Runtime geoscape jouable *(le livrable « on voit la map »)*
L'écran qui : charge la map, **rend le maillage**, colorie les états (dispo / verrouillé / nettoyé / perdu), montre les régions cliquables + leur info (nom, type de mission, menace), lance la mission, et y revient.

### D. Persistance du roster
Les **mêmes personnages nommés** d'une mission à l'autre. La *progression* (perks) est différée, mais **l'identité et le roster persistent** dans l'état de campagne (indispensable pour C1/B9 : on s'attache, on perd).

---

## 3. Ancrage direction — les piliers actifs dès l'Acte 1

| Pilier | Présence en Acte 1 |
|---|---|
| **A3 Choix concurrent** | ≥ 3 régions disponibles à la sortie de l'intro |
| **C4 Échec fait avancer** | `lose` → état changé (région perdue / menace), pas de reload |
| **C1/B9 Identité & mort** | Roster nommé persistant ; statut spécial des persos clés de l'intro |
| **Thème (géométrie)** | La carte du monde **est** un maillage, et il se déforme au fil de l'acte — *fait*. **À réorienter** : nouvel univers = grille régulière reconquise par l'organique qui bloque le passage |
| **A1 Horloge locale** | *(option, peut être différée)* une menace par région qui monte si on tarde |

---

## 4. Contenu minimal pour la tranche Acte 1

- **1 camp** + **intro** — déjà en place : `Opening.txt`, `mission-1.json`, `Mission1-beginning/​end.txt`.
- **3 régions** avec mission (dont au moins une réutilise `mission-1` au départ).
- **1 région-clé** dont le nettoyage = **fin d'acte**.
- **Interludes** déjà écrits (`Interlude1…4`) branchés aux transitions.

---

## 5. Ordre de construction (après ce doc) — ✅ **fait**

> Les quatre étapes ci-dessous sont réalisées : le format geoscape, le nœud de campagne, le runtime jouable et la boucle complète sont en place.

1. **Format geoscape + éditeur dédié** : génération grossière (`genMesh`), nommage des cellules, marquage du camp, liaison cellule→mission, états/déverrouillages. *(la fondation)*
2. **Nœud `geoscape`** dans l'éditeur de campagne + câblage du retour (win/lose → geoscape) et de `endWhen`.
3. **Runtime geoscape jouable** : rendu + sélection + lancement + retour.
4. **Câbler le contenu minimal** de l'Acte 1 et **tester la boucle complète** (intro → carte → choix → mission → retour → fin d'acte).

---

## 6. Différé — *état août 2026*

- ✅ **Progression des personnages** (perks A/B par grade) — **faite** (grades, arbres A/B irréversibles, XP plafonné).
- ⬜ **Détail de l'horloge locale** (A1) — toujours ouvert (cf. `PLAN-SUITE.md`, phase E).
- 🟡 **Déformation visuelle progressive** de la carte — **faite**, mais **à réorienter** avec le nouvel univers (grille → organique, cf. `DIRECTION.md`).
- ⬜ **Dosage du hasard en combat** (friction 1) — toujours ouvert ; le RNG est désormais **seedable** (déterminisme), ce qui permet de le calibrer par simulation.
