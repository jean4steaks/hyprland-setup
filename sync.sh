#!/usr/bin/env bash
# ============================================================
#  sync.sh — Recapture la configuration actuelle dans dotfiles/
#
#  À lancer sur la machine d'origine après avoir modifié
#  la configuration. Ensuite, lancer ./build.sh pour
#  régénérer install.sh.
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

II_COMMIT="cb1c428bf841dabccff1b126904047c28e89ba8c"
SRC="${HOME}"
DST="dotfiles"

copy_path() {
  local rel="$1"
  if [[ ! -e "$SRC/$rel" ]]; then
    echo "  - absent : $rel"
    return 0
  fi
  mkdir -p "$DST/$(dirname "$rel")"
  cp -a "$SRC/$rel" "$DST/$rel"
  echo "  + $rel"
}

echo "Nettoyage de $DST/..."
rm -rf "$DST"
mkdir -p "$DST"

echo "Copie des fichiers de configuration..."

# Shell
copy_path .bashrc
copy_path .bash_profile

# Fichiers simples de ~/.config
for f in \
  chrome-flags.conf \
  code-flags.conf \
  thorium-flags.conf \
  darklyrc \
  dolphinrc \
  konsolerc \
  kdeglobals \
  QtProject.conf \
  starship.toml \
  user-dirs.dirs \
  user-dirs.locale
do
  copy_path ".config/$f"
done

# Dossiers de ~/.config
for d in \
  fish \
  fontconfig \
  foot \
  fuzzel \
  gtk-3.0 \
  gtk-4.0 \
  hypr \
  kde-material-you-colors \
  kitty \
  Kvantum \
  matugen \
  mpv \
  cava \
  wlogout \
  xdg-desktop-portal \
  zshrc.d
do
  copy_path ".config/$d"
done

# Réglages personnels d'illogical-impulse
copy_path .config/illogical-impulse/config.json

# État généré par Quickshell (couleurs, thème terminal, fond d'écran)
copy_path .local/state/quickshell/user/generated

# Thèmes KDE générés par Material You
copy_path .local/share/color-schemes
copy_path .local/share/kde-material-you-colors
copy_path .local/share/org.kde.syntax-highlighting
copy_path .local/share/icons/illogical-impulse.svg

# Fond d'écran
copy_path Pictures/Wallpapers/main.jpg

# Nettoyage des fichiers indésirables
find "$DST" -type d -name .git -prune -exec rm -rf {} + 2>/dev/null || true
find "$DST" -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
find "$DST" -type f \( -name '*.pyc' -o -name '*.log' \) -delete 2>/dev/null || true
rm -f "$DST/.local/share/kde-material-you-colors/kde-material-you-colors.log"

# Certains scripts du thème de verrouillage ne sont pas toujours copiés
# par l'installateur. On les récupère depuis le commit épinglé.
HYPRLOCK="$DST/.config/hypr/hyprlock"
mkdir -p "$HYPRLOCK"
for f in check-capslock.sh status.sh; do
  if [[ ! -f "$HYPRLOCK/$f" ]]; then
    if curl -fsSL --max-time 30 \
      "https://raw.githubusercontent.com/end-4/dots-hyprland/$II_COMMIT/dots/.config/hypr/hyprlock/$f" \
      -o "$HYPRLOCK/$f"
    then
      chmod +x "$HYPRLOCK/$f"
      echo "  + hyprlock/$f (depuis GitHub)"
    else
      echo "  ! impossible de récupérer hyprlock/$f"
    fi
  fi
done

echo
echo "Snapshot prêt : $DST ($(du -sh "$DST" | cut -f1))"
echo "Lance maintenant : ./build.sh"
