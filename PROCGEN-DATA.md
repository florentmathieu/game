# Procgen — données d'auto-évaluation & calibration (P2)

_Résultats du banc d'essai `tools/sim-mesh.cjs` (IA-vs-IA headless sur le moteur maillage). ~50 configurations × 6–8 parties. Sert à calibrer les paramètres de génération : **taille de map, espacement & distance des pods, mouvement, couvert, nombre de pods**._

> **Méthode.** `tools/mesh-engine.cjs` charge le vrai moteur de `index.html` en Node (stubs DOM, anims neutralisées) ; une IA générique synchrone joue les deux camps jusqu'à victoire/défaite/timeout. Deux modèles : **séquentiel** (réaliste — les pods s'activent quand on les repère) et **simultané** (pire cas — tout s'active d'un coup). Métriques par map : couvert %, distance déploiement→pod, espacement min des pods, accessibilité.
>
> **Caveat majeur.** L'IA joueur est **naïve** (pas de vigilance, usage du couvert/focus-fire limité, pas de potions). Les **taux de victoire sont une borne basse** ; un humain (ou une meilleure IA) gagne davantage. Les **tendances relatives** (quel paramètre aide) sont fiables ; les valeurs absolues sont pessimistes.

---

## 1. Modèle séquentiel (réaliste)
`win% / loss% / timeout%`, moyennes sur 8 parties. Map de base 12×9 (~262 cellules) sauf balayage taille.

| Paramètre balayé | win% | loss% | to% | tours | survivants J | tendance |
|---|---|---|---|---|---|---|
| **Taille** 8×6 | 0 | 100 | 0 | 5 | 0 | trop petit = on subit tout |
| **Taille** 12×9 | 13 | 63 | 25 | 16 | 0.9 | |
| **Taille** 16×12 | 13 | 50 | 38 | 22 | 1.5 | |
| **Taille** 20×14 | 25 | 25 | 50 | 27 | 2.8 | **+ grand = + facile** (isolement des pods) |
| **Mouvement** MOB=2 | 0 | 88 | 13 | 13 | 0.3 | trop lent |
| **Mouvement** MOB=3 | 13 | 63 | 25 | 16 | 0.9 | **seuil mini** |
| **Mouvement** MOB=4–5 | 13 | ~68 | ~19 | ~15 | ~0.8 | au-delà, peu d'effet |
| **Espacement** spc=2 | 0 | 88 | 13 | 13 | 0.1 | multi-activation = mortel |
| **Espacement** spc=3 | 0 | 100 | 0 | 7 | 0 | |
| **Espacement** spc=5 | 13 | 88 | 0 | 6 | 0.1 | **≥5 = on les prend un par un** |
| **Espacement** spc=7 | 13 | 75 | 13 | 12 | 0.6 | |
| **Dist. dépl→pod** 3→12 | 13 | 63 | 25 | 16 | 0.9 | **peu d'effet seul** (une fois ≥3) |
| **Nb pods** 1 | 63 | 0 | 38 | 20 | 4.0 | |
| **Nb pods** 2 | 50 | 13 | 38 | 22 | 2.9 | **fenêtre équilibrée** |
| **Nb pods** 3 | 13 | 63 | 25 | 16 | 0.9 | dur |
| **Nb pods** 4 | 0 | 100 | 0 | 7 | 0 | brutal |
| **Nb pods** 5 | 0 | 88 | 13 | 10 | 0.1 | |
| **Couvert** 0.12 | 13 | 75 | 13 | 12 | 0.9 | |
| **Couvert** 0.22 | 0 | 88 | 13 | 11 | 0.3 | |
| **Couvert** 0.32 | 25 | 50 | 25 | 18 | 1.4 | **optimum ~0.30** |
| **Couvert** 0.45 | 0 | 75 | 25 | 17 | 0.8 | trop = blocage des lignes |

