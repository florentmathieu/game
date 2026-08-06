# Direction de design — synthèse d'interview

_Consolidation des choix de design issus de l'interview (manche par manche) sur la base de `ETUDE-PROGRESSION`. Sert de référence pour diriger l'ensemble du projet._

> **Vision en une ligne.** Un tactique-RPG « **XCOM tempéré** » au service d'un thème — *on prend ce monde, le monde répond* — où l'on **joue l'envahisseur** ; où **monter une unité, c'est verrouiller une voie de perks** ; où l'on **arbitre entre opportunités concurrentes** sur une carte que le monde reprend ; et où l'on **ne perd jamais ses héros — mais on les épuise**.

---

## 0. Le thème — la racine du « pourquoi »

> **On prend ce monde. Le monde répond.** *(thème n°1)*

Le joueur dirige une **équipe d'extraction** : il arrive, il vide, il repart. Le monde n'est pas un décor — il encaisse, il résiste, puis il **barre le passage**. L'incertitude n'a pas disparu, elle a **changé de camp** : ce n'est plus la réalité qui vacille, c'est **la version des faits** que le joueur a reçue (qui sont vraiment ceux d'en face, ce que veut la puissance rivale, pourquoi les visiteurs épargnent les civils).

> **À refaire :** les textes d'ouverture (`texts/`, ex-`Opening.txt`) portent encore l'ancien thème de la réalité distordue et doivent être réécrits.

**Conséquence directrice : les mécaniques ne sont pas justifiées d'abord par l'anti-treadmill, mais par le thème.** Chaque choix doit être une *traduction jouable* de « on prend, le monde répond / notre version des faits s'effrite ». L'argument anti-corvée (cf. `ETUDE-PROGRESSION`) reste valable, mais vient *en second* — il sert le thème.

| Le thème… | …se traduit en | Réf. |
|---|---|---|
| On impose un ordre au monde | **Grille régulière au départ** — la carte telle que le Consortium l'a tracée, propre et prévisible | géométrie |
| Le monde reprend ce qu'on lui prend | **Le maillage se désaligne** de mission en mission : carré → organique/fractal, tailles très inégales, **et ça bloque le passage** — *moteur prêt des deux côtés, inversion à câbler* | geoscape |
| L'incertitude augmente | **RNG assumé** en combat (potentiellement croissant) | C7 écarté |
| On ne retrouve pas la certitude/le passé | **Pas de retour en arrière** (pas de respec/undo/reload) | réversibilité |
| La déformation est irréversible | **Choix de perks & macro définitifs** | B1, C5 |
| On vit avec le monde déformé | **L'échec fait avancer**, on ne recharge pas | C4 |
| Le doute ronge les personnages | **Stress + fatigue**, identité forte (on doute de ce à quoi on tient) | C3, B9 |

---

## 0 bis. Le cadre narratif — l'allégorie *(figé)*

Le thème abstrait (« on prend, le monde répond ») reçoit une **incarnation narrative arrêtée**. Elle dirige l'écriture des textes, le bestiaire et la fin.

**Le cadre — *La Foreuse*.** Science-fiction, 100 % original (aucun emprunt à une œuvre existante : le point était explicitement de sortir de toute question de licence). **Le joueur dirige l'équipe d'extraction d'un consortium interstellaire** débarquée sur un monde vivant pour le vider et repartir. Ton **sombre, avec humour** : brutalité industrielle, absurdité corporate, personne ne se croit méchant.

**La cause — pas une faute, un modèle d'affaires.** Il n'y a pas d'accident fondateur à réparer : la dévastation est le **fonctionnement normal** de la machine, mission après mission, quota après quota. Le joueur n'arrive pas après la catastrophe — **il est la catastrophe**, et il la conduit.

**L'alibi — « avant l'autre ».** Le Consortium ne se présente jamais comme un pillard : il faut prendre ce monde **avant la Contrepartie**, puissance rivale mal connue qui fait exactement le même métier. C'est le discours qui rend le reste supportable, et le moteur de la **complicité** (curseur choisi : *complice*, pas jubilatoire).

**Le sens — une allégorie du capitalisme et de l'impérialisme.** Le pivot directeur, qui déborde sur la fiction *et* la mécanique :

> Ceux d'en face ne sont ni des monstres ni des sauvages : c'est une **résistance locale**, moderne, qui se bat avec ta technologie récupérée. L'écart est **logistique** (usine et pièces neuves contre casse et bricolage), jamais civilisationnel.

- **La magie appartient au monde.** Le Consortium l'extrait, la raffine et la retourne contre sa source. Le *Siphoner* du joueur tire des fioles d'essence raffinée ; le *Wild Siphoner* d'en face fait le même métier avec un siphon remonté à la main — **le grief est une question de licence, pas de superstition**. C'est là que vit le « chamane du futur ».
- **Le vocabulaire fait la villainisation, pas la fiction.** L'interface affiche les **désignations du Consortium** (« Irregular », « Wrecker », « Barricade »), un lexique d'inventaire. Chaque classe porte en parallèle son **vrai nom** (`trueName` : Hunter, Defender, Warden, Keeper).
- La mécanique **encode déjà l'allégorie**, sans surcouche : les **primes** sont l'appât d'extraction ; l'**usure et la mort** sont le coût humain encaissé par ceux d'en bas ; le motif du **Fallen** (perte du statut protégé une fois le rôle joué) = le travailleur utilisé puis effacé.

**La résolution — le retournement.** L'ennemi final, ce sont les **visiteurs** (`Contact` → *Witness*), ceux qu'on a appris à craindre depuis le début : **ce sont eux « les gentils »**. À la révélation, `revealTruth()` **bascule d'un coup tout le vocabulaire du jeu** vers les vrais noms — rétroactivement, jusque dans le roster et les rapports archivés. Le joueur relit ses propres comptes rendus et voit ce qu'il a fait. Le Consortium, lui, classe le dossier et passe au monde suivant : pas de rédemption institutionnelle, la seule dignité est **individuelle** (celle de l'équipe).

**Indices plantés tôt (pour que le twist soit relu, pas subi).**
- Le `Contact` **n'attaque jamais de civils** — déjà vrai dans les données.
- Le *Wild Siphoner* fait littéralement le même métier que l'arcaniste du joueur.
- La *Counterparty* est le **miroir statistique exact** de l'Enforcer du joueur : même métier, autre drapeau.

> **À l'écriture.** Ton sobre, elliptique, amer, avec l'humour corporate en contrepoint (mémos RH, séminaires bien-être, objectifs trimestriels pendant un saccage). Arc : le briefing officiel → les détails qui ne collent pas → la bascule. **Diégétiser les libellés** (primes, usure, désignations) plutôt que les laisser purement « gameplay ».
>
> **Questions en pause.** (a) Une **méca de pacte / tentation** (avantage immédiat contre usure accrue) pour rendre le choix de la complicité jouable — *non tranché*. (b) La **lueur d'espoir par l'équipe** : usure morale menant à refus d'ordre, sabotage, désertion — *piste retenue au pitch, non spécifiée*. (c) Ancienne galerie de personnages (Sorne, Kael, Wren) **abandonnée** avec l'ancien univers ; à réécrire.

---

## 1. La colonne vertébrale (choix confirmés, cohérents entre eux)

| Couche | Décision | Réf. étude |
|---|---|---|
| **Moteur** | La **décision / bifurcation** avant l'accumulation | B / C |
| **Structure** | **Geoscape concurrent** — missions simultanées, coût d'opportunité | A3 |
| **Pression** | **Horloge douce / locale** (par mission/zone), pas d'horloge globale écrasante | A1 tempéré |
| **Forme** | **Hybride** — ossature narrative fait-main + variance autour | A6 |
| **Contenu** | **Procédural borné + golden path** (gabarits + moments clés faits main) | A6 |
| **Puissance** | **Niveaux discrets + perks**, lisibles et plafonnés | B3 |
| **Profondeur du build** | **Choix de perks exclusifs par unité** (le build = somme des portes fermées) | B1 |
| **Réversibilité** | **Définitive** — pas de respec, pas d'undo | anti-pattern réversibilité |
| **Économie** | **Monnaies séparées, quasi pas de loot** — stuff et argent volontairement effacés | B8 |
| **Mort** | **Asymétrique** — la plupart mortels ; persos clés K.O. tant qu'ils servent l'histoire (statut **temporaire**) | C1 |
| **Usure** | **Stress + Fatigue** → rotation forcée du roster | C3 |
| **Échec** | **Produit du contenu** (revers narratif), jamais de reload | C4 |
| **Macro** | **Choix exclusifs réels** — vraie non-linéarité, contenu manquable | C5 |
| **Récit** | **Personnel léger** (faits d'armes, historique) | C6 |
| **Identité** | **Forte / customisation** — soldats nommés, personnalisés | B9 |

---

## 2. Le fil rouge — ce qui relie tout

La décision a du **poids** parce qu'elle est **irréversible** : perks définitifs, choix macro exclusifs, échec qui fait avancer. Aucune de ces portes ne se rouvre.

La **rareté** — moteur classique de la décision — n'est **pas** placée dans l'argent ou le loot (effacés), mais dans le **temps de tes unités** :

> **Stress + Fatigue + mort asymétrique** rendent tes meilleures unités régulièrement **indisponibles**. Tu es donc forcé de **faire tourner un roster**, donc d'**investir dans plusieurs builds divergents** (puisqu'ils sont non-respecables).

C'est l'élégance du système : **une seule pression** — « mes bonnes unités sont indisponibles » — alimente à la fois **l'enjeu** (je risque de devoir jouer sous-optimal) **et** la **décision** (dans qui j'investis, qui je repose, qui je sacrifie à cette mission). Macro et micro tirent sur la même corde.

---

## 2 bis. Décision d'architecture — le geoscape EST un maillage

*Actée à l'interview. Le geoscape réutilise le principe géométrique de la carte tactique (cellules irrégulières carré/hexa/pentagone, adjacence).*

- **Une seule géométrie pour les deux échelles.** Le `genMesh` actuel (Voronoï sur graines en trame carré/hexa/pentagone, jittées) sert tel quel, à **densité grossière**. Identité visuelle « fractale » + un seul moteur de géométrie/rendu. **Ancrage thème :** la même grille déformée à toutes les échelles = la distorsion est partout.
- **Le maillage EST la carte** (et non un graphe posé dessus). L'ancien node-graph de campagne (tâche #10) devient une simple **couche logique** = l'adjacence des cellules.
- **Une cellule stratégique = une région** porteuse d'une opportunité (mission), dont les voisines sont menacées/verrouillables. L'escouade est un pion qui s'y déplace ; le déplacement **coûte du temps** → rend les unités indisponibles (branche le fil rouge §2).
- **Génération hybride** (cohérent A6) : graines **posées à la main** pour les lieux nommés du golden path + remplissage **procédural borné** autour.
- **Réemploi gratuit des mécaniques tactiques au niveau stratégique :** élévation = terrain stratégique (relief lent), murets/arêtes = routes coupées / fronts, **pods = menaces qui rôdent** sur la carte (la pression locale, A1).
- **Levier thème fort — implémenté :** le maillage **se déforme de mission en mission et d'acte en acte** (niveau cumulé). Distorsion *purement géométrique* (sommets déplacés par un bruit déterministe de position) : l'adjacence topologique est figée avant déformation → arêtes jointes, rendu sans couture, jeu inchangé.
- **À câbler — l'inversion :** dans le nouveau cadre le sens s'inverse. On **démarre en grille régulière** (la carte du Consortium) et l'organique la **reconquiert** : cellules irrégulières de tailles très inégales, trous, **passage bloqué**. Le moteur produit déjà les deux extrêmes (grille ↔ maillages fractals type pinwheel, conformes et connexes par arêtes) ; il reste à piloter la bascule par la progression de campagne, et à revoir la palette (le voile violacé était l'ancien univers).
- **À surveiller — lisibilité.** Un Voronoï irrégulier se « lit » moins bien comme un *lieu* qu'un graphe propre → iconographie par cellule indispensable (type de mission, menace, statut).

