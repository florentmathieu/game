# Plan — la suite (après l'Acte 1 jouable)

_Feuille de route des prochaines phases. Traduit `DIRECTION.md` (les piliers) et la partie « différé » de `ACTE-1.md` en incréments jouables. Chaque phase = une brique vérifiable, livrée puis poussée._

---

## Où on en est

**En place :** éditeurs Mission / Campagne / Geoscape, runtime hub geoscape (carte → mission de région → retour → déverrouillage → `endWhen`), moteur de combat tour-par-tour (RNG, pods, vigilance, crackers, potions, brouillard), effet « île ». **L'Acte 1 se joue en avant** : Opening → mission d'intro → geoscape → fin.

**Ce qui manque — le cœur RPG.** Aujourd'hui : un *bac à sable tactique + une coquille de campagne*. Presque tous les piliers de la DIRECTION ne sont pas encore dans le jeu : progression par choix, usure (stress/fatigue), mort à enjeu, roster persistant.

> **Le constat directeur.** Ce qui transforme le projet en **le jeu de la DIRECTION**, c'est une boucle qui n'existe pas encore :
> **roster persistant → déploiement → progression par choix → usure qui force la rotation → mort à enjeu.**
> Tout s'accroche au **roster persistant** — la fondation manquante (actuellement chaque mission définit ses unités ; la campagne ne transporte que les PV par nom).

---

## Les phases

### Phase A — Roster persistant + déploiement · *fondation*
Un **escadron de campagne** : persos nommés, persistants d'une mission à l'autre, stockés dans l'état de partie. En mission lancée depuis le geoscape, le joueur **déploie son roster** sur des cases de départ (au lieu des unités pré-placées de la mission). Éditeur : marquer des **zones de déploiement** dans la mission.
- **Livrable :** lancer une région → choisir/déployer ses persos → jouer avec eux.
- **Débloque** B, C, D (tout s'attache au roster). *Réf : préalable à B9/B1/C1/C3.*

### Phase B — Progression par perks · *le pilier « décision »* (B1/B3)
Grades **discrets** ; à chaque grade, un **choix A/B irréversible** — un nouveau *verbe* (capacité), pas un plus gros chiffre. Gain d'XP (ou puissance structurelle) plafonné. Écran de montée entre missions, au camp.
- **Livrable :** un perso monte d'un cran, on choisit A ou B, deux persos identiques divergent durablement.

### Phase C — Stress + Fatigue → rotation · *le fil rouge* (C3)
Deux jauges par perso : montent en mission, **récupèrent lentement au camp à slots limités**. Un perso trop éprouvé/épuisé devient **temporairement indisponible**.
- **Livrable :** enchaîner les missions **force à faire tourner le roster** (jouer l'équipe B), donc à investir dans plusieurs builds.

### Phase D — Mort & statut spécial · *l'enjeu* (C1/B9)
**KO vs mort définitive** (asymétrique) ; **statut spécial temporaire** des persos clés (protégés tant qu'ils servent l'histoire, mortels ensuite). Un mort **quitte le roster**.
- **Livrable :** perdre un perso compte vraiment, sans jamais bloquer le récit.

### Phase E — Pression & échec-fait-avancer · *geoscape vivant* (A1/C4)
**Horloge / menace locale par région** ; un **échec change la carte** (région perdue, menace qui s'étend) au lieu de bloquer ; le **camp** devient le hub de récupération (lié à C).
- **Livrable :** tarder ou échouer **transforme le territoire**.

### Phase F — Thème & feel · *polish*
**Déformation progressive de la carte** au fil de l'acte (levier thème « tout se déforme ») ; trancher le **dosage RNG** (friction 1) manette en main ; **identité/customisation** des persos (apparence, historique de faits d'armes).
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

> **Prochaine étape : Phase A — Roster persistant + déploiement.**
