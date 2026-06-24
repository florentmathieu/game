# Revue de retape — Cœur maillage (hex → maillage)

_Revue demandée le 2026-06-24 (nuit). Objectif : retrouver l'état du jeu **juste avant** le passage au plateau Voronoï (carrés/pentagones), inventorier ce qu'il savait faire, comparer à l'état actuel, et lister les **chantiers de retape** pour revenir au niveau de qualité d'avant._

## Méthodologie

- **OLD** (étalon de qualité) = `index.html` au commit **`9c13570`** _« Persistance de campagne… »_ — c'est le **parent direct** de `c20edab` _« POC : terrain mixte hexagones/carrés/pentagones »_ (le premier commit du maillage, ~17 h 20 en heure locale). C'est la version **hexagonale** mûre (4128 lignes).
- **NEW** = `index.html` actuel (maillage Voronoï, 893 lignes).
- 8 revues croisées par sous-système + **vérifications ciblées par `grep` sur les deux fichiers** pour écarter les faux positifs. Les comptes `OLD=n / NEW=m` ci-dessous sont ces vérifications.

> ⚠️ Le maillage est volontairement plus compact. La **boucle de jeu de base est bien là** et fonctionne (déplacement PA/Dijkstra, combat à parité — chance/couvert/hauteur/flanc/bouclier/parade, brouillard, pods & sommeil, campagne à nœuds, éditeur de mission + campagne, triggers/dialogues). Ce document liste ce qui a été **perdu ou affaibli**.

---

## Résumé exécutif — les 5 grands manques

Par ordre d'impact ressenti :

1. **Le « jus » du combat a totalement disparu** (`pushDmg/drawFx/pushBlast/pushAlert/shake` : OLD=21, NEW=0). Aucun nombre de dégâts flottant, aucune trajectoire de projectile, aucune explosion, aucun « ! » d'alerte, aucun tremblement d'écran. Les coups n'ont plus de retour visuel.
2. **L'IA ennemie est devenue « bête »** : plus de **mémoire/poursuite** (`lastSeen` OLD=9/NEW=0), plus de **recherche** du joueur perdu de vue (`searchAct/predictedGoal` OLD=4/NEW=0), plus de **coordination** entre ennemis (`clump/spread` OLD=4/NEW=0), plus d'usage de **grenade** par l'IA (`bestGrenade` OLD=2/NEW=0), plus de **rechargement** ni de **garde** opportunistes.
3. **La profondeur stealth a été perdue** : la classe **assassin furtif** (visible seulement de face) et les **cônes de vision / ombres** ont disparu (`stealth` OLD=14/NEW=0 ; `frontal/fieldOfView/inShadow` OLD=9/NEW=0). _(Note : on vient de rajouter l'angle mort arrière au réveil — c'est un début, mais ça ne couvre pas la furtivité de classe ni les cônes.)_
4. **La scénarisation par triggers est bridée** : plus de **dépendances** (`requires/forbids` OLD=7/NEW=0) ni d'**actions-monde** (réveiller un pod, faire apparaître/ouvrir/fermer — `.wake/.spawn/.open/.close` OLD=14/NEW≈0). Les triggers ne savent plus que **parler**.
5. **Design de mission & progression de campagne amincis** : plus de seuil de **protection N/M** ni de distinction civils/otages dans la victoire (`protect/missionProtect` OLD=12/NEW=0), plus de **fullHeal** (OLD=11/NEW=0), plus de **butin** (potions gagnées entre missions — `addItem/loot` OLD=7/NEW=0), plus de **saut des textes déjà vus** au réessai (`seenText` OLD=7/NEW≈0).

---

## Chantiers de retape (priorisés)

### P0 — fort impact, à faire en premier

