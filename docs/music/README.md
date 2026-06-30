# Musiques

Dépose tes fichiers audio ici, puis liste-les dans `manifest.json`.

## Dossiers

- `missions/` — pistes de combat. Une est tirée **au hasard à chaque mission**.
- `interludes/` — pistes des écrans de texte / choix de campagne. Tirée **au hasard** à chaque interlude.
- `geoscape/` — piste(s) de la carte stratégique. Mets-en **une** (ou plusieurs : une au hasard sera jouée en arrivant sur la carte).

## Comment ajouter une musique

1. Copie ton fichier dans le bon sous-dossier, p. ex. `missions/combat-1.ogg`.
2. Ajoute son chemin (relatif à `music/`) dans `manifest.json` :

```json
{
  "missions":   ["missions/combat-1.ogg", "missions/combat-2.ogg"],
  "interludes": ["interludes/calme.ogg"],
  "geoscape":   ["geoscape/theme.ogg"]
}
```

3. Si tu déploies sur GitHub Pages, copie aussi le dossier `music/` dans `docs/` (les deux sont synchronisés). Le `manifest.json` et les fichiers doivent exister sous `docs/music/`.

## Formats

- Préfère **`.ogg`** (léger, bien supporté) ou **`.mp3`**.
- Les pistes sont jouées **en boucle**, volume réglable, et peuvent être coupées via le bouton 🎵 / 🔇 (en bas à droite).

## Comportement

- Une liste vide = pas de musique pour ce contexte (la piste en cours, s'il y en a une, continue).
- La musique ne redémarre pas tant qu'on reste dans le même contexte ; elle change (et re-tire au hasard) en passant d'un contexte à l'autre (mission ↔ geoscape ↔ interlude).
- L'autoplay peut être bloqué par le navigateur tant que tu n'as pas cliqué une première fois — c'est normal, la musique démarre dès la première interaction.
