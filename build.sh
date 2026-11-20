#!/usr/bin/env bash
# ============================================================
#  build.sh — Génère install.sh à partir de install.template.sh
#             et du contenu de packages/ + dotfiles/
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

OUT="install.sh"
TMP=".build"

if [[ ! -d dotfiles || ! -d packages ]]; then
  echo "Erreur : dotfiles/ ou packages/ manquant. Lance ./sync.sh d'abord." >&2
  exit 1
fi

bash -n install.template.sh || { echo "Erreur : install.template.sh contient une erreur de syntaxe." >&2; exit 1; }

rm -rf "$TMP"
mkdir -p "$TMP"

echo "Création de l'archive de configuration..."
tar -czf "$TMP/payload.tar.gz" packages dotfiles
tar -tzf "$TMP/payload.tar.gz" >/dev/null || { echo "Erreur : archive invalide." >&2; exit 1; }

echo "Génération de $OUT..."
cp install.template.sh "$OUT"
printf '\nexit 0\n__ARCH_CONFIG_PAYLOAD_BELOW__\n' >> "$OUT"
cat "$TMP/payload.tar.gz" >> "$OUT"
chmod +x "$OUT"

# Vérifie que le marqueur est bien présent et que le payload se relit.
marker_line=$(awk '/^__ARCH_CONFIG_PAYLOAD_BELOW__$/ { print NR; exit }' "$OUT")
[[ -n "$marker_line" ]] || { echo "Erreur : marqueur absent de $OUT." >&2; exit 1; }
mkdir -p "$TMP/verify"
tail -n +"$((marker_line + 1))" "$OUT" | tar -xzf - -C "$TMP/verify"
[[ -f "$TMP/verify/packages/pacman.txt" && -f "$TMP/verify/dotfiles/.bashrc" ]] \
  || { echo "Erreur : payload illisible après assemblage." >&2; exit 1; }
rm -rf "$TMP/verify"

echo "Terminé : $OUT ($(du -h "$OUT" | cut -f1))"
echo "Payload : $(du -h "$TMP/payload.tar.gz" | cut -f1)"
