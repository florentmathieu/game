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
| `say`      | `["QuiParle", "texte"]` (ou `{ "who": "...", "text": "..." }`). `who` par défaut = l'acteur |
| `once`     | `true` par défaut (ne se déclenche qu'une fois). Mettre `false` pour répétable |
| `priority` | si plusieurs triggers matchent le **même** évènement, seul le plus prioritaire se déclenche (défaut 0) |
| `id`       | identifiant optionnel (sinon l'index sert d'id pour le `once`) |

C'est ainsi qu'on gère « sauf si… » : une règle générale (priorité 0) + une règle
plus précise et plus prioritaire (priorité 1) qui la remplace quand elle matche.

## Évènements (`on`) et leur contexte

- **`start`** — début de la bataille. (aucun champ)
- **`attack`** — une attaque est résolue.
  `actor`, `target` (nom **ou** classe), `weapon` (`épée`/`dagues`/`arbalète`/`arc`),
  `result` (`hit`/`miss`/`blocked`), `killed` (bool), `dmg` (nombre), `reaction` (bool),
  `first` (1re action offensive de la bataille, hors riposte), `actorTeam`.
- **`kill`** — une unité meurt. `actor`, `target`, `weapon`.
- **`cracker`** — un cracker explose. `actor`, `enemiesHit`, `alliesHit`, `killed`, `first`.
- **`win`** / **`lose`** — fin de partie.

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
