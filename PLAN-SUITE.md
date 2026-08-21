# Plan — la suite (après l'Acte 1 jouable)

_Feuille de route des prochaines phases. Traduit `DIRECTION.md` (les piliers) et la partie « différé » de `ACTE-1.md` en incréments jouables. Chaque phase = une brique vérifiable, livrée puis poussée._

---

## Où on en est *(mis à jour — août 2026)*

> **Ce document a été écrit avant les phases A→F. Elles sont aujourd'hui faites pour l'essentiel.** Il est conservé comme trace du plan ; les statuts ci-dessous disent où on en est réellement.

**La boucle RPG est debout.** Ce qui manquait à l'écriture de ce plan — *roster persistant → déploiement → progression par choix → usure qui force la rotation → mort à enjeu* — **existe** : roster de campagne persistant, déploiement depuis le roster sur zones de départ, grades + perks A/B irréversibles, stress/fatigue avec repos au camp, mort définitive, sauvegarde/chargement.

**En place également :** éditeurs Mission / Campagne / Geoscape, runtime hub geoscape (carte → mission → retour → déverrouillage → `endWhen`), moteur de combat tour-par-tour (RNG **seedable**, pods, vigilance, crackers, potions, brouillard), génération procédurale de missions avec archétypes d'objectif, calibrage par simulation, lecteur de texte narratif, missions bonus enchaînées, distorsion progressive du maillage, et un **portage Godot 3D** (campagne, cartes, graphe de campagne).

**Ce qui reste :** surtout de la **pression geoscape** (phase E) et du **réglage** (phase F), plus le chantier ouvert par le changement d'univers — voir en bas.

---

## Les phases

### Phase A — Roster persistant + déploiement · *fondation* — ✅ **fait**
Un **escadron de campagne** : persos nommés, persistants d'une mission à l'autre, stockés dans l'état de partie. En mission lancée depuis le geoscape, le joueur **déploie son roster** sur des cases de départ (au lieu des unités pré-placées de la mission). Éditeur : marquer des **zones de déploiement** dans la mission.
- **Livrable :** lancer une région → choisir/déployer ses persos → jouer avec eux.
- **Débloque** B, C, D (tout s'attache au roster). *Réf : préalable à B9/B1/C1/C3.*

### Phase B — Progression par perks · *le pilier « décision »* (B1/B3) — ✅ **fait**
Grades **discrets** ; à chaque grade, un **choix A/B irréversible** — un nouveau *verbe* (capacité), pas un plus gros chiffre. Gain d'XP (ou puissance structurelle) plafonné. Écran de montée entre missions, au camp.
- **Livrable :** un perso monte d'un cran, on choisit A ou B, deux persos identiques divergent durablement.

### Phase C — Stress + Fatigue → rotation · *le fil rouge* (C3) — ✅ **fait**
Deux jauges par perso : montent en mission, **récupèrent lentement au camp à slots limités**. Un perso trop éprouvé/épuisé devient **temporairement indisponible**.
- **Livrable :** enchaîner les missions **force à faire tourner le roster** (jouer l'équipe B), donc à investir dans plusieurs builds.

### Phase D — Mort & statut spécial · *l'enjeu* (C1/B9) — ✅ **fait**
**KO vs mort définitive** (asymétrique) ; **statut spécial temporaire** des persos clés (protégés tant qu'ils servent l'histoire, mortels ensuite). Un mort **quitte le roster**.
- **Livrable :** perdre un perso compte vraiment, sans jamais bloquer le récit.

### Phase E — Pression & échec-fait-avancer · *geoscape vivant* (A1/C4) — 🟡 **partiel** (retour win/lose et déverrouillages en place ; l'horloge/menace locale par région reste à faire)
**Horloge / menace locale par région** ; un **échec change la carte** (région perdue, menace qui s'étend) au lieu de bloquer ; le **camp** devient le hub de récupération (lié à C).
- **Livrable :** tarder ou échouer **transforme le territoire**.

### Phase F — Thème & feel · *polish* — 🟡 **partiel** (distorsion progressive et RNG seedable faits ; le sens de la déformation est à inverser, cf. ci-dessous)
**Déformation progressive de la carte** au fil de l'acte — *faite, mais à réorienter* : dans le nouvel univers on part d'une **grille régulière** que l'organique **reconquiert en bloquant le passage** (cf. `DIRECTION.md`). Trancher le **dosage RNG** (friction 1) manette en main ; **identité/customisation** des persos.
- **Livrable :** le thème se *voit* et se *joue* ; le combat a son grain de hasard calibré.

---

## Dépendances

```
A (roster) ─┬─> B (perks)
            ├─> C (stress/fatigue) ──┐
            └─> D (mort) ────────────┴─> E (pression / échec-fait-avancer)
                                          F (thème & feel) — en dernier, transverse
```

- **A est bloquant** pour B, C, D.
- **E** s'appuie sur D (mort) + C (camp/récupération) + le geoscape (déjà là).
- **F** se fait en dernier (ou par petites touches en continu).

---

## Décision encore ouverte
- **Dosage RNG** (friction 1, cf. DIRECTION) : socle = RNG tempéré + curseur de variance, à trancher **en jouant** — idéalement pendant B/C quand il y a assez de matière.

---

## Cadence
Travail **autonome, phase par phase** : à chaque phase, implémentation → vérification dans Chromium (headless) → commit/push → aperçu. Un seul déploiement Pages à la fois (on laisse chaque build finir avant de pousser le suivant, pour éviter la course de déploiement).

---

## Ce qui s'ajoute depuis le changement d'univers *(août 2026)*

Le passage à **La Foreuse** (cf. `DIRECTION.md` / `VISION-DU-JEU.md`) ouvre trois chantiers qui ne figuraient pas dans le plan d'origine :

- **G — Inversion de la géométrie.** ✅ **câblée.** Chaque acte porte un **profil de terrain** — géométrie de départ et d'arrivée — et chaque mission **interpole entre les deux selon son rang dans l'acte**. Le défaut part d'une vraie grille (mesuré : distorsion 0 %, **72 % des cases ont exactement 4 voisins**) et finit en organique (**5,4 voisins de moyenne**, hexagones et pentagones majoritaires). Édition dans l'onglet Campagne, « Terrain de l'acte », avec aperçu. *Reste :* revoir la palette (le voile violacé appartenait à l'ancien univers), et faire que ce qui repousse **bloque** vraiment le passage plutôt que de seulement changer de forme.
- **H — Brancher le retournement.** `revealTruth()` bascule déjà tout le vocabulaire du jeu vers les vrais noms ; reste à le **déclencher depuis un nœud de campagne** et à le **persister dans la sauvegarde**, pour que les rapports archivés se relisent après coup.
- **I — Réécrire les textes.** Les textes narratifs (`texts/`) portent encore l'ancien thème de la réalité distordue. *(Écriture — hors périmètre technique.)*

> **Prochaine étape suggérée : H (brancher le retournement)** — G est câblée, et H est le second endroit où le thème devient jouable plutôt qu'écrit.
