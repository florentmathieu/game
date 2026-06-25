# Rendre la progression motivante — tactique tour-par-tour & RPG

_Étude de design générale. Comment éviter le treadmill « amasser du stuff / passer des niveaux / aller à tel point de la carte pour de l'XP » et la linéarité, sans gonfler le monde. Panorama d'~25 jeux organisé en **menus d'options** par couche (macro / micro / tension)._

> **Version PDF soignée** : `ETUDE-PROGRESSION.pdf` (source `ETUDE-PROGRESSION.tex`).
>
> **Confiance.** La plupart des mécaniques sont confirmées par wikis/guides + connaissance établie. Les points **†** ont une **source de développeur** (post-mortem / GDC / interview). Les *Compromis*, *Principes* et *Anti-patterns* sont de l'**analyse de design**, pas des faits sourcés. Darkest Dungeon et XCOM n'y sont que **deux exemples parmi beaucoup**.

---

## 0. Diagnostic : pourquoi la boucle « XP/loot/voyage » lasse
Le treadmill empile *des nombres* (+1 stat, loot incrémental, ennemis qui montent avec toi). Trois défauts : (1) l'inflation verticale **dévalorise l'effort passé** (écueil n°1) ; (2) **pas de décision = pas d'intérêt** (on exécute, on ne décide pas) ; (3) **pas d'enjeu = pas d'attachement**.

> **Principe.** Trois moteurs, du plus fort au plus faible : **(1) enjeu/attrition** (on peut perdre) > **(2) décision** (chaque palier ferme des portes) > **(3) accumulation de stats** (support seulement).

---

## A. MACRO — structurer la campagne et le monde
_Non-linéarité par le **choix**, pas la **taille** ; anti-farm par la **pression**._

