# Plan — intégrer les classes du Sheet

_Ce que le classeur « Classes » demande au moteur, dans l'ordre où ça se construit. Lu par `tools/import-classes.py`, dont le rapport est la référence à jour ; ce document ne fait qu'en tirer un ordre de travail._

**État du Sheet au 23 août 2026 :** Enforcer, Sapper et Stinger réécrits (nouvelles colonnes `turn-ending` et `Cooldown`), Siphoner encore à l'ancien format, Foreman et Contact **supprimés du classeur**.

---

## Ce que le Sheet change dans le contrat

Aujourd'hui le moteur décide **dans le code** ce que coûte une capacité : chaque `exec*` écrit son propre `u.ap-=1` ou `u.ap=0`, et le cooldown vient d'une table globale `COOLDOWN[id]`. Le Sheet, lui, donne ces trois valeurs **par perk**. Deux perks pourront donc partager une capacité avec des coûts différents — et c'est bien ce qu'il demande : `Fade` est à 0 PA avec un cooldown de 4, alors que la version codée coûte 1 PA et n'est utilisable qu'une fois par combat.

**Une inversion à avoir en tête :** dans le moteur, **toute attaque termine déjà le tour** (`att.ap=0`). Une capacité offensive marquée `Yes` ne demande donc aucun travail ; c'est `No (1AP)` qui est l'exception et qui coûte du code. Le `Buttstroke` de l'Enforcer — frapper à la crosse sans finir son tour — est à ce titre plus lourd à écrire que `Guaranteed hit`.

---

## Chantier 0 — la plomberie *(préalable à tout le reste)*

Rien de visible en jeu, mais tout le reste s'y branche.

- **0.1 — Coût, fin de tour et cooldown portés par le perk.** `applyPerks` recopie `cost` / `endsTurn` / `cd` sur l'unité, à côté de l'identifiant de capacité ; les `exec*` lisent ces valeurs au lieu de les écrire en dur. La table `COOLDOWN` reste le défaut pour les capacités d'ennemis, qui n'ont pas de perk.
- **0.2 — Les charges, qui ne sont pas des cooldowns.** `Smoker`, `Cusser` et `Lure` sont notés « 1 charge » : un stock par combat, pas un délai. Le décompte existe déjà pour les crackers (`u.crackers`) ; il faut le généraliser et l'afficher sur le bouton, comme `💣 ×2`.
- **0.3 — Bonus liés à une arme.** `Sharpen` ne vaut que pour l'épée, `Sharp` et `Better safe` que pour la grenade. Le moteur n'a qu'un `dmgBonus` global : il lui faut une portée d'application (`melee` / `ranged` / `cracker`).
- **0.4 — « N'a pas bougé ce tour-ci ».** Un drapeau posé au déplacement, remis à zéro en début de tour. Seul `Precision shot` s'en sert aujourd'hui, mais c'est la brique d'une famille entière (tir posé contre tir en mouvement).
- **0.5 — Attaquer sans finir son tour.** `doAttack` force `ap=0` hors réaction. Il faut pouvoir lui demander de débiter un coût et de rendre la main. C'est ce qui débloque `Buttstroke` et `Stab`.

---

## Chantier 1 — ce qui ne demande que des données

Une fois le chantier 0 posé, ces sept-là ne sont plus que des lignes de tableau.

