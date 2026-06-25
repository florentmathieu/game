# Étude — Rendre la progression long-terme motivante (tactique TB & RPG)

_Étude de design générale (non liée à un jeu précis), demandée pour comprendre comment éviter le treadmill « amasser du stuff / passer des niveaux / aller à tel point de la carte faire une mission pour de l'XP » et la linéarité, sans tomber dans le piège des mondes trop grands._

> **Méthode & honnêteté des sources.** Une recherche web multi-sources avec vérification adversariale a été lancée. Son fact-checker, calibré pour des affirmations « falsifiables avec citation », n'a confirmé qu'un noyau étroit (surtout **Darkest Dungeon** et **XCOM**) — il est mal adapté à de l'analyse de design, qui repose sur des observations interprétatives plutôt que des faits citables. Les points **【vérifié】** ci-dessous sont sourcés (Game Developer / déclarations dev). **Tout le reste est une synthèse de design** appuyée sur la connaissance établie de ces jeux — solide, mais non re-citée ligne à ligne.

---

## 0. Diagnostic : pourquoi la boucle « XP/loot/voyage » lasse

Le treadmill classique empile **des nombres** : +1 stat par niveau, du loot incrémental, des ennemis qui montent en même temps que toi. Problème de fond :

- **L'inflation verticale dévalorise le passé.** 【vérifié, medium】 Multiplier les récompenses d'XP par 100 réduit 1000 h d'effort à l'équivalent de 10 h — exactement une hyperinflation monétaire. Quand la puissance n'est qu'un nombre qui gonfle, le progrès passé perd sa valeur et la sensation devient creuse. _(Clockwork Labs, analyse MMO.)_
- **Pas de décision = pas d'intérêt.** Si « monter » se résume à répéter une boucle pour franchir un seuil de stats, il n'y a aucun arbitrage : on exécute, on n'décide pas.
- **Pas d'enjeu = pas d'attachement.** Si rien ne peut être perdu, la progression n'a pas de poids émotionnel.

**Les trois vrais moteurs de motivation long-terme** (par ordre de puissance, du plus fort au plus faible) :
1. **L'enjeu / l'attrition** — on peut perdre quelque chose d'irremplaçable.
2. **La décision** — chaque palier ferme des portes (build, route, ressource).
3. **L'accumulation de stats** — le plus faible ; à n'utiliser que comme support des deux autres.

Le reste de l'étude décline ces moteurs sur les trois couches **(A) Macro**, **(B) Micro**, **(C) Tension**, puis liste les **anti-patterns** et les **principes transférables**.

---

## A. MACRO — structure de campagne & monde

**Objectif : créer de la non-linéarité par le CHOIX, pas par la TAILLE ; et empêcher le farm par la PRESSION.**

### A1. L'horloge montante (anti-grind par construction)
Une menace qui s'aggrave avec le temps rend le farm impossible : tu ne peux pas « tourner en rond pour de l'XP », car attendre te coûte.
- **XCOM 2 — Projet Avatar** : une jauge mondiale qui, pleine, fait perdre la partie. Tu dois agir, choisir tes fronts, accepter de laisser des opportunités filer. C'est l'inverse du grind : le temps est l'ennemi.
- **XCOM 2 : WOTC — les Élus / Dark Events** : une menace qui apprend et revient, et des événements négatifs qu'on ne peut pas tous contrer → coût d'opportunité permanent.
- **Darkest Dungeon** : l'horloge est interne (le stress, l'argent, l'usure du roster) plutôt qu'un compte à rebours, mais l'effet est le même — repartir « pour farmer » use tes héros.
- **FTL** : la flotte rebelle te poursuit sur la carte ; t'attarder pour fouiller un secteur, c'est se faire rattraper. Chaque détour est un pari risque/récompense.
- **Battle Brothers** : des « crises » montantes (guerres, invasions) qui transforment le monde — l'attente n'est pas neutre.

> **Principe.** Une pression temporelle (explicite ou systémique) convertit « je farme jusqu'à être prêt » en « je décide quoi sacrifier ». Le compromis : trop de pression = stress/anxiété ; il faut doser et laisser des respirations.