---

## 3. Détail par couche

### A — Macro
- **A3 Geoscape concurrent.** Plusieurs missions/opportunités ouvertes en même temps ; on ne peut pas tout faire → coût d'opportunité permanent. *(Rendu sous forme de maillage — cf. §2 bis.)*
- **A1 Horloge douce/locale.** La pression est portée par chaque mission/zone (objectifs en N tours, menaces qui montent localement), pas par une horloge globale anxiogène.
- **A6 Hybride + procédural borné.** Une campagne à ossature écrite (golden path, beats narratifs) ; cartes/rencontres générées par gabarits bornés autour, pour la variété sans perdre le contrôle. L'éditeur de maillage sert à faire-main les moments clés.
- **C5 Choix exclusifs réels.** Sauver une zone peut en condamner une autre ; des branches verrouillent du contenu. Assumé : du contenu ne sera jamais vu en une partie.

### B — Micro
- **B3 Niveaux discrets + perks.** Progression lisible, plafonnée ; la puissance vient des **choix** de perks/équipement, pas d'un robinet de stats.
- **B1 Perks exclusifs par unité.** À chaque grade, capacité « A ou B » irréversible. L'arbre parcouru **est** l'identité de l'unité.
- **Monnaies séparées + quasi pas de loot.** L'économie et le stuff ne sont **pas** des leviers de progression ; on évite le robinet à loot et le juggling de ressources. Le poids décisionnel est concentré sur les perks.
- **Réversibilité définitive.** Pas de respec, pas d'undo : c'est ce qui donne tout leur poids aux choix de perks. **Pilier le plus solide du profil.**

