# POC — terrain mixte hexagones / carrés / pentagones

Ouvre `poc/mixed-grid.html` dans un navigateur (ou via GitHub Pages : `…/poc/mixed-grid.html`).

- **Clic gauche** : sélectionner une cellule → portée de déplacement (Dijkstra pondéré).
- **Clic droit** : poser / retirer un obstacle.
- **Survol** : distance (en pas de graphe) + ligne de vue depuis la sélection.
- Cases : carrés (gauche), **pentagones** (bande de transition), hexagones (droite). Curseur *arêtes du graphe* pour voir l'adjacence.

## Pourquoi des pentagones ?

Le réseau carré (pas entier) et le réseau hexagonal (pas en √3) **ne peuvent pas partager d'arêtes** : √3 est irrationnel. Les **pentagones irréguliers** absorbent ce décalage — ils ont une arête verticale (partagée avec un carré) et des arêtes obliques (côté hexagones). C'est le rôle naturel d'une tuile de transition (il n'existe aucun pavage régulier mêlant pentagones réguliers + carrés + hexagones).

## Changement d'architecture clé

On passe d'une **grille à coordonnées** (offset/cube) à un **graphe de cellules polygonales** : chaque cellule porte sa géométrie (`poly`, `cx/cy`) et sa **liste de voisins** déduite des arêtes partagées (proximité des milieux d'arêtes). Le graphe construit ici est entièrement connexe (les pentagones relient les deux blocs).

## Impacts sur le moteur du jeu (`index.html`)

| Sous-système | Aujourd'hui (hex) | Avec un graphe de cellules |
|---|---|---|
| Coordonnées | `key(c,r)`, `offsetToCube`, `NEI[r&1]` | id de cellule + `nb[]` (voisins explicites) |
| Distance | `cubeDist` (formule) | BFS / Dijkstra sur le graphe |
| Déplacement | `computeReach` + `moveCost` (Dijkstra hex) | Dijkstra générique, **coût par arête** (cellules hétérogènes) |
| Champ de vision | shadowcasting **angulaire** sur 6 secteurs | **raycast géométrique** centre→centre (plus coûteux) |
| Couvert / flanc | 6 directions fixes (`coverInDir`, `flankOf`) | par **arête** (normale d'arête) + angle réel |
| Rendu | `tileCenter` / `fillHex` / hex pointe-en-haut | tracé de **polygones quelconques** ; murets = arêtes |
| Portées (tir/cracker/bruit) | en « cases » | en **distance euclidienne** ou pas de graphe (cases de tailles variées) |
| Format mission / éditeur | `elev`/`rocks`/`walls` en `[col][row]` | liste de cellules + arêtes ; pinceau & export JSON revus |

**Reste stable** si on s'appuie sur des abstractions `neighbors(cell)` / `dist(a,b)` : tours & PA, triggers, IA (choix de cible/score), persistance PV/crackers, dialogues. La bascule est donc surtout une **couche « plateau »** à réécrire ; la logique de jeu au-dessus bouge peu.

## Étape déjà amorcée dans le jeu

Le jeu (`index.html`) expose désormais une **couche `Board`** (objet near `hexDistUnits`) qui regroupe les
primitives de plateau : `Board.dist`, `Board.neighbors`, `Board.center`, `Board.key`, `Board.inBounds`,
`Board.forEach`. Toute la logique de jeu (portées, IA, adjacence potion/vigilance) appelle maintenant
`Board.dist` au lieu de la maths hex directe. Pour un plateau mixte, on réimplémente `Board` (en graphe de
cellules) + le FoV + le rendu ; le reste de la logique ne bouge pas. (`Board` est aussi exposé via `MGF.Board`
et dans le harness de test.)

## Verdict

Faisable, mais ce n'est pas un réglage : c'est remplacer le cœur géométrique (coordonnées → graphe) et réécrire FoV + rendu + format de carte. Le présent POC valide la voie : un graphe mixte connexe, déplacement et ligne de vue fonctionnels sur des cellules de formes différentes.
