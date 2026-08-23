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

## Révision : 75, sur demande de jeu

Le réglage à 60 tenait la cible des 30 % de marche à vide, mais **★1 se jouait sur un mouchoir** :
une seule poche, donc 6x6 après plancher, soit une trentaine de cases praticables. Trop petit à
l'usage. Deux changements, mesurés avant/après sur 25 parties par palier (escouade blindée, forme
rect, ★1 à ★4) :

- `CEL_PAR_POD` **60 → 75** ;
- plancher de largeur **6 → 7** (et hauteur 5 → 6), pour ★1 qui est borné par le plancher et non
  par la formule.

| ★ | cellules/pod 60 → 75 | marche à vide (méd.) | tours (méd.) |
|---|---|---|---|
| ★1 | 90 → 90 | 14 % → **13 %** | 11 → 9 |
| ★2 | 54 → 72 | 33 % → **40 %** | 12 → 14 |
| ★3 | 62 → 77 | 47 % → **50 %** | 22 → 27 |
| ★4 | 59 → 72 | 36 % → **39 %** | 28 → 30 |

Coût réel : **+3 à +7 points** de marche à vide et **+2 à +5 tours**. ★1 ne bouge pas, parce qu'il
était déjà borné par le plancher — l'agrandir ne lui coûte rien, une poche unique se trouve vite.

> Le plancher a été porté à 7 et pas à 8 : il gonfle la surface **sans ajouter d'ennemis**, donc il
> creuse ★1 mécaniquement. 7x6 est le compromis ; au-delà, ★1 redevient la carte la plus vide du jeu.

(Les taux de cette table sont plus hauts que les 30 % du tableau de calibration : protocole
différent — escouade blindée, mesure par palier et non agrégée. Seul le **delta** compte ici.)

## Ce que ça donne en jeu

`largeur = √(75 × pods / k)`, hauteur = 0,8 × largeur, plancher 7x6 :

| forme | ★1 | ★2 | ★3 | ★4 | ★5 |
|---|---|---|---|---|---|
| rect | 7x6 | 9x7 | 11x9 | 12x10 | 14x11 |
| croix | 9x7 | 13x10 | 15x12 | 18x14 | 20x16 |
| anneau | 7x6 | 10x8 | 13x10 | 15x12 | 16x13 |
| L | 8x6 | 11x9 | 13x10 | 15x12 | 17x14 |

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

---

# Recette d'acte : tout se pilote avant

Un acte se décrit au lieu de s'assembler : longueur, courbe de difficulté, formes autorisées,
objectifs tirés, profil de terrain, **graine**. À paramètres et graine identiques on retombe sur le
**même acte** ; on change la graine pour en tirer un autre du même caractère. La recette voyage avec
l'acte (champ `recette` du JSON de campagne), donc il reste regénérable.

Les missions sont **générées** — un nœud de campagne peut porter une recette (`gen`) au lieu de
pointer vers un fichier. C'est ce qui rend l'acte reproductible sans traîner des fichiers de mission.

Exemple de plan (graine 1, 6 missions, facile → difficile) :

| rang | difficulté | forme | objectif | pods | plateau | distorsion |
|---|---|---|---|---|---|---|
| 1 | facile | sablier | eliminate | 2 | 11x9 | 0 % |
| 2 | facile | croix | harvest | 2 | 11x9 | 11 % |
| 3 | moyen | diagonale | eliminate | 3 | 12x10 | 22 % |
| 4 | moyen | sablier | extract | 3 | 12x10 | 33 % |
| 5 | difficile | S | harvest | 4 | 12x10 | 44 % |
| 6 | difficile | croix | assassinate | 4 | 14x11 | 55 % |

## Distorsion et difficulté : deux axes, pas un

**La distorsion suit le rang de la mission dans l'acte, pas sa difficulté.** Dans un acte dont la
difficulté monte avec le rang, les deux paraissent liés — le tableau ci-dessus le montre — mais c'est
une corrélation, pas une cause : un acte à difficulté constante aurait la même courbe de distorsion.

Un **second axe** existe désormais, `bonusDiff`, qui ajoute (ou retire) de la distorsion selon la
difficulté de la mission, indépendamment du rang. **Nul par défaut**, pour que les deux effets restent
démêlables. Exemple avec facile −10, moyen 0, difficile +25 sur le même acte :

| rang | difficulté | distorsion sans | avec |
|---|---|---|---|
| 1 | facile | 0 % | 0 % |
| 2 | facile | 11 % | 1 % |
| 3 | moyen | 22 % | 22 % |
| 4 | moyen | 33 % | 33 % |
| 5 | difficile | 44 % | 69 % |
| 6 | difficile | 55 % | 80 % |

## Vérification du bout en bout

63 parties jouées (21 par difficulté, 7 formes, escouade blindée) sur des missions produites par la
recette :

| difficulté | cellules | par pod | tours (méd.) | marche à vide (méd.) | non nettoyées |
|---|---|---|---|---|---|
| facile | 106 | 53 | 10 | 26 % | 0/21 |
| moyen | 178 | 59 | 19 | 33 % | 2/21 |
| difficile | 248 | 62 | 23 | 24 % | 3/21 |

La marche à vide reste sur la cible des 30 % aux trois difficultés, et les cellules par pod entre 53
et 62 pour un seuil de 60.