### C — Tension / enjeux
- **C1 Mort asymétrique.** **Tous les personnages sont nommés.** Certains ont un **statut spécial** qui les rend **indispensables à l'histoire** : ceux-là tombent K.O. (récupérables) plutôt que de mourir — les perdre bloquerait le récit. **Tous les autres — nommés et attachants eux aussi — peuvent mourir définitivement.** Enjeu de perte bien réel (il frappe des persos qu'on connaît), sans cul-de-sac narratif. **Statut non définitif :** une fois qu'un personnage a accompli son rôle dans l'histoire, il **perd** sa protection et redevient mortel comme les autres → **personne n'est à l'abri pour toujours** (renforce le thème : même la sécurité s'effrite).
- **C3 Stress + Fatigue.** Deux jauges hors-combat à récupération lente → rotation du roster (cf. fil rouge). **Pas** d'attrition financière (économie effacée).
- **C4 L'échec fait avancer.** Un revers monte la menace / ouvre une branche / produit une situation, la partie continue. Tue le save-scum, alimente le récit.
- **C6 Récit personnel léger.** Les unités accumulent un historique (faits d'armes, surnoms) ; **pas** de simulation sociale lourde type Crusader Kings.
- **B9 Identité forte.** **Toutes** les unités sont nommées et customisables → on s'attache à chacune, donc la perte / le K.O. / la rotation portent émotionnellement.
- **Pas de séquelles permanentes (C2 écarté).** Le corps des persos reste simple ; l'usure passe par stress/fatigue, pas par la mutilation.

---

## 4. Frictions avec l'étude — arbitrage

### Friction 1 — RNG vs moteur « décision » · **OUVERT (à prototyper)**
Tu hésites entre **RNG tempéré** (touches fiables, variance sur dégâts/init) et **RNG plein** (ratages à %).

- Un point déjà fixé tranche en partie : **pas de save-scum + l'échec fait avancer.** Le gros défaut du RNG plein (rechargement frustré) **n'existe pas ici** — un ratage devient une *war story* qui alimente le geoscape. Le RNG plein est donc **plus défendable** chez toi qu'ailleurs.
- À l'inverse, le RNG brouille la lisibilité décisionnelle (« bien joué, perdu au dé »).

> **Décision : laisser ouvert.** Socle = **RNG tempéré**, avec un **curseur de variance** assumé. À régler manette en main, c'est *le* point qui se tranche en prototype, pas sur le papier.

### Friction 2 — « mix nombre + level-scaling » vs anti-pattern · **RÉSOLU**
Choix retenu : **mix franc (nombre + stats), mais scaling-stats borné par zone** (paliers, pas une fonction continue qui colle au joueur).

> **Pourquoi le borner.** Le treadmill ne vient pas du scaling en soi, mais du scaling **vertical en lockstep** : si les stats ennemies montent au même rythme que les tiennes, l'écart relatif reste constant et tu ne te sens jamais plus fort (*l'inflation verticale dévalorise l'effort passé*).
>
> **Pourquoi ce n'est pas un problème ici.** Ta progression est surtout **horizontale** (perks = nouveaux *verbes*, pas de plus gros nombres). Un nouveau verbe ne se fait pas avaler par +X% de PV ennemi. Le scaling-stats borné dose donc la difficulté **sans** manger tes gains. C'est la part numérique seule qui doit rester bornée.

---

## 5. Ce que la direction EXCLUT (anti-scope)

Aussi important que les choix positifs — ce qu'on s'interdit pour rester cohérent :

- **Pas de loot-grind / robinet à objets.** Le stuff n'est pas un levier de puissance.
- **Pas de respec / undo / save-scum.** Les choix sont définitifs.
- **Pas de séquelles/mutilations permanentes.**
- **Pas de simulation sociale lourde** (récit émergent reste *léger*).
- **Pas d'horloge globale écrasante** (pression locale seulement).
- **Pas de level-scaling continu non-borné.**
- **Pas de montée verticale comme moteur principal** (les stats sont du décor, cf. étude §D.7).

---

## 6. Prochaines étapes — traduire en pratique

1. **Combat « Cœur maillage ».** Spécifier la boucle de combat sur le maillage : verbes de base, système de perks (arbre A/B par grade), tour-par-tour, dosage RNG (proto).
2. **Jauges Stress + Fatigue.** Modéliser les deux jauges, leur récupération à slots limités, et l'effet sur la disponibilité du roster.
3. **Geoscape = maillage (PoC).** Réutiliser `genMesh` à densité grossière pour une carte stratégique cliquable (cellule = région/opportunité) ; adjacence = déplacement ; horloge locale par mission. Tester la lisibilité (cf. §2 bis).
4. **Boucle « échec fait avancer ».** Définir 2–3 conséquences de revers qui produisent du contenu plutôt qu'un game-over.

> _Friction 1 (RNG) à trancher au stade prototype combat. Tout le reste est figé._
