# Taille de plateau : ce que disent 560 parties

_Mesure, pas opinion. Chaque ligne du tableau vient de parties réellement jouées par le moteur —
IA ennemie, pods, vigilance, brouillard, réactions — via `window.SIMULER()`. Données brutes :
`tools/balayage-taille.ndjson`. Rejouer : `node tools/balayage-taille.js`, puis
`python3 tools/analyse-balayage.py`._

## La question

Quelle taille de plateau pour quelle forme, selon le nombre de pods ? Aucune mesure statique ne la
tranche : il faut compter les **tours de marche à vide**, ceux où l'escouade avance sans personne en
vue. C'est le coût réel d'un plateau trop grand — pas un chiffre de surface.

## Protocole

7 formes × 4 tailles × 4 nombres de pods × 5 répétitions = **560 parties**, 3 ennemis par pod pour
isoler la variable, 120 tours maximum.

**Escouade blindée.** L'IA joueur du simulateur est faible : en combat réel elle perd 4 hommes sur 4
et tue 2 ennemis sur 5, *même à 10x8 en 4 contre 5*, la configuration calibrée. Une mission qui
s'arrête au tour 8 parce que l'escouade est anéantie ne mesure pas le coût d'un plateau, elle mesure
la maladresse du pilote. En rendant l'escouade invulnérable, chaque partie va à son terme et
« tours » redevient le temps de traverser et de nettoyer la carte. **Ces chiffres décrivent donc le
rythme d'une carte, pas sa difficulté.**

## Le résultat : c'est la surface PAR POD qui commande

| cellules par pod | parties | marche à vide (moyenne) | (médiane) | tours (médiane) |
|---|---|---|---|---|
| ≤ 60 | 218 | 17 % | 12 % | 23 |
| 60 – 90 | 96 | 27 % | 23 % | 24 |
| 90 – 130 | 118 | 38 % | 33 % | 28 |
| 130 – 200 | 83 | 46 % | 45 % | 25 |
| 200 + | 45 | 59 % | 55 % | 25 |

La courbe est strictement monotone, et **elle est la même à 2, 3, 4 et 5 pods** (vérifié à nombre de
pods constant : 17/18/16/17 % dans la première tranche, 60/53/61 % dans la dernière). Le nombre de
pods n'a donc pas d'effet propre : il n'agit qu'en divisant la surface.

Autre enseignement : la **durée** d'une mission ne dépend presque pas de la taille (23 à 28 tours
partout). Ce qui change, c'est la **proportion** passée à marcher sans rien voir.