## 2. Modèle simultané (pire cas — tous les pods d'un coup)
Sous engagement total, **map/mouvement/espacement/distance n'ont quasi aucun effet** : seul le **nombre de pods** compte (1–2 pods → victoire ; 3+ → défaite à 100%). C'est attendu : si tout s'active ensemble, l'espace et la séparation ne servent plus. Cela **démontre l'importance de l'activation séquentielle** (et donc de l'espacement/distance) pour un design jouable.

---

## 3. Lecture & réglages calibrés
- **Le nombre de pods est le dial de difficulté maître.** Pour l'escouade actuelle (4 unités) + IA naïve (borne basse) : **facile = 1 pod, moyen = 2, difficile = 3**. (4+ est punitif même pour un humain prudent.)
- **Espacer les pods (≥ 4–5 sauts)** pour garantir l'activation séquentielle — sinon multi-activation = défaite.
- **Mouvement MOB ≥ 3** (en dessous, le joueur ne peut pas se repositionner).
- **Couvert ~ 0.30.**
- **Maps moyennes-grandes** (≥ 12×9) : l'espace permet d'isoler les pods et de manœuvrer.
- **Distance déploiement→pod** : garder ≥ 3 (au-delà, peu d'effet ; sert surtout à ne pas être collé aux pods au départ).

### Réglages appliqués au générateur
- `podCount` par difficulté : **1 / 2 / 3** (était 2 / 3 / 4).
- `podSpacing` par défaut : **4** (était 3).
- Couvert par défaut : **30 %** (était 28 %).

---

## 3 bis. Balayages croisés (interactions) — `tools/sim-grid.cjs`
`win%` (borne basse, 10 parties/case), modèle séquentiel, espacement 4, MOB 3.

**Nombre de pods × taille de map** (couvert 0.30) :

| pods \ board | 10×7 | 13×10 | 17×12 | 22×15 |
|---|---|---|---|---|
| 1 | 90 | 50 | 70 | 80 |
| 2 | 50 | 40 | 60 | 50 |
| 3 | 0 | 30 | 20 | 10 |
| 4 | 0 | 0 | 0 | 0 |

→ **Le nombre de pods écrase la taille.** Pas de règle « agrandir la map avec la difficulté » : pour 3 pods, le moyen (13×10) est le moins pire. **Garder des maps moyennes** ; régler la difficulté par les pods, pas la taille.

**Nombre de pods × couvert** (board 13×10) :

| pods \ couvert | 0.15 | 0.25 | 0.35 | 0.45 |
|---|---|---|---|---|
| 1 | 100 | 60 | 40 | 80 |
| 2 | 90 | 70 | 20 | 30 |
| 3 | 0 | 10 | 10 | 20 |

→ À 1-2 pods, **moins de couvert favorise le joueur** ; à 3 pods, plus de couvert aide l'assiégé. **Attention : effet AI-dépendant** — l'IA naïve n'exploite pas le couvert (seuls les ennemis en profitent). Un humain inverserait probablement. **On ne sur-ajuste pas le couvert** sur cette base ; on garde ~0.30 et on re-mesurera avec une meilleure IA.

**Conclusion robuste (indépendante du biais IA) : le nombre de pods est le dial de difficulté ; 4 pods est imbattable même avec retraite/espace → plafond difficile = 3 confirmé.**

## 4. Limites & prochaines pistes
- **IA joueur naïve** → refaire les sweeps quand l'IA s'améliore (vigilance, couvert, focus-fire, potions), ou ajouter un mode « IA experte » pour une borne haute. La vérité est entre les deux bornes.
- **Patrouille** : les sims figent les pods dormants ; tester l'effet de la patrouille sur les multi-activations (un pod qui erre peut en réveiller un autre / entrer dans la vue).
- **Archétypes** : ces données concernent l'élimination ; sauvetage/extraction/défense auront d'autres courbes.
- **Boucle de filtrage** : rejeter automatiquement les maps hors fenêtre (ex. garder 40–70 % de victoire estimée) et les dégénérées (déjà 0 ici).
