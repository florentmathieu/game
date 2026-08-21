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