> **Réserve.** L'écart-type de la marche à vide est de 18 à 20 points, avec une queue à droite
> (jusqu'à 99 %) : ce sont les parties où l'IA erre sans trouver le dernier pod. Les moyennes par
> case (n = 5) ne sont donc **pas** fiables — seules les tranches agrégées (n = 45 à 218) le sont.

## Le seuil

**80 cellules par pod.** C'est là que la marche à vide passe 30 % : 27 % dans la tranche 60–90,
38 % dans la suivante.

## Conversion par forme

Les formes n'ont pas la même surface à réglages égaux — une croix à 20x16 ne fait que 389 cellules
là où un rectangle en fait 806. Mesuré, `cellules ≈ k × largeur²` :

| forme | 10x8 | 13x10 | 16x13 | 20x16 | k |
|---|---|---|---|---|---|
| rect | 174 | 306 | 509 | 806 | 1,98 |
| S | 129 | 220 | 363 | 572 | 1,41 |
| anneau | 115 | 215 | 363 | 572 | 1,40 |
| L | 114 | 198 | 320 | 506 | 1,25 |
| diagonale | 106 | 176 | 296 | 468 | 1,15 |
| sablier | 107 | 177 | 289 | 464 | 1,14 |
| croix | 97 | 156 | 243 | 389 | 0,96 |

D'où **largeur = √(80 × pods / k)**, hauteur ≈ 0,8 × largeur :

| forme | 2 pods | 3 pods | 4 pods | 5 pods |
|---|---|---|---|---|
| rect | 9x7 | 11x9 | 13x10 | 14x11 |
| L | 11x9 | 14x11 | 16x13 | 18x14 |
| S | 11x9 | 13x10 | 15x12 | 17x13 |
| croix | 13x10 | 16x13 | 18x15 | 20x16 |
| sablier | 12x9 | 15x12 | 17x13 | 19x15 |
| anneau | 11x9 | 13x10 | 15x12 | 17x14 |
| diagonale | 12x9 | 14x12 | 17x13 | 19x15 |

## Ce que ça dit du défaut actuel

Le plateau par défaut — **rect 20x16, 806 cellules, 4 pods** — fait **202 cellules par pod**, soit la
dernière tranche du tableau : **~59 % de marche à vide**. C'est cohérent avec la mesure directe faite
avant le balayage (69 % sur cinq parties).

Deux sorties, et une seule est raisonnable :

- **Ramener le rectangle à 13x10** pour 4 pods.
- **Garder 20x16** et monter à **10 pods**, soit 30 ennemis à 3 par pod. Injouable au tour par tour.

La croix est le seul cas où 20x16 se tient — parce qu'elle n'a que 389 cellules — et seulement à
5 pods.

---

# Recalibration : 60 cellules par pod, pas 80

_Ajouté après le câblage. 252 parties supplémentaires._

Les 80 cellules par pod ci-dessus ont été mesurées **dans les conditions du balayage**, qui mettait
**3 ennemis par poche**. Le jeu, lui, en met 2 (`ENNEMIS_PAR_POD`), pour ne pas gonfler une
difficulté déjà réglée par ailleurs. Moins d'ennemis à trouver sur la même surface, donc plus de
marche : câblé à 80, le taux réel remontait à 39 %.

Le seuil a donc été recalibré **aux conditions réelles du jeu**, en rejouant 252 parties à trois
valeurs :

| `CEL_PAR_POD` | cellules/pod obtenues | marche à vide (médiane) | tours (médiane) | missions terminées |
|---|---|---|---|---|
| 45 | 43 | 22 % | 14 | 92 % |
| **60** | **57** | **30 %** | **17** | 94 % |
| 80 | 79 | 39 % | 20 | 94 % |

**Retenu : 60.** C'est la valeur qui tient la cible des 30 %, pour des missions de 17 tours de
médiane. Les deux chiffres — 80 et 60 — sont justes chacun dans ses conditions ; c'est le nombre
d'ennemis par poche qui les sépare. Si tu remontes `ENNEMIS_PAR_POD` à 3, remonte `CEL_PAR_POD` à 80.

## Ce que ça donne en jeu

`largeur = √(60 × pods / k)`, hauteur = 0,8 × largeur :

| forme | facile (2 pods) | moyen (3 pods) | difficile (4 pods) |
|---|---|---|---|
| rect | 8x6 · 104 cel | 10x8 · 185 cel | 11x9 · 238 cel |
| croix | 11x9 · 109 cel | 14x11 · 185 cel | 16x13 · 247 cel |
| anneau | 9x7 · 87 cel | 11x9 · 160 cel | 13x10 · 215 cel |

Mesuré à la génération, toutes formes confondues : **44 à 62 cellules par pod**, un seul secteur
fortement connexe, toutes les plateformes accessibles, aucun ennemi visible au tour 1, tous les
ennemis joignables.

## Réglages

Panneau d'équilibrage, groupe « Board size » :

- **`CEL_PAR_POD`** — le seuil. Le baisser resserre les cartes, le monter les aère.
- **`PODS_DIFF`** — poches par difficulté (2 / 3 / 4). **C'est le seul réglage à toucher pour durcir
  une mission** : il ajoute un engagement, et le plateau s'agrandit juste assez pour l'accueillir.
- **`ENNEMIS_PAR_POD`** — plancher d'ennemis par poche (2).

Case **« 📐 auto size »** dans l'éditeur de mission pour revenir au dimensionnement manuel : les
champs Width/Height et Pods redeviennent souverains.

---

# Interaction avec le profil de terrain de l'acte

Le profil de terrain fait varier la **densité** du maillage au fil de l'acte (46 au début, 38 à la
fin) : à taille de plateau égale, cela change le nombre de cellules — mesuré **180 à densité 46,
211 à 42, 233 à 38**. Sans correction, les cellules par pod dérivaient de 30 % le long de l'acte et
la calibration ci-dessus ne tenait plus.

L'exposant n'est pas 2 mais **1,35** (le rognage des bords amortit), et `k` a été mesuré à la densité
de référence **44**. Le dimensionnement corrige donc :

```
k_effectif = k_forme × (44 / densité)^1,35
largeur    = √(CEL_PAR_POD × pods / k_effectif)
```

L'ordre d'exécution compte, et il est contre-intuitif :

1. **calculer** le profil interpolé — il donne la densité, dont dépend la taille ;
2. **redimensionner** — `setBoardSize()` réécrit la grille de zones ;
3. **appliquer** le profil — il remplit la grille aux dimensions finales ;
4. **mailler**.

Vérifié sur les 7 formes × 3 moments de l'acte : **51 à 66 cellules par pod** pour une cible de 60,
pendant que la géométrie passe de 3,4 à 5,4 voisins de moyenne. Aucune anomalie — un seul secteur
fortement connexe, plateformes accessibles, aucun ennemi visible au tour 1, tous joignables.