- **A1 · Horloge / menace montante.** XCOM 2 (Projet Avatar ; Élus + fatigue dans WOTC), Phoenix Point (Brume qui s'étend), Invisible Inc. (alarme montante† + 72 h), FTL (flotte qui poursuit), Battle Brothers (crises obligatoires). — *Compromis : trop = anxiété ; les experts apprennent à retarder l'horloge.*
- **A2 · Carte à nœuds (curation anti-dilution).** Slay the Spire, FTL (balises), Into the Breach (4 missions/7), Darkest Dungeon (hub↔expéditions), Banner Saga. Toute la non-linéarité, zéro trajet vide. — *Compromis : moins d'immersion « monde » ; dépendance RNG.*
- **A3 · Geoscape = coût d'opportunité.** XCOM (3–7 missions concurrentes), Phoenix Point (havres simultanés), JA2 (secteurs/mines). On ne peut pas tout faire.
- **A4 · Libération de territoire = colonne vertébrale.** JA2/3 (secteurs + milices qui auto-défendent), Bannerlord (fiefs ; composition > nombre). — *Compromis : fin « à plat » sans crise scénarisée.*
- **A5 · Régions cloisonnées à sens unique (anti-bloat).** DOS2 (5 actes irréversibles), Wasteland 2/3 (scope resserré). — *Compromis : contenu manquable → guides.*
- **A6 · Procédural borné + « golden path » fait-main.** XCOM, Darkest Dungeon, Into the Breach : variété **et** beats narratifs maîtrisés.
- **A7 · Scaling contre dilution.** Wartales (le **nombre** d'ennemis scale avec ton nombre → escouade lean), Bannerlord (aucun scaling, composition). — *À ne pas confondre avec le level-scaling généralisé (anti-pattern).*
- **A8 · Absence volontaire de pression.** Tactical Breach Wizards (pas de limite de tours, undo, pas de geoscape) : la tension est *opt-in*. Option assumée, à l'opposé du reste.

> **Anti-pattern — le monde ouvert gonflé.** Grande carte + `?` + listes + trajets longs = fatigue. *La taille n'est pas du contenu* ; c'est le monde **vide** qui lasse. Densité > échelle.

---

## B. MICRO — montée en puissance, builds, économie
_Remplacer « +1 stat » par des **décisions** et des **paliers** qui changent *comment* on joue._

- **B1 · Choix exclusifs verrouillés.** Slay the Spire (1 carte sur 3 ; le deck = le build), XCOM (capacité « A ou B » par grade), Wartales (paliers verrouillés), Banner Saga (promotions irréversibles), Fire Emblem (classes).
- **B2 · Pas d'XP du tout : puissance *structurelle*.** Into the Breach, FTL (scrap de la run), Slay the Spire. → **l'XP n'est qu'une option de montée parmi d'autres**, souvent la plus paresseuse.
- **B3 · Learn-by-doing vs niveaux discrets.** À l'usage : JA2, Bannerlord (immersif mais opaque, invite au grind). Discret : JA3, XCOM (lisible, plafonné, puissance via les choix de perks/équipement).
- **B4 · Potentiel fixé au recrutement.** Battle Brothers (talents aléatoires à l'embauche → plafond non-farmable ; l'équipement compte autant).
- **B5 · Build par composition d'équipe.** Wasteland 2/3 (7 Rangers spécialisés), DOS2 (classes = templates ; sorts par **combinaison** d'écoles). La profondeur est dans l'assemblage.
- **B6 · Multiclassage / archetypes / voies transformatives.** Pathfinder: WOTR (10 Mythic Paths ; Ange vs Filou « presque rien en commun » à l'acte 5). Builds transformatifs, pas « plus gros ».
- **B7 · Monnaie unique = dilemme permanent.** Banner Saga (Renown = niveau OU objets OU **nourrir la caravane**), Shadowrun Dragonfall (Karma = combat OU Étiquettes/contournements).
- **B8 · Loot rare, situationnel, à malus.** Battle Brothers (objets nommés rares/lointains), Darkest Dungeon (trinkets à bonus/**malus**), JA2/Wartales (éco tendue). Équiper = décider.
- **B9 · Customisation = progression d'identité.** XCOM† (surnoms/bios/apparence → l'unité jetable devient un personnage).

> **Anti-pattern — +1 stat linéaire + level-scaling.** Sans bifurcation ni nouveau « verbe », aucune identité ni décision ; et si tout monte avec toi, tu ne te sens jamais plus fort. Idem le **robinet à loot**.

> **Principe.** **Horizontal** (nouveaux outils/verbes) > **vertical** (nombres plus gros). « Monter » = se **spécialiser** (fermer des options) → identité + rejouabilité.

---

## C. TENSION / ENJEUX — ce qui donne *envie* de continuer
_Le moteur le plus puissant, et le plus négligé._

- **C1 · Mort permanente, en gradients.** Stricte (Fire Emblem classique, Battle Brothers, DD) ; downed-then-dead (JA3, Wartales = fuite de terreur) ; asymétrique (Bannerlord : troupes meurent, héros K.O.) ; optionnelle (FE3H → **dilue** l'attachement).
- **C2 · Blessures/séquelles permanentes.** Battle Brothers (œil perdu…), Wildermyth† (mutilations→transformations, vieillissement, mort de vieillesse). Les marques deviennent l'histoire du perso.
- **C3 · Attrition (psy / morale / financière).** **Psy :** Darkest Dungeon† — le Stress est conçu *explicitement* pour la tension (pas le min-maxing) ; deux faces (Affliction OU Vertu) ; récupération à **slots limités** → on **fait tourner le roster**. *(Un exemple fort, parmi d'autres.)* **Morale :** Wartales, Battle Brothers, Bannerlord (désertions). **Financière :** la **paie qui scale avec la taille** = frein anti-snowball quasi universel des jeux de mercenaires.
- **C4 · Échec qui fait avancer.** XCOM (rater fait monter l'Avatar mais la partie continue), Battle Brothers/DD (un wipe = revers, pas un load). L'échec produit du **contenu** au lieu d'un rechargement.
- **C5 · Choix irréversibles et exclusifs (la vraie non-linéarité).** DOS2 (Origins exclusifs ; un seul Divin), Pathfinder (voies mythiques ; fail states du royaume), Wasteland 2 (Highpool **vs** Ag Center détruit l'un), Wasteland 3 (factions exclusives), Shadowrun, Banner Saga. — *Compromis : beaucoup de contenu jamais vu ; risque d'« illusion de choix » si conséquences cosmétiques.*
- **C6 · Narration émergente.** Crusader Kings 2/3† (« des histoires sans intrigue ni script » ; traits d'agents autonomes → intrigues/trahisons), XCOM†/DD† (récit personnel), Battle Brothers, Wildermyth.
- **C7 · Tension sans RNG ni perte : information parfaite.** Into the Breach (attaques télégraphiées ; puzzle de protection en N tours). Tension max, zéro grind, zéro coup du sort.

> **Anti-pattern — tout réversible.** Save-scum, respec gratuite illimitée, undo : tension et poids des choix s'effondrent. La réversibilité est une *option de confort* (cf. C1 optionnelle, A8) à doser.

---

## D. Synthèse — principes transférables
1. **Pousser vers l'avant (une horloge) > laisser farmer.**
2. **Le choix avant l'accumulation** (bifurcations, exclusivité, irréversibilité).
3. **La rareté crée la décision** (récupération limitée, éco tendue, paie qui scale).
4. **L'enjeu crée le sens** (perte/séquelles, attrition, échec qui fait avancer).
5. **L'identité avant les stats** (persos nommés/customisés, historique émergent).
6. **Curer, ne pas agrandir** (nœuds, régions denses, golden path).
7. **La puissance = de nouveaux verbes, pas de plus gros nombres.**
8. **Les couches se renforcent** : la même ressource sert l'enjeu *et* la décision (paie, Renown, Karma, slots de repos).

> **En une phrase.** La progression devient motivante quand **monter, c'est décider** ; **continuer, c'est risquer** ; **explorer, c'est arbitrer** — les stats n'étant que le décor.

### Aiguillage : quel mécanisme pour quel objectif
| Si tu veux… | Options |
|---|---|
| Tuer le grind d'XP | A1 (horloge), B2 (pas d'XP), C3 (rareté/paie) |
| Tuer la linéarité | A2/A3 (nœuds/geoscape), C5 (choix exclusifs), B1/B6 (builds divergents) |
| Éviter le monde trop grand | A2 (nœuds), A5 (régions cloisonnées), A7 (scaling) ; densité > taille |
| Donner du poids émotionnel | C1/C2 (perte/séquelles), C6 (récit émergent), B9 (identité) |
| Garder la boucle micro vivante | B1 (exclusivité), B7 (monnaie-dilemme), B8 (loot à malus) |
| Accessibilité / public large | A8 (pas de pression), C1 optionnelle, C7 (information parfaite) |

---

### Annexe — sources & fiabilité
**Sources dev (†)** : Darkest Dungeon (Affliction Deep Dive, Game Developer) ; XCOM (Game Developer + interview producteur) ; Crusader Kings II (GDC Vault, Fåhraeus) ; Invisible Inc. (Alarm Deep Dive) ; Wildermyth (presse design). **Mécaniques (wikis/guides)** : tous les autres titres. **Analyse de design (non sourcée)** : Compromis, Principes, Anti-patterns, synthèse. _Limite : certaines pages bloquées par le proxy (lecture sur extraits) ; les faits structurels sont robustes, les chiffres exacts varient selon patch/difficulté._
