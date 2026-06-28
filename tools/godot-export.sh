#!/usr/bin/env bash
# Exporte le port Godot en web (mono-thread = compatible GitHub Pages) vers docs/godot/.
# Usage : GODOT=/chemin/godot bash tools/godot-export.sh   (défaut : godot dans le PATH)
set -e
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path godot-port --export-release "Web" godot-port/export/index.html
mkdir -p docs/godot && cp -f godot-port/export/index.* docs/godot/ && rm -f docs/godot/*.import && touch docs/.nojekyll
echo "Export web -> docs/godot/ (activer GitHub Pages sur /docs pour jouer à <pages-url>/godot/)"