| perk | classe | ce qu'il faut |
|---|---|---|
| Violence (+2 dégât) | Enforcer | rien, `mod` existe |
| Loaded (+1 grenade) | Sapper | rien, `mod:{crackers:1}` existe |
| Sharp (précision de jet) | Sapper | rien, `mod:{scatter:1}` existe |
| Better safe (+2 portée de grenade) | Sapper | 0.3 — portée de la grenade, pas du fusil |
| Sharpen (+2 dégât à l'épée) | Stinger | 0.3 |
| Discrete (flanc dos +2 / côté +1) | Stinger | un `mod` de flanc, lu par `flankOf` |
| Fade | Stinger | 0.1 — la capacité existe, seuls le coût et le cooldown changent |

---

## Chantier 2 — variantes de capacités existantes

Le verbe existe, il faut le décliner.

- **Smoker** *(Sapper)* — `smoke` existe, mais devient une **grenade** : lancée, limitée en charges, et profitant de `Sharp`. C'est le premier client du chantier 0.2.
- **Cusser** *(Sapper)* — un cracker à +2 dégâts et +2 de portée. Une variante de `resolveThrow`, pas une nouvelle mécanique.
- **Shadow Strike** *(Stinger)* — `shadowstrike` existe ; le Sheet lui ajoute un **prérequis** (`Stab`) et un coût de 2 PA. Le prérequis est nouveau : aucun perk n'en a jamais eu.
- **Remove wall** *(Sapper)* — `detruireMurs` détruit déjà des segments dans un rayon ; ici il faut viser **un** segment.

---

## Chantier 3 — mécaniques neuves

Rangées de la moins chère à la plus chère. Chacune est un incrément livrable seul.

1. **Guaranteed hit** *(Enforcer)* — forcer la visée à 100 %. Trivial une fois qu'un tir peut se voir imposer sa précision.
2. **Precision shot** *(Enforcer)* — +20 % si on n'a pas bougé. Découle de 0.4.
3. **Buttstroke** *(Enforcer)* — coup de crosse à 1 PA qui ne finit pas le tour. Découle de 0.5.
4. **Stab** *(Stinger)* — frappe préparée à 2 PA, +2 dégâts. Découle de 0.5, et c'est le prérequis de Shadow Strike.
5. **Run and gun** *(Enforcer)* — tirer après avoir couru. Aujourd'hui courir vide les PA et interdit de tirer : la capacité doit réserver l'attaque plutôt que d'ajouter des PA, sinon elle vaut un tour entier.
6. **Burst of fire** *(Enforcer)* — deux tirs à −10 %. Demande une résolution multi-coups et deux munitions.
7. **Explosive shells** *(Enforcer)* — un tir qui explose sur rayon 2. Croise le tir et le souffle (`pushBlast` existe).
8. **Impose fear** *(Stinger)* — zone, 50 % de panique, panique = étourdi 2 tours. `stunned` existe mais ne dure qu'un tour : il lui faut une durée.
9. **Raise wall** *(Sapper)* — bâtir jusqu'à deux segments de mur. Le moteur sait **détruire** du décor, jamais en ajouter : c'est le premier ajout de terrain en cours de combat (chemin, ligne de vue, IA, et la carte qui n'est plus celle de la mission).
10. **Arbalest** *(Sapper)* — débloque une troisième arme. Une unité n'a aujourd'hui que trois emplacements figés (`ranged` / `melee` / `cracker`) ; il faut un emplacement conditionnel et un sélecteur d'arme.
11. **Lure** *(Stinger)* — les ennemis se tournent vers un leurre. Facing forcé plus détournement de l'IA.
12. **Bait** *(Stinger)* — crée une copie du Stinger qui n'attaque pas. Le plus lourd : une unité joueur invoquée touche au ciblage ennemi, à la ligne de vue, aux conditions de victoire, au décompte de l'escouade et à la sauvegarde.

---

## Les stats aussi ont changé

Le Sheet ne réécrit pas que les arbres. À intégrer en même temps, sinon les perks se calibrent sur les mauvaises armes :

- **Enforcer** — fusil 4-5 dégâts (au lieu de 3-5), chargeur 4.
- **Sapper** — fusil 4-5, chargeur 4 ; grenade ramenée à **portée 5**, 4-5 dégâts, visée 100, **une seule charge sans recharge** ; arbalète 5-6, portée 9, chargeur 1.
- **Stinger** — épée à visée 90 et 4-5 dégâts, mais **flanc réduit** (dos +2 / côté +1 au lieu de +5 / +2) ; et surtout un **fusil léger** (70, 3-4, portée 7) alors que la classe n'avait que le contact. Ça déplace franchement le rôle : le nettoyeur devient jouable à distance.
- **Stinger** gagne aussi une capacité de classe hors arbre, **Faded** — commence le tour indétectable.

---

## À trancher avant de coder

- **Foreman et Contact n'ont plus d'onglet.** Classes abandonnées, ou onglets supprimés par accident ? Le moteur les connaît encore ; l'import les signale mais n'y touche pas.
- **« 1 charge »** — une utilisation par mission, ou par campagne ?
- **`Lure` dure « 5 secondes »** — dans un jeu au tour par tour, il faut un nombre de tours.
- **`Spray with gunfire` demande « 2 charges »** — deux munitions du chargeur, ou un stock à part ?
- **Le Stinger a deux lignes « arme 2 »** (épée et fusil léger). Un emplacement par arme, ou l'épée en arme 1 ?
- **Les pitchs de Sapper et Stinger sont vides** ; ceux du moteur seront écrasés à l'import.
