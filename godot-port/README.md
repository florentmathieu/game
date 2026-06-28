# Cœur maillage — port Godot (3D, vue XCOM)

Port **séparé** du jeu (le `index.html` d'origine reste la version de référence).
Seule différence de design voulue : **rendu 3D** pour **voir l'élévation**, caméra
à la XCOM ; les personnages restent des **sphères**.

## Tester
- **Éditeur** : ouvrir `godot-port/` dans Godot 4.3, F5.
- **Web** : export HTML5 **mono-thread** (compatible GitHub Pages) → dossier `export/`.

## Structure
- `rules/` — moteur de règles, sans nœud (testable headless). `Rng.gd` réplique le
  PRNG du jeu JS à l'identique (génération procédurale reproductible).
- `scripts/` — vue 3D (scène, caméra, rendu des tuiles, unités).
- `tests/` — tests headless (`godot --headless --script res://tests/...`),
  croisés avec l'oracle Node du dépôt (`tools/`).

État : en construction (tranche verticale combat 3D d'abord).
