# Évènements scriptés (triggers) d'une mission

Une mission peut contenir un tableau `triggers` : des règles qui déclenchent une
réplique (ou une action) quand un évènement de combat correspond.

```json
{
  "name": "Embuscade du pont",
  "cols": 16, "rows": 14,
  "elev": [...], "rocks": [...], "walls": [...], "units": [...],
  "triggers": [
    { "on": "attack",  "match": { "actor": "Gizzard", "first": true, "result": "miss" },                 "say": ["Gizzard", "texte 1"] },
    { "on": "attack",  "match": { "actor": "Gizzard", "first": true, "result": "hit", "killed": false },  "say": ["Gizzard", "texte 2"] },
    { "on": "cracker", "match": { "actor": "Merry",   "first": true },                                    "say": ["Merry", "texte 3"] },
    { "on": "cracker", "match": { "actor": "Merry",   "first": true, "enemiesHit": 1 }, "priority": 1,     "say": ["Merry", "texte 4"] }
  ]
}
```

## Un trigger

| champ      | rôle |
|------------|------|
| `on`       | type d'évènement (voir liste) |
| `match`    | conditions ; **tous** les champs doivent correspondre au contexte |
| `say`      | une réplique : `["QuiParle", "texte"]` ou `{ "who": "...", "text": "..." }`. `who` par défaut = l'acteur |
| `lines`    | une **série** de répliques jouées à la suite : `[["Gizzard","…"], ["Merry","…"], …]` |
| `once`     | `true` par défaut (ne se déclenche qu'une fois). Mettre `false` pour répétable |
| `priority` | si plusieurs triggers matchent le **même** évènement, seul le plus prioritaire se déclenche (défaut 0) |
| `id`       | identifiant (pour être référencé par `requires`/`forbids`) |
| `requires` | id(s) d'autres triggers qui doivent **déjà s'être déclenchés** (chaîne ou liste) |
| `forbids`  | id(s) qui ne doivent **pas** s'être déclenchés |

### Actions (en plus du dialogue)

Un trigger peut aussi agir sur le monde (cumulable avec `say`/`lines`) :

| champ    | effet |
|----------|------|
| `wake`   | réveille un **pod** : `0`/`1`/… ou `"all"` (tous les ennemis) |
| `spawn`  | fait apparaître des **renforts** : liste d'unités `[{ "cls":"brute", "team":"enemy", "col":8, "row":2 }]` |
| `open`   | **ouvre un passage** : enlève les rochers d'un nom de zone (`"porte"`) ou d'une liste `[[c,r],…]` |
| `close`  | **ferme un passage** : pose des rochers (même format) |

```json
{ "on":"enter", "match":{ "zone":"piège" },
  "say":["Stiff","C'était un piège !"], "close":"sortie", "wake":"all",
  "spawn":[{ "cls":"archer","team":"enemy","col":10,"row":3 }] }
```

Dans l'éditeur, section **Actions (optionnel)** du formulaire : *réveiller pod*, *ouvrir zone*,
*fermer zone* (les renforts `spawn` se font pour l'instant en JSON / via `MGF`).

### Séries et réponses conditionnées

Une **série** se fait avec `lines` (les répliques s'enchaînent dans l'encart).
Une **réponse conditionnée au passage par une réplique** se fait avec `id` + `requires` :

```json
[
  { "id": "rate1", "on": "attack", "match": { "actor": "Gizzard", "first": true, "result": "miss" },
    "lines": [["Gizzard", "et merde"], ["Merry", "joli, l'artiste"], ["Gizzard", "la ferme"]] },
  { "on": "turn", "requires": "rate1", "say": ["Stiff", "concentrez-vous, au prochain tour"] }
]
```

Dans l'éditeur : tape une réplique + **« + ligne »** pour bâtir la série, renseigne un **id**
et un **requiert id(s)** au besoin, puis **« ✓ Créer l'évènement »**. Les triggers ne se
déclenchent **qu'une fois** par défaut.

C'est ainsi qu'on gère « sauf si… » : une règle générale (priorité 0) + une règle
plus précise et plus prioritaire (priorité 1) qui la remplace quand elle matche.

## Le plus simple : l'éditeur

Dans l'éditeur (`?edit`), section **« Évènements (dialogues) »** : choisis *Quand*, remplis
les conditions qui s'affichent, écris la réplique, **+ Ajouter**. La liste se gère avec ✕.
Tout est enregistré dans la mission. (On peut aussi éditer le JSON à la main, ci-dessous.)

## Évènements (`on`) et leur contexte

- **`start`** — début de la bataille. (aucun champ)
- **`turn`** — début d'un tour. `turn` (numéro).
- **`attack`** — une attaque est résolue.
  `actor`, `target` (nom **ou** classe), `weapon` (`épée`/`dagues`/`arbalète`/`arc`),
  `result` (`hit`/`miss`/`blocked`), `killed` (bool), `dmg`, `reaction` (bool),
  `first` (1re action offensive de la bataille, hors riposte), `actorTeam`.
- **`kill`** — une unité meurt. `actor`, `target`, `weapon`.
- **`wounded`** — une unité encaisse des dégâts. `target`, `by` (`byName`), `hp`, `maxHp`,
  `hpPct` (0–100), `killed`. Ex. seuil de PV : `"hpPct": { "max": 30 }`.
- **`cracker`** — un cracker explose. `actor`, `enemiesHit`, `alliesHit`, `killed`, `first`.
- **`friendlyfire`** — `actor` blesse une unité de son propre camp (ou le joueur touche un PNJ/otage). `actor`, `target` (la **victime**, nom **ou** classe), `targetTeam`, `weapon`, `dmg`, `killed`. *(pour l'instant seul le cracker en inflige ; généralisable aux futures attaques via `emitFriendlyFire`)*
- **`move`** — une unité finit un déplacement. `actor`, `col`, `row`, `steps`.
- **`enter`** — une unité **entre dans une zone**. `actor` (vide = n'importe qui), `zone`, `col`, `row`.
- **`spotted`** — un pod **ennemi** se réveille (quelle qu'en soit la cause) **ou** le joueur repère à vue un pod de **PNJ/otages**. `pod`, `actorTeam` (`"enemy"` / `"neutral"`), `by` (`"sight"` = repéré à vue, `"noise"` = bruit/combat).
- **`discovered`** — soit un pod ennemi se réveille **en repérant le joueur à vue** (sans attaque ni bruit), soit le joueur **découvre un pod de PNJ/otages** à vue. `pod`, `actorTeam` (`"enemy"` / `"neutral"`). (sous-cas de `spotted` avec `by:"sight"`)
  - Pour distinguer un pod neutre d'un pod ennemi de même numéro, ajoute `"actorTeam": "neutral"` au `match` (champ **camp** dans l'éditeur). Assigne un n° de pod aux PNJ/otages avec l'outil **👥 Pod**.
- **`win`** / **`lose`** — fin de partie.

## Zones

Les zones se dessinent dans l'éditeur (colonne dédiée, section **Zones**) : « + zone »,
puis l'outil **▦ Peindre la zone** pour colorier les cases. Elles sont stockées dans la
mission (`"zones": [{ "name": "piège", "tiles": [[5,2],[5,3]] }]`) et servent à l'évènement
`enter` (`"match": { "actor": "Gizzard", "zone": "piège" }`).

## Champs de `match`

- `actor` / `target` : comparés au **nom** (`"Gizzard"`) **ou** à la **classe** (`"assassin"`).
- booléens / chaînes / nombres : égalité stricte (`"result": "miss"`, `"killed": false`, `"enemiesHit": 1`).
- nombres avec borne : `{ "min": 2 }`, `{ "max": 1 }`, `{ "min": 1, "max": 3 }`.

## Effet

`say` affiche une **bulle** au-dessus du personnage pendant quelques secondes et une
ligne dans le **journal** (`💬 Gizzard : …`).

## Tester en direct (console du navigateur)

```js
MGF.addTrigger({ on:"attack", match:{ actor:"Gizzard", first:true, result:"miss" }, say:["Gizzard","Raté !"] });
MGF.say("Merry", "Bouge de là !");      // afficher une réplique tout de suite
MGF.triggers;                            // voir les triggers chargés
MGF.resetFired();                        // ré-armer les triggers "once"
MGF.clearTriggers();                     // tout enlever
```

Les triggers sont enregistrés **dans la mission** (champ `triggers`) : ajoute-les au
fichier `missions/xxx.json`, ou mets-les au point en direct via `MGF` puis recopie-les.