| # | Chantier | Ce que faisait OLD | État NEW | Effort |
|---|----------|--------------------|----------|--------|
| 1 | **Jus de combat / FX** | nombres de dégâts flottants, trait de projectile attaquant→cible, arc de mêlée, explosion de cracker, onde de bruit, « ! » au repérage, léger tremblement d'écran (`pushDmg/drawFx/pushBlast/pushAlert/pushNoise/shake`) | **absent** | Moyen |
| 2 | **IA — mémoire & poursuite** | `lastSeen` (dernière position connue) + `searchAct`/`predictedGoal` : l'ennemi qui perd le joueur de vue **va le chercher** au lieu de se figer | **absent** (l'ennemi se fige si pas de cible visible) | Moyen-élevé |
| 3 | **IA — coordination** | malus d'agglutinement + bonus d'écartement angulaire → **encerclement** ; les ennemis ne s'empilent pas | **absent** | Moyen |
| 4 | **IA — grenade / rechargement / garde** | `bestGrenade` (lance si touche assez d'ennemis), recharge si une cible serait à portée, lève le bouclier/garde si exposé, **fait toujours face à la menace** (anti-dos) en tenant position | **absent** | Moyen |
| 5 | **Stealth de classe + cônes de vision** | assassin `stealth:true` **vu seulement de face** ; dormeurs/éveillés ont un **cône** de détection (~120°) ; **ombres** projetées par les rochers ; pion furtif **estompé** tant que non repéré | **absent** (assassin = unité normale ; détection = distance+LdV+angle mort arrière seulement) | Élevé |

### P1 — systèmes importants

| # | Chantier | Ce que faisait OLD | État NEW | Effort |
|---|----------|--------------------|----------|--------|
| 6 | **Rechargement (action)** | bouton/▶ « recharger » quand l'arc/arbalète est vide (`doReload`, `reload` OLD=24/NEW=1) | munitions suivies mais **aucune action pour recharger** → unité distance « bloquée » une fois à sec | Faible |
| 7 | **Garde / posture défensive** | action `doBrace` (+`DEF_BRACE` de défense, terme `-def` dans le calcul de touche) ; l'IA l'utilise (`brace/defenseOf` OLD=31/NEW=0) | **absent** (le terme `def` n'existe plus dans `chance()`) | Faible-moyen |
| 8 | **Triggers — dépendances** | `t.requires` / `t.forbids` (chaîner/bloquer des évènements) | **absent** | Faible-moyen |
| 9 | **Triggers — actions-monde** | un trigger peut **réveiller un pod**, **faire apparaître** des unités, **ouvrir/fermer** un passage (`.wake/.spawn/.open/.close`) | **absent** (les triggers ne font que parler) | Moyen |
| 10 | **Triggers — filtres riches** | bornes `{min,max}` sur `hpPct`, `turn`, `enemiesHit` ; match sur `weapon`, `actorTeam`, `reaction` | match par **égalité simple** seulement | Faible |
| 11 | **Victoire/défaite fines** | seuil de protection **N sur M** PNJ, distinction **civils vs otages**, indulgence paramétrable | **toute** mort de PNJ/otage = défaite immédiate (`checkEnd`) | Faible-moyen |
| 12 | **Progression de campagne** | **butin** (potions/objets gagnés en fin de mission, `addItem`), report plus complet, **saut des textes déjà vus** au réessai (`seenText`) | report PV + crackers + potions portées, mais **aucun gain** de potion et les textes se rejouent | Moyen |

### P2 — finitions / confort

| # | Chantier | Ce que faisait OLD | État NEW | Effort |
|---|----------|--------------------|----------|--------|
| 13 | **Éditeur — relief auto** | `generateElevation` (collines gaussiennes) + `generate()` incrémental (relief+rochers+murets, **sans tout effacer**) | `autoTerrain` ne pose **que** terrain/couvert/murets ; **pas de relief auto** ; « regen » **efface tout** | Faible-moyen |
| 14 | **Éditeur — outils dédiés** | outils nommés « orienter », « renommer » ; suppression de mission du dépôt ; rangée de boutons d'équipe | rotation/rename existent mais **moins découvrables** ; **pas de suppression** de mission ; équipe en menu déroulant | Faible |
| 15 | **Rendu — relief lisible** | couleur de cellule **graduée par altitude** (lecture d'un coup d'œil) | teinte par **type** de terrain + léger sur-voile d'altitude (moins lisible) | Faible |
| 16 | **Rendu — confort** | fiche d'unité **ancrée** (stable) ; messages d'erreur **éphémères** (auto-effacés) ; **vitesse d'anim par camp** (ennemi plus lent, plus lisible) | fiche **suit le curseur** ; message persistant ; vitesse unique | Faible |
| 17 | **Déplacement & brouillard** | le joueur **ne peut pas** planifier un trajet dans le brouillard (`reach` filtre `visible`) | `reach()` **ignore** le brouillard → on planifie dans l'inconnu | Faible |

---

## Détail vérifié par sous-système

### Déplacement & pathfinding
Cœur identique (Dijkstra `reach`, `pathTo`, `hops`, modèle PA `FREE_MP=2/AP_MAX=2/MOB`, falaises ≥2 infranchissables, `apForMove`). **Améliorations NEW** : terrain accidenté (coût +1), animation de glissement.
- ❌ `reach()` n'exclut plus les cases non vues (OLD le faisait) → planification dans le brouillard. _(P2-17)_
- ⚠️ Vitesse d'animation unique (OLD : ennemi plus lent). _(P2-16)_
- ⚠️ Révélation des paliers de portée moins progressive qu'avant (cosmétique).

### Combat
Très bonne parité de règles : `chance` (visée−couvert+hauteur−bout-portant), `flankOf` (face/flanc/dos), `muretCover` (couvert directionnel de muret), bouclier, **parade**, bonus de flanc, malus de réaction −15, −1 dégât ennemi, crackers. Classes/armes **identiques** (sergent/sapeur/assassin/garde/archer/brute + civils).
- ❌ **Garde/posture (`doBrace`)** et le terme de défense dans `chance()` : supprimés. _(P1-7)_
- ❌ **Rechargement** : munitions suivies mais pas d'action. _(P1-6)_
- ❌ Pas de **détail de la touche** affiché au joueur (OLD : `hitBreakdown` montrait visée/couvert/hauteur/def/bout-portant).
- ✅ **Correction au pré-rapport** : la **parade fonctionne** dans NEW (`doAttack` la teste, ligne ~318). Ce n'est PAS du code mort.

### Stealth & détection
Conservé : pods (`podAlerted`, `wakePod`, le pod se tourne vers le découvreur), sommeil (`_asleep0`), portées `ENEMY_VIS=7/SLEEP_VIS=4`, `enemyActive`, découverte des PNJ, évènements spotted/discovered, **angle mort arrière au réveil** (ajouté récemment).
- ❌ **Classe furtive** assassin (vu de face uniquement) : disparue. _(P0-5)_
- ❌ **Cônes de vision** dormeur/éveillé + **ombres** des rochers : disparus (NEW = distance + LdV simple + angle mort arrière). _(P0-5)_
- ❌ Pion furtif **estompé** tant que non repéré : disparu.
- ℹ️ `SLEEP_VIS` est passé de 6 à 4 (réglage à revoir avec les cônes).

### IA ennemie
Conservé : score de case `offense − 0.7·menace − 1.4·proximité + 0.5·relief`, choix de cible `chance·1000 − pv`, bouger-puis-attaquer, réactions d'overwatch, gating par `enemyActive`.
- ❌ **Mémoire `lastSeen` + recherche/poursuite** (`searchAct`/`predictedGoal`). _(P0-2)_
- ❌ **Coordination** (agglutinement/écartement → encerclement). _(P0-3)_
- ❌ **Grenade IA** (`bestGrenade`), **rechargement** conditionnel, **garde** si exposé, **face à la menace** en tenant position. _(P0-4)_
- ⚠️ Formule de score simplifiée (perte des termes de coordination).

### Rendu, HUD & UX
Conservé (large parité) : pions + flèche d'orientation + couleurs d'équipe + anneau de sélection, croix de mort, « z » sommeil, anneau d'overwatch (+ « 👁🏹 » ajouté), barres de PV, **brouillard réel**, rochers, contours de portée 3 paliers, aperçu de chemin mauve, bannières de tour, fiche au survol, journal repliable, bulle de dialogue, barre d'actions (icône+numéro+libellé au survol), roster, zoom molette, écran de fin, **écran-titre** (réduit à « New game »).
- ❌ **Tous les FX de combat** (dégâts flottants, projectile, explosion, arc de mêlée, onde de bruit, « ! » d'alerte, tremblement). _(P0-1)_
- ❌ Anneau bleu de **garde** sur le pion (lié à P1-7).
- ⚠️ Couleur de relief moins lisible ; fiche qui suit le curseur ; messages non éphémères. _(P2-15/16)_

### Éditeur de mission
Conservé (et parfois **mieux**) : peinture terrain (sol/accidenté/rocher/muret), relief +/−, pose d'unités (équipe/classe/**nom**), **gomme murets+rochers**, **clic-droit = suppression**, **pods/sommeil au clic**, **zones de déclenchement nommées**, **rotation au clic** (tous outils), taille de plateau, **zones auto**, sauvegarde/chargement dépôt + brouillon localStorage + **nom de mission mémorisé**, **sections repliables**.
- ✅ **Correction au pré-rapport** : les **sections repliables existent** dans NEW (`makeCollapsible`, 4 appels).
- ❌ **Relief auto** (`generateElevation`) absent ; « regen » destructif. _(P2-13)_
- ❌ Suppression d'une mission du dépôt ; outils dédiés orienter/renommer ; métadonnées de mission (fullHeal, seuil protection). _(P1-11, P2-14)_

### Campagne & triggers/dialogues
Conservé : graphe de nœuds (texte/mission/choix), branches victoire/défaite, intro/outro (+ fichiers), interlude plein écran, **report PV/crackers/potions**, menu de choix, « tester d'ici », éditeur visuel (graphe + détail), lecteur de texte paginé (`_`, noms gras+doré, machine à écrire, bouton « … »), `once`/`priority`/`firstAction`, **répliques multiples** (ajouté), évènement **« entrée en zone »** (ajouté).
- ❌ **`requires`/`forbids`** (dépendances entre triggers). _(P1-8)_
- ❌ **Actions-monde** `.wake/.spawn/.open/.close`. _(P1-9)_
- ❌ Filtres riches (bornes min/max, `weapon`, `actorTeam`, `reaction`). _(P1-10)_
- ❌ **Saut des textes déjà vus** au réessai (`seenText`) ; **butin** (gain de potions/objets). _(P1-12)_

### Objets, tour & entrées
Conservé : crackers (aire/dispersion/tir ami + **aperçu animé** ajouté), potions (soi/adjacent, −1 PA, +6 PV), overwatch tir/mêlée, barre d'actions adaptative, fin de tour (touche 0), auto-passage à l'unité suivante, `checkEnd`, raccourcis (Tab cible/unité, 1-9 actions, Échap, Entrée, Espace).
- ❌ **Rechargement** (P1-6), **garde** (P1-7), **butin de potions** (P1-12).
- ❌ **Victoire/défaite fines** : toute mort de PNJ = défaite (pas de seuil N/M, pas de civils tolérés). _(P1-11)_
- ✅ **Correction au pré-rapport** : le **drapeau otage existe** dans NEW (`hostile()` le respecte : les otages ne sont pas ciblés). Ce qui manque, c'est la **granularité** de la condition de défaite, pas le drapeau.

---

## Ce que NEW fait MIEUX que OLD (à conserver tel quel)

- Terrain **accidenté** (coût de déplacement) ; **gomme** murets+rochers ; **clic-droit** = suppression d'unité.
- **Zones de déclenchement nommées** peintes à la souris ; **rotation au clic** quel que soit l'outil ; **pods/sommeil au clic**.
- **Nom de mission** + **orientations** mémorisés et rechargés ; **aperçu animé du cracker** ; **angle mort arrière** au réveil ; **Échap** désactive l'outil ; **rochers en lisière** de vision ; zoom molette.

## Faux positifs des pré-rapports (déjà vérifiés, **ne pas** traiter)

1. ~~Parade inutilisée dans NEW~~ → **elle fonctionne** (`doAttack`).
2. ~~Distinction otage supprimée~~ → **le drapeau existe** ; seule la granularité victoire/défaite manque.
3. ~~Sections repliables supprimées~~ → **présentes** (`makeCollapsible`).

---

## Ordre de bataille suggéré

1. **P0-1 (FX de combat)** — gain de « feel » immédiat, indépendant du reste.
2. **P0-5 (stealth de classe + cônes)** — c'est le cœur identitaire du jeu (assassin, infiltration) et tu travailles justement le stealth en ce moment.
3. **P0-2/3/4 (IA)** — re-porter le moteur de décision de la version hex (mémoire, recherche, coordination, grenade, garde) ; gros gain de difficulté/crédibilité.
4. **P1-6/7 (recharge, garde)** — petites actions, profondeur tactique restaurée.
5. **P1-8/9/10 (triggers)** — pendant que la scénarisation est fraîche : dépendances + actions-monde.
6. **P1-11/12 (victoire fine + butin/skip textes)** — variété de missions et progression de campagne.
7. **P2** — finitions éditeur/rendu/brouillard au fil de l'eau.