> **Réserve.** Les 5/63 missions non nettoyées en 80 tours ne sont pas un défaut de dimensionnement :
> c'est le pilote automatique qui perd la dernière poche et tourne en rond. Un premier relevé à n=10
> laissait croire que « facile » était systématiquement la plus creuse (45 % de marche à vide) ; avec
> 21 tirages, cette valeur tombe à 26 % — les deux parties bloquées tiraient la moyenne. **Se méfier
> des moyennes sur cette mesure : sa distribution a une queue épaisse, la médiane est plus honnête.**

---

# Distorsion : une plage par difficulté

Remplace le décalage global `bonusDiff`, qu'on ne savait pas démêler du rang. Chaque difficulté porte
sa **plage**, et le rang situe la mission dedans :

```
distorsion = min[difficulté] + (max[difficulté] − min[difficulté]) × avancement
```

La difficulté choisit la bande, le rang la position dans la bande. Défauts :

| difficulté | min | max | avancement 0 % | 50 % | 100 % |
|---|---|---|---|---|---|
| facile | 0 | 15 | 0 | 8 | 15 |
| moyen | 15 | 40 | 15 | 28 | 40 |
| difficile | 40 | 70 | 40 | 55 | 70 |

Conséquence utile : un acte à **difficulté constante** garde une progression de distorsion (la plage
de sa difficulté), au lieu d'être figé. Un acte facile → difficile parcourt 0 → 70 %.

## L'échelle sature — à savoir avant de régler

Nombre moyen de voisins mesuré (un carré en a 4, un pentagone 5, un hexagone 6) :

| distorsion | 0 % | 4 % | 8 % | 16 % | 32 % | 55 % | 80 % |
|---|---|---|---|---|---|---|---|
| voisins | 3,70 | 4,44 | 4,72 | 5,15 | 5,16 | 5,28 | 5,34 |

**Tout se joue entre 0 et 16 %.** Au-delà, l'écart n'est plus perceptible : passer de 40 à 70 % ne
change presque rien à l'œil. Si tu veux que la déformation se *voie* le long de l'acte, resserre les
plages vers le bas (par exemple 0–4 / 4–9 / 9–16) plutôt que d'étaler jusqu'à 70.

Vérification : les six missions d'un acte facile → difficile donnent 3,40 · 3,51 · 5,01 · 5,23 ·
5,38 · 5,20 voisins, un seul secteur fortement connexe, aucun ennemi visible au tour 1, tous les
ennemis joignables.

## Réglage par mission

Le panneau de détail d'un nœud généré affichait encore le sélecteur de fichier de mission — un
contrôle **sans effet**, puisque `n.gen` a la priorité. Il propose désormais difficulté, forme,
objectif, avancement et graine, avec un aperçu du résultat (pods, taille de plateau, distorsion,
densité), un bouton **🎲 autre carte** (nouvelle graine, mêmes paramètres) et une bascule
**↩ fichier / 🎲 générer** dans les deux sens.

---

# Les étoiles comme échelle unique

Il y avait **deux systèmes de difficulté côte à côte**, dont un décoratif :

- `facile` / `moyen` / `difficile` pilotait vraiment la génération (poches, taille, effectifs) ;
- les **étoiles** du geoscape (0 à 5) ne faisaient que **teinter la case** et **payer la prime
  express** — aucun effet sur la carte (`index.html`, coloration, affichage, `PRIME_DIFF_MIN`).

La raison était structurelle : `geoLaunchMission()` chargeait un **fichier** de mission et ne passait
jamais par le générateur. Tout le dimensionnement mesuré ne s'appliquait donc qu'aux actes.

## Ce qui change

**L'étoile est la difficulté**, et elle commande le nombre de poches — donc le nombre
d'engagements, dont découle la taille du plateau :

```
★1 = 1 poche   …   ★5 = 5 poches
```

`facile` / `moyen` / `difficile` ne sont plus que des raccourcis d'éditeur vers **★2, ★3, ★4**
(réglables : `ETOILES_DIFF`). Les trois plages de distorsion restent les trois paliers nommés, et
les cinq étoiles s'y rangent : **★1-2 → facile, ★3 → moyen, ★4-5 → difficile**.

**Une région du geoscape peut porter une recette** au lieu d'un fichier (case *🎲 carte générée*,
avec forme et objectif au choix ou au hasard). Ses étoiles pilotent alors réellement la carte, et
l'éditeur affiche ce qu'elles produiront.

## Mesuré, 50 parties

| ★ | cellules | par pod | ennemis | tours (médiane) | marche à vide (méd.) | nettoyées |
|---|---|---|---|---|---|---|
| 1 | 62 | 62 | 4 | 12 | 13 % | 100 % |
| 2 | 112 | 56 | 4 | 12 | 25 % | 100 % |
| 3 | 173 | 58 | 6 | 19 | 26 % | 100 % |
| 4 | 235 | 59 | 8 | 31 | 37 % | 90 % |
| 5 | 302 | 60 | 10 | 27 | 28 % | 90 % |

Les cellules par pod tiennent entre 56 et 62 pour une cible de 60, et la durée d'une mission passe
de 12 à une trentaine de tours. Un secteur fortement connexe partout, aucun ennemi visible au tour 1,
tous les ennemis joignables.

> **Deux réserves.** ★1 et ★2 ont le même nombre d'ennemis (4) : le plancher `ENEMY_COUNT.facile`
> l'emporte sur `pods × 2`, si bien que ★1 est une seule grosse poche là où ★2 en fait deux petites.
> Baisser `ENEMY_COUNT.facile` à 2 si tu veux que ★1 soit vraiment léger.
> Et le plancher de largeur a dû descendre de 8 à 6 : à une seule poche la formule demande 5,5, et
> un plancher trop haut rendait **★1 plus creuse que ★2** (132 cellules par poche au lieu de 60).
