#!/usr/bin/env bash
# Build du port web + anti-cache : on tamponne les gros binaires (wasm/pck/js/worklet)
# avec une version dérivée du contenu, pour qu'un nouveau build = nouvelle URL.
# Le navigateur ne peut alors plus servir un ancien index.wasm/index.pck en cache.
set -euo pipefail
GODOT="${GODOT:-/tmp/godot}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
EXPORT="$ROOT/export"
DOCS="$(cd "$ROOT/.." && pwd)/docs/godot"

rm -rf "$EXPORT"; mkdir -p "$EXPORT"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$EXPORT/index.html" >/dev/null 2>&1 || \
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$EXPORT/index.html"

VER="$(md5sum "$EXPORT/index.pck" | cut -c1-10)"
echo "version build = $VER"

# renomme les fichiers dérivés du nom 'executable' + le moteur (index.js)
for ext in wasm pck js audio.worklet.js; do
  if [ -f "$EXPORT/index.$ext" ]; then
    mv "$EXPORT/index.$ext" "$EXPORT/index.$VER.$ext"
  fi
done

# patche le HTML : script du moteur + champ executable
sed -i "s|<script src=\"index.js\">|<script src=\"index.$VER.js\">|" "$EXPORT/index.html"
sed -i "s|\"executable\":\"index\"|\"executable\":\"index.$VER\"|" "$EXPORT/index.html"
sed -i "s|\"index.pck\":|\"index.$VER.pck\":|;s|\"index.wasm\":|\"index.$VER.wasm\":|" "$EXPORT/index.html"

# badge de version visible (diagnostic cache) : si tu ne le vois pas, c'est l'ancien build en cache
sed -i "s|</body>|<div id=\"buildtag\" style=\"position:fixed;top:4px;right:6px;z-index:9999;font:11px monospace;color:#7c7;background:#0008;padding:2px 6px;border-radius:4px;pointer-events:none\">build $VER</div>\n</body>|" "$EXPORT/index.html"

# synchro vers docs/ : purge les anciens binaires versionnés, garde campaign.json + icônes
mkdir -p "$DOCS"
find "$DOCS" -maxdepth 1 -type f \( -name 'index.*.wasm' -o -name 'index.*.pck' -o -name 'index.*.js' -o -name 'index.*.audio.worklet.js' -o -name 'index.html' \) -delete
cp "$EXPORT"/index.html "$DOCS"/
cp "$EXPORT"/index.*.wasm "$EXPORT"/index.*.pck "$EXPORT"/index.*.js "$DOCS"/
[ -f "$EXPORT/index.$VER.audio.worklet.js" ] && cp "$EXPORT/index.$VER.audio.worklet.js" "$DOCS"/
# icônes/splash (noms fixes, petits) si absents
for f in index.icon.png index.apple-touch-icon.png index.png; do
  [ -f "$EXPORT/$f" ] && cp "$EXPORT/$f" "$DOCS/" || true
done
echo "déployé dans $DOCS (version $VER)"
ls "$DOCS"