### A2. Carte à nœuds > monde ouvert (curation contre dilution)
La non-linéarité ne demande pas un grand monde : une **carte à nœuds** offre des choix de route à chaque étape, sans traversée vide.
- **Slay the Spire, FTL, Darkest Dungeon, The Banner Saga, Hand of Fate** : tu choisis ton chemin parmi des nœuds (combat / événement / repos / boutique / élite). 100 % de la non-linéarité, 0 % de remplissage. La tension vient du **choix de route** (prendre le nœud « élite » risqué pour une meilleure récompense ?).
- Avantage : densité maximale, zéro temps de trajet mort, rejouabilité (le graphe change).
- Compromis : moins d'immersion « monde » et d'exploration libre que DOS2 ou Pathfinder.

### A3. La couche stratégique comme espace de décision
Le « monde » peut être une **carte de décisions** plutôt qu'un terrain à parcourir.
- **XCOM — geoscape** : à tout instant, plusieurs missions/projets simultanés (de l'ordre de 3 à 7) dont tu ne peux pas tout faire → **coût d'opportunité** constant. La non-linéarité = choisir *quoi* et *où*, pas la taille de la map.
- **Jagged Alliance 2** : contrôle de secteurs, milices, économie de mines qui finance la guerre → la carte est un système, pas un couloir.
- **Battle Brothers / Wartales / Mount & Blade** : contrats, réputation, économie de la compagnie → tu te fixes tes propres objectifs (sandbox dirigé).

> **Principe.** Rends la carte décisionnelle (arbitrages, coûts d'opportunité) plutôt que spatiale (distances à parcourir). La « liberté » utile, c'est de **choisir parmi des options exclusives**, pas de marcher loin.

### A4. Procédural borné + « golden path » fait-main
- **XCOM** : cartes tactiques procédurales (variété/rejouabilité) **+** missions d'histoire scénarisées obligatoires (le « golden path ») au milieu de missions optionnelles. On combine variété infinie et beats narratifs maîtrisés.
- **Darkest Dungeon** : donjons procéduraux, mais bosses et région finale fait-main.
- **DOS2 / Pathfinder : WOTR / Shadowrun** : à l'opposé, tout fait-main, mais **densément réactif** (cf. A5) — la non-linéarité vient des solutions multiples et des conséquences, pas de la taille.

### A5. Densité > taille (anti-bloat)
L'écueil du monde ouvert : grande carte, points d'interrogation, listes de tâches, fatigue de trajet. La parade : **petit, dense, réactif**.
- DOS2 : des zones relativement compactes mais où *presque tout* réagit (dialogues, environnement, ordre des quêtes libre).
- Into the Breach : une « carte » minuscule (grille 8×8), profondeur maximale.

> **Principe macro global.** Curer plutôt qu'agrandir. La sensation de monde vient de la **réactivité et de la densité de choix**, pas des kilomètres carrés.

---

## B. MICRO — montée en puissance, builds, loot, économie

**Objectif : remplacer « +1 stat » par des DÉCISIONS et des PALIERS qui changent *comment* on joue.**

### B1. Choix exclusifs > croissance linéaire
Chaque palier doit être une **bifurcation**, pas un incrément.
- **Slay the Spire** : à chaque combat, choisir 1 carte sur 3 (ou aucune). Ton deck **est** ton build ; il se construit par une suite d'engagements irréversibles → identité + rejouabilité énorme.
- **XCOM** : à chaque grade, choix « A ou B » de capacité (jamais les deux) → deux snipers du même grade jouent différemment.
- **Fire Emblem** : promotions/classes, choix de compétences ; **Three Houses** : choix de maison + de cours qui orientent durablement.
- **Into the Breach** : **zéro XP**. La puissance vient des mechs/armes qu'on **choisit** de débloquer et d'équiper → 100 % décision, 0 % grind.

> **Principe.** « Monter » = **se spécialiser** (fermer des options) plutôt qu'« avoir plus ». La spécialisation crée de l'identité et donne envie de rejouer pour explorer une autre branche.

### B2. Paliers (power spikes) > montée plate
Les meilleurs sauts de puissance changent **les verbes** disponibles, pas seulement les nombres.
- XCOM : un nouveau palier d'armure n'ajoute pas que des PV — il ajoute une **utilité** (grappin, saut, slot d'objet) qui ouvre de nouvelles tactiques.
- DOS2 : débloquer une nouvelle école de magie = de nouvelles **interactions** (élémentaires, surfaces), pas +X dégâts.

> **Principe.** Privilégier l'**horizontal** (nouveaux outils/verbes) au **vertical** (nombres plus gros). Un nouveau pouvoir qui change une situation > un +10 % de dégâts.

### B3. Rareté & coût d'opportunité dans le loot/l'éco
- **Jagged Alliance 2 / Battle Brothers** : l'argent est rare ; chaque achat (soin, recrue, équipement) est un arbitrage. Le loot compte parce qu'il est *cher* et *situationnel*.
- **Darkest Dungeon — trinkets** : objets puissants **avec un défaut** (bonus/malus) → équiper, c'est décider, pas empiler.
- Anti-pattern inverse : le robinet à loot (slot-machine) où tout afflue → plus aucune décision.

### B4. Leçon cross-genre : la puissance peut ne PAS venir de l'XP
- **Into the Breach** (pas d'XP), **FTL** (puissance = décisions sur le scrap de *cette* partie), **Slay the Spire** (le deck) : la progression peut être **structurelle** (débloquer/choisir) plutôt qu'expérientielle (farmer un compteur). À méditer : l'XP n'est qu'**une** façon de faire monter, souvent la plus paresseuse.

### B5. Customisation signifiante = progression d'identité
- **XCOM** 【vérifié】 : surnoms adaptés à la classe, petites bios, personnalisation poussée → l'esprit du joueur « comble le récit », l'unité devient un personnage. La customisation **est** une forme de progression (attachement), distincte du stat-bloat. _(Game Developer ; producteur XCOM 2 : « You've got to create your own stories. »)_

---

## C. TENSION / ENJEUX — ce qui donne *envie* de continuer

**C'est le moteur le plus puissant, et le plus négligé. Verdict de la recherche : la motivation long-terme tient moins à l'accumulation qu'à la PRESSION ÉMOTIONNELLE et l'ATTRITION.** 【vérifié】

### C1. Mort permanente + investissement = attachement
- **XCOM** 【vérifié】 : permadeath + customisation transforme des unités jetables en personnages auxquels on tient. La menace de les perdre force à **apprendre leurs capacités et à les développer** comme un bon manager → la guerre devient personnelle, et chaque perte raconte quelque chose. _(Game Developer.)_
- Se généralise (synthèse) à **Fire Emblem (mode classique)**, **Battle Brothers**, **The Banner Saga**, **Darkest Dungeon**, **Wildermyth** : des persos nommés, qu'on a façonnés, qui peuvent mourir pour de bon.

> **Principe.** La perte irréversible est *le* générateur de sens. Sans risque de perte, la progression n'a pas de poids.

### C2. Attrition psychologique / usure (l'anti-treadmill structurel)
- **Darkest Dungeon — Stress** 【vérifié, primaire】 : conçu **explicitement** pour modéliser la réponse humaine au stress, avec l'intention délibérée de **retirer l'agency** au joueur quand un héros craque. Objectif = **tension émotionnelle**, pas min-maxing. _(« We wanted to capture the human response to stress. Any person can break under pressure. »)_
- Le stress est une **ressource persistante** : à 100, jet d'Affliction → condition handicapante (Selfish, Paranoid…) — mais parfois une **Vertu** (Stalwart, Courageous…). Mécanique **à deux faces** (effondrement vs résilience héroïque), pas une jauge purement punitive (~75 % affliction / 25 % vertu). 【vérifié】
- L'attrition se gère à la **couche stratégique** via des activités de ville **en nombre limité** (boire, prier, méditer, jouer), avec préférences par héros et **slots rares** → impossible de « farmer la récupération ». On est **forcé de faire tourner le roster** (3+ équipes pour ~28 héros). 【vérifié】 → la ressource qu'on gère, ce sont les **gens**, pas l'or.
- L'**historique d'affliction** par héros tend à se répéter → chaque membre développe une **personnalité comportementale** émergente. 【vérifié】

> **Principe.** Faire des personnages une **ressource périssable et limitée en récupération** crée des arbitrages humains (qui envoyer ? qui ménager ?) et empêche le farm infini.

### C3. Choix irréversibles & conséquences (la vraie non-linéarité)
- **DOS2 / Shadowrun / Pathfinder : WOTR (mythic paths)** : des choix qui **ferment des portes** (PNJ tués, factions perdues, routes mutuellement exclusives) → rejouabilité et poids.
- **The Banner Saga** : décisions de caravane (qui nourrir, qui sacrifier) aux conséquences durables et souvent amères.
- **Crusader Kings** : la non-linéarité **émerge** des systèmes (héritage, relations, trahisons) — personne n'a scénarisé ton histoire, mais elle est inoubliable.

> **Principe.** « Non-linéaire » ≠ « grand ». C'est **des choix qui comptent et qu'on ne peut pas annuler**.

### C4. Échec signifiant (« failing forward »)
- **XCOM** : rater une mission ne renvoie pas à un load — ça fait avancer l'Avatar, tu perds du terrain mais la partie continue, transformée.
- **Darkest Dungeon / Battle Brothers** : un wipe est un revers de campagne (héros morts, à reconstruire), pas un écran de chargement.

> **Principe.** Quand l'échec produit du **contenu et de l'histoire** (au lieu d'un rechargement), la tension devient jouable au lieu d'être contournée par le save-scum.

### C5. Narration émergente
- 【vérifié pour XCOM & DD】, se généralise à Battle Brothers, Wildermyth (récit génératif), CK : des **systèmes qui fabriquent des histoires** que le joueur raconte. C'est ce qui donne envie de relancer « encore une campagne ».

---

## D. ANTI-PATTERNS explicites (à éviter)

1. **Treadmill d'inflation** 【vérifié】 : des nombres toujours plus gros qui dévalorisent l'effort passé. La sensation de progrès est une illusion court-terme.
2. **Level-scaling des ennemis** : si tout monte avec toi, tu ne te sens **jamais** plus fort → le progrès s'annule (Oblivion en est le cas d'école).
3. **La boucle « va à tel point de la map pour une mission qui donne de l'XP »** sans horloge, sans enjeu, sans choix : pur remplissage.
4. **Le monde ouvert gonflé** : grande carte + cases à cocher + trajets longs → fatigue d'exploration. La taille n'est pas du contenu.
5. **Tout réversible** : si on peut tout annuler (save-scum, respec gratuite illimitée), la tension et le poids des choix s'effondrent.
6. **Puissance purement additive (+1 stat)** : sans bifurcation ni nouveau verbe, aucune identité ni décision.
7. **Récupération/grind illimités** : sans rareté, plus aucun arbitrage — on optimise au lieu de décider.

---

## E. Principes transférables (la synthèse)

1. **Pousser vers l'avant (une horloge) > laisser farmer.** Une pression temporelle/systémique tue le grind à la source.
2. **Le choix avant l'accumulation.** Bifurcations, exclusivité, irréversibilité : chaque palier ferme des portes.
3. **La rareté crée la décision.** Récupération limitée, économie tendue, coûts d'opportunité.
4. **L'enjeu crée le sens.** Perte permanente, attrition, échec qui fait avancer.
5. **L'identité avant les stats.** Personnages nommés/customisés, historique émergent : on s'attache à des gens, pas à des chiffres.
6. **Curer, ne pas agrandir.** Cartes à nœuds, densité, golden path fait-main au milieu d'optionnel.
7. **La puissance = de nouveaux verbes, pas de plus gros nombres.** Horizontal > vertical ; et l'XP n'est qu'une option parmi d'autres pour faire monter.

> **En une phrase.** La progression devient motivante quand **monter, c'est décider** (choix exclusifs), **continuer, c'est risquer** (attrition/perte), et **explorer, c'est arbitrer** (carte décisionnelle curée) — l'accumulation de stats n'étant que le décor de ces trois moteurs.

---

### Annexe — couverture & limites de la recherche web
- **Confirmé par sources (3-0 sauf mention)** : Darkest Dungeon — intention de design du stress, mécanique stress/affliction à deux faces, gestion en ville à slots limités, historique d'affliction émergent _(Game Developer, deep dive développeur)_ ; XCOM — permadeath + customisation = attachement & récit émergent _(Game Developer ; PC Gamer / producteur)_. **Anti-pattern d'inflation d'XP** (2-1, qualité blog, calcul auto-évident) _(Clockwork Labs)_.
- **Non re-vérifié par citation** (mais design établi) : tout le reste — couche macro (Avatar/Élus, geoscape, cartes à nœuds, JA2/Battle Brothers), couche micro (Slay the Spire, Into the Breach, FE, loot/éco), et les autres titres. À considérer comme **synthèse de design experte**, pas comme faits sourcés.
