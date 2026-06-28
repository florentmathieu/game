# Porter « Cœur maillage » dans Godot 4 — guide

_But : réécrire le jeu (actuellement un seul `index.html`, IIFE + canvas) dans Godot
sans repartir de zéro. La logique est déjà découplée du rendu (preuve :
`tools/mesh-engine.cjs` fait tourner tout le moteur en Node, DOM stubé). On garde les
données, on porte les règles, on remplace la vue._

---

## 1. Stratégie

- **Ne PAS embarquer le JS** dans Godot (pas de runtime JS natif en Godot 4 ; QuickJS via
  GDExtension = fragile et inutile ici).
- **Réécrire la logique en GDScript**, en utilisant `index.html` comme **spécification
  exécutable** et `tools/*.cjs` comme **oracle de test** (golden master).
- **Garder les fichiers de données** tels quels (JSON) : missions, geoscapes, campagnes,
  `texts/`. Godot les lit nativement.

Trois couches (comme aujourd'hui) :

| Couche | Aujourd'hui | Godot |
|---|---|---|
| Données | JSON + `texts/*.json` | inchangées — `FileAccess` + `JSON.parse_string` |
| Modèle / règles | fonctions pures de l'IIFE | classes GDScript **sans nœud** (testables headless via GUT) |
| Vue | `draw()` canvas, `fx`, `playText`, `localStorage` | nœuds, tweens, `RichTextLabel`, `user://` |

Règle d'or : **le modèle ne doit jamais référencer un nœud**. Il expose un état + des
méthodes + des **signaux**. La vue observe les signaux et envoie des intentions.

---

## 2. Arbre de scènes proposé

```
Main (autoload: Game = état global + chargement données + RNG)
├── TitleScreen
├── Geoscape (scene)            # carte stratégique
│   ├── RegionLayer (Node2D)    # 1 Polygon2D par région (ou _draw global)
│   ├── PathLine (Line2D)       # aperçu chemin mauve
│   ├── RosterPanel (Control)
│   └── Banner (Control)
├── Battle (scene)              # combat
│   ├── MeshLayer (Node2D/_draw)# cellules, murets, brouillard, voile de corruption
│   ├── Units (Node2D)          # 1 UnitView par unité (sprite + barre PV + facing)
│   ├── FxLayer (Node2D)        # dégâts flottants, explosions, givre → tweens
│   ├── HUD (Control)           # PA, capacités (cooldowns), journal
│   └── TextPlayer (Control)    # RichTextLabel, pages séparées par « _ »
└── rules/ (scripts sans scène)
    ├── Rng.gd, Mesh.gd, Combat.gd, Abilities.gd, Ai.gd,
    ├── Geoscape.gd, Progression.gd, Campaign.gd, Tune.gd
```

Événements modèle → vue via **signals** (remplacent `emit()`/`log()`/`pushDmg`) :
`damage_dealt(unit, amount)`, `unit_moved(unit, path)`, `turn_changed(side, n)`,
`ability_used(unit, id, target)`, `region_attacked(name)`, `forge_unlocked(bonus)`, …

---

## 3. Inventaire fonction par fonction

Légende : **PORTER** = traduire ~à l'identique · **REMPLACER** = équivalent Godot natif ·
**RÉÉCRIRE** = dépend du rendu/UI.

### Maillage & géométrie
| index.html | action | note Godot |
|---|---|---|
| `mk(seed)` (PRNG) | **PORTER à l'identique** | indispensable pour la repro procédurale (voir §4) |
| `genMesh` / `geoVoronoi` | PORTER | maths pures (Voronoï clippé) ; rendu = `Polygon2D` |
| `buildAdj` (nb/edgeNb/wallSeg) | PORTER | clé d'arête arrondie → `Dictionary` |
| `polyCentroid`, `pointIn`, `cellAtXY` | PORTER | `cellAtXY` peut aussi se faire via `Area2D`/clic |
| `distortTerrain` | PORTER | warp déterministe + adjacence figée |

### Déplacement / vision
| `reach(u)` (Dijkstra + budget PA) | PORTER | cœur du jeu, voir squelette §6 |
| `hops`, `pathTo` | PORTER **ou** `AStar2D` | AStar2D : 1 point/cellule, `connect_points` selon `nb` |
| `los` (échantillonnage de segment) | PORTER | ou `RayCast2D` contre des `StaticBody` de rochers |
| `budget`, `apForMove`, `passable`, `occ`, `adjacent` | PORTER | trivial |
| `computeVis`/`computeEVis` (brouillard) | PORTER | masque de visibilité = set d'ids |

### Combat
| `chance(att,tgt,m)` | PORTER | couvert/hauteur/portée/bracing — voir constantes §7 |
| `doAttack`, `shieldBlock`, `muretCover` | PORTER | résolution pure ; le « jus » part en signals |
| `U(team,cls,cell,opts)` (fabrique d'unité) | PORTER | → un `RefCounted`/`Dictionary` d'état |
| `CLASSES`, armes (`sword`/`bow`) | PORTER (données) | mets-les en `.tres`/JSON si tu veux les éditer |

### Capacités & cooldowns
| `ABIL` (registre) + `exec*` | PORTER | dict de défs + méthodes ; `target` ∈ self/cell/enemy/ally |
| `COOLDOWN`, `onCd/setCd/tickCd`, `CD_MULT` | PORTER | `u.cd` = `Dictionary` |
| statuts `stunned`/`slowed`/`bracing`/`taunt`/`wallStance` | PORTER | champs d'état |

### Progression / usure / macro
| `PERKS`, `perkById`, `applyPerkMods`, `gradeFromXp` | PORTER | données + apply |
| `applyAttrition` (stress/fatigue), `applyCarry`, mort | PORTER | |
| forge (`forgeBonus`, `addForgeEnemies`) | PORTER | |
| Geoscape : `genGeoMap`, `geoAccessibleSet`, `geoPathTo`, primes, `maybeAttackRegion`, `podCenters/podOwns` | PORTER | logique pure |
| `ACT_MISSIONS`, `GEO_NAMES`, `BOSS_NAME`, profils de distorsion | PORTER (données) | |

### IA
| IA ennemie de combat (`endTurn`→`step` : scoring de case) | **PORTER** | une seule IA à porter (voir §8) |
| `enemyUseAbil`, `enemyShieldAct`, `patrolStep` | PORTER | |
| `tools/ai.cjs` (IA symétrique du banc d'essai) | **NE PAS porter** | reste un outil Node de test |

### Vue / IO (à RÉÉCRIRE)
| `draw()` canvas, `shade`, voile de corruption, icônes | RÉÉCRIRE | `_draw()` / `Polygon2D` / `Line2D` |
| `fx`, `pushDmg/pushBlast/pushHeal/pushFrost`, `screenShake` | REMPLACER | tweens + `Camera2D` shake |
| `playText`/`showCampText` (pages `_`, noms en gras) | RÉÉCRIRE | `RichTextLabel` + BBCode |
| `localStorage` (save/resume, roster, tune, events) | REMPLACER | `user://*.json` via `FileAccess` |
| `fetchText` (fichiers + dépôt GitHub) | REMPLACER | `FileAccess` (GitHub : inutile hors éditeur web) |
| panneau d'équilibrage, éditeurs (mission/campagne/geoscape) | OPTIONNEL | à refaire seulement si tu veux l'outil d'édition dans Godot |

---

## 4. Porter le PRNG à l'identique (critique)

La génération procédurale (geoscape, maps) doit rester **reproductible** et
**comparable** au JS. Reproduis exactement `mk` (Mulberry32, arithmétique 32 bits) :

```gdscript
# Rng.gd — réplique de mk() (Mulberry32, arithmétique 32 bits)
class_name Rng
var _s: int
func _init(seed: int) -> void: _s = seed & 0xffffffff
func next() -> float:                                  # ∈ [0,1)
    _s = (_s + 0x6D2B79F5) & 0xffffffff
    var t := _imul(_s ^ (_s >> 15), _s | 1)            # t = imul(s ^ s>>>15, 1|s)
    t = (_imul(t ^ (t >> 7), t | 61) + t) ^ t          # t = imul(t ^ t>>>7, 61|t) + t ^ t
    t &= 0xffffffff
    return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0
static func _imul(a: int, b: int) -> int:              # = Math.imul (mult. 32 bits)
    return (a * b) & 0xffffffff                         # int GDScript = 64 bits → masque 32 bits OK
```

> Les `>>>` du JS deviennent `>>` ici car on travaille sur des entiers 32 bits **non
> signés** (toujours masqués `& 0xffffffff`, donc positifs). Valide la fidélité avec le
> test croisé (§9) : `mk(1234)` doit sortir la même suite en JS et en GDScript.

Pour le hasard **gameplay** (jets de touche `chance`), tu peux utiliser
`RandomNumberGenerator` de Godot — la repro n'y est pas requise.

---

## 5. Structure d'une cellule

En JS une cellule est un objet libre. En Godot, garde un `Dictionary` (souple, proche du
JS) **ou** un `RefCounted` typé. Champs utiles (combat) :
`id, poly:PackedVector2Array, cx, cy, nb:Array[int], edgeNb, terr, elev, zone`.
Geoscape (réutilise le même maillage à l'échelle macro) : `gname, gkind, gref, gstate,
gdiff, gforge, gboss`.

Rendu : un `Polygon2D` par cellule (couleur = `shade()`), `Line2D` pour les murets
(segments `wallSeg`), un `Node2D` overlay `_draw()` pour brouillard + voile de corruption.

---

## 6. Squelette `reach()` (déplacement)

```gdscript
# Mesh.gd — Dijkstra pondéré par le coût d'entrée, borné au budget de PA
func reach(u) -> Dictionary:
    var occu := occupied()           # set de cellules occupées
    var dist := { u.cell: 0 }
    var pq := [[0, u.cell]]           # (coût, cellule) ; remplace par un vrai tas si besoin
    var B := budget(u)                # free move + ap * mob
    while not pq.is_empty():
        var bi := 0
        for i in range(1, pq.size()):
            if pq[i][0] < pq[bi][0]: bi = i
        var top: Array = pq.pop_at(bi)
        var d: int = top[0]; var id: int = top[1]
        if d > dist[id]: continue
        for n in cells[id].nb:
            if occu.has(n): continue
            if fog_blocks(u, n): continue       # brouillard + LdV (computeVis)
            var c := enter_cost(id, n)          # null = infranchissable
            if c == -1: continue
            var nd := d + c
            if nd <= B and (not dist.has(n) or nd < dist[n]):
                dist[n] = nd; pq.append([nd, n])
    dist.erase(u.cell)
    return dist
```

`hops`/`pathTo` se portent pareil (BFS / Dijkstra avec `prev`). Alternative : `AStar2D`
peuplé une fois par mission (`add_point`/`connect_points`), mais `reach` (budget PA +
brouillard) reste maison.

---

## 7. Constantes d'équilibrage à transférer

Mets-les dans un `Tune.gd` (ou un JSON éditable, comme le panneau actuel) :
`AP_MAX, MOB, FREE_MP`, `HEIGHT_BONUS=6, COVER_PEN=30, DEF_BRACE=20`, `PB={1:30,2:15}`
(bonus point-blank), `ENEMY_COUNT`, `CD_MULT`, `FATIGUE_MISSION/STRESS_*`, portées des
sorts (`BLAST_*`, `HEAL_*`, `FROST_*`, `CHARGE_RANGE`), profils de distorsion
(`fracs`/`distPct`), seuils de prime, `ATTACK_CHANCE/ATTACK_GAP`.

---

## 8. Squelette IA ennemie (combat)

Pas de ML : un scoring de case, tour par tour. Port direct de `endTurn`→`step`.

```gdscript
# Ai.gd
func enemy_take_turn(e, state) -> void:
    if not is_active(e):                 # pas alerté → patrouille bornée à la zone du pod
        patrol_step(e); return
    if shield_act(e): return             # porteur de bouclier : charge / repousse (termine le tour)
    var seen := visible_foes(e)
    if seen.is_empty(): search_act(e); return
    # 1) choisir la meilleure case atteignable
    var d := reach(e); var best := e.cell; var best_score := -INF
    for cell in [e.cell] + d.keys():
        var off := max_shot_from(cell, e, seen)         # espérance de tir
        var thr := incoming_threat(cell, seen)          # feu reçu
        var near := nearest_foe_hops(cell, seen)
        var s := off - 0.7*thr - 1.5*near + 0.5*elev(cell) - clump(cell) + encircle(cell)
        if s > best_score: best_score = s; best = cell
    # 2) bouger (animer via tween), puis agir
    if best != e.cell:
        await move_unit(e, best)         # await tween.finished
    if enemy_use_abil(e): return         # mage : déflagration/givre
    var t := best_target(e)
    if t: do_attack(e, t, e.wtype)
```

Le **séquencement** (aujourd'hui `setTimeout` entre actions) devient `await` sur les
tweens/timers — plus propre et déterministe côté logique.

Patrouille : marche aléatoire bornée à la **zone Voronoï du pod** (`podOwns`), déjà
implémentée — garantit que deux pods ne patrouillent pas les mêmes cases.

---

## 9. L'atout : garder un oracle de test

`tools/mesh-engine.cjs`, `night-test.cjs`, `check-campaigns.cjs`, `distort-test.cjs`
restent utilisables en Node. Sers-t'en pour valider le port :

1. **Test croisé du PRNG** : génère N valeurs `mk(1234)` en JS et en GDScript → doivent
   être identiques. (Si le PRNG colle, la génération procédurale colle.)
2. **Maillage** : même `seed` → mêmes polygones / même nombre de cellules / même adjacence.
3. **Combat** : rejoue une séquence scriptée (mêmes seeds, mêmes ordres) et compare les PV
   finaux. Écris ces oracles en JSON depuis Node, charge-les dans des tests GUT.

Ça transforme le port en « faire passer les tests » plutôt qu'en « deviner si c'est pareil ».

---

## 10. Ordre de travail conseillé (jalons)

1. **Rng + Mesh** : porte `mk`, `genMesh`, `buildAdj`, `polyCentroid` ; affiche un maillage
   en `Polygon2D`. Valide via test croisé PRNG + comptage de cellules.
2. **Déplacement** : `reach`/`hops`/`pathTo`/`los` + sélection/déplacement d'une unité avec
   aperçu de portée. (Le « jeu » commence à être jouable.)
3. **Combat** : `chance`/`doAttack`/`shieldBlock`, couvert/hauteur/flanc, PA, fin de tour,
   IA ennemie de base. Tweens pour mouvement + dégâts flottants.
4. **Capacités & perks** : `ABIL`/cooldowns, `applyPerkMods`, statuts.
5. **Geoscape** : `genGeoMap` procédural, accessibilité, primes, forge, régions attaquées ;
   textes depuis `texts/geoscape.json`.
6. **Méta** : usure (stress/fatigue), mort, sélection d'escouade, sauvegarde `user://`,
   distorsion progressive, lecteur de texte.
7. (Optionnel) Éditeurs + panneau d'équilibrage.

---

## 11. Choix de langage

- **GDScript partout** pour commencer : moins de friction, idiomatique. Isole le moteur de
  règles dans des classes **sans nœud** pour le tester headless (GUT).
- **C#** envisageable pour le seul moteur de règles si tu veux du typage strict (le mapping
  depuis le JS — classes, `Dictionary` — est direct), vue en GDScript. À ne faire que si le
  volume de logique te gêne en GDScript.

---

### TL;DR
Tes **données** et tes **algorithmes** se portent presque tels quels ; seules la **vue**,
les **animations** et la **persistance** sont à refaire avec les nœuds Godot. Porte le
**PRNG à l'identique**, garde les **outils Node comme oracle**, et avance par jalons
(maillage → déplacement → combat → capacités → geoscape → méta).
