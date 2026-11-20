#!/usr/bin/env bash
# ============================================================
#  Installation automatique de la configuration Arch Linux
#  Hyprland + illogical-impulse (end-4) + dotfiles personnels
#
#  Utilisation :
#    curl -fLO https://raw.githubusercontent.com/jean4steaks/hyprland-setup/main/install.sh
#    bash install.sh
#
#  Ne pas faire "curl ... | bash" : le script contient une archive
#  intégrée et doit être exécuté depuis le fichier téléchargé.
#
#  Ce script doit être lancé en utilisateur normal, pas en root.
# ============================================================

set -Eeuo pipefail

# ---------- Réglages ----------
II_REPO="https://github.com/end-4/dots-hyprland.git"
II_COMMIT="cb1c428bf841dabccff1b126904047c28e89ba8c"
OLD_HOME="/home/j1s"
WORKDIR="${XDG_CACHE_HOME:-$HOME/.cache}/arch-config-installer"
PAYLOAD_MARKER="__ARCH_CONFIG_PAYLOAD_BELOW__"
ASSUME_YES=0
DRY_RUN=0
ENABLE_SDDM=1
SKIP_UPDATE=0
LOG_FILE=""

# ---------- Couleurs ----------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_BOLD=$'\033[1m'
else
  C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""
fi

log()  { printf '%s[%s]%s %s\n' "$C_BLUE" "$(date +%H:%M:%S)" "$C_RESET" "$*"; }
ok()   { printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[ATTENTION]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf '%s[ERREUR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
  cat <<'EOF'
Installation de la configuration Arch Linux (Hyprland + illogical-impulse)

Usage:
  bash install.sh [options]

Options:
  -y, --yes          Ne pas demander de confirmation
  -n, --dry-run      Afficher ce qui serait fait, sans rien modifier
      --no-sddm      Ne pas activer SDDM
      --skip-update  Ne pas lancer pacman -Syu
  -h, --help         Afficher cette aide

Le script doit être exécuté en tant qu'utilisateur normal (pas root).
Il est prévu pour une installation Arch Linux fraîche, déjà bootable.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      -y|--yes) ASSUME_YES=1 ;;
      -n|--dry-run) DRY_RUN=1 ;;
      --no-sddm) ENABLE_SDDM=0 ;;
      --skip-update) SKIP_UPDATE=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "Option inconnue: $1 (voir --help)" ;;
    esac
    shift
  done
}

check_system() {
  [[ -f /etc/arch-release ]] || die "Ce script est prévu pour Arch Linux."
  [[ $EUID -ne 0 ]] || die "Ne lance pas ce script avec sudo/root. Lance-le en tant qu'utilisateur normal."
  command -v pacman >/dev/null || die "pacman est introuvable."
  command -v sudo >/dev/null || die "sudo est introuvable. En root: pacman -S sudo, puis ajoute ton utilisateur au groupe wheel."

  local user
  user=$(id -un)
  if ! id -nG "$user" | grep -qw wheel; then
    warn "L'utilisateur $user n'est pas dans le groupe wheel. sudo risque de refuser."
  fi

  if command -v curl >/dev/null; then
    curl -fsI --max-time 10 https://archlinux.org >/dev/null 2>&1 || warn "Pas d'accès à archlinux.org. Vérifie la connexion."
  fi

  local free_gb
  free_gb=$(df -Pk "$HOME" | awk 'NR==2 { print int($4 / 1024 / 1024) }')
  if [[ -n "$free_gb" ]] && (( free_gb < 10 )); then
    warn "Il reste seulement ${free_gb} Go libres dans $HOME (10 Go recommandés)."
  fi
}

init_log() {
  mkdir -p "$WORKDIR"
  LOG_FILE="$WORKDIR/install-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  log "Journal: $LOG_FILE"
}

sudo_init() {
  log "Demande des droits sudo..."
  sudo -v || die "Impossible d'obtenir sudo."
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null || true; sleep 60; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

extract_payload() {
  [[ -f "$0" ]] || die "Le script doit être exécuté depuis un fichier. Télécharge-le puis lance: bash install.sh"
  local line
  line=$(awk -v m="$PAYLOAD_MARKER" '$0 == m { print NR + 1; exit }' "$0")
  [[ -n "$line" ]] || die "Payload introuvable dans le script."
  PAYLOAD_DIR="$WORKDIR/payload"
  rm -rf "$PAYLOAD_DIR"
  mkdir -p "$PAYLOAD_DIR"
  log "Extraction de la configuration..."
  tail -n +"$line" "$0" | tar -xzf - -C "$PAYLOAD_DIR"
  [[ -d "$PAYLOAD_DIR/dotfiles" && -d "$PAYLOAD_DIR/packages" ]] || die "Payload invalide."
}

read_pkg_list() {
  local file="$1"
  awk 'NF && $1 !~ /^#/ { print $1 }' "$file"
}

confirm() {
  (( ASSUME_YES )) && return 0
  echo
  printf '%sCette installation va :%s\n' "$C_BOLD" "$C_RESET"
  echo "  - mettre à jour le système et installer les paquets"
  echo "  - installer illogical-impulse (compilation de Quickshell/MicroTeX)"
  echo "  - sauvegarder puis remplacer les fichiers de config actuels"
  echo "  - activer les services (NetworkManager, Bluetooth, SDDM, ...)"
  echo
  echo "Durée estimée : 30 à 90 minutes. Espace disque : ~10 Go."
  echo
  if ! read -r -p "Continuer ? [y/N] " ans; then
    echo "Entrée fermée, installation annulée."
    exit 1
  fi
  [[ "$ans" =~ ^[yY]$ ]] || { echo "Annulé."; exit 1; }
}

install_bootstrap() {
  log "Installation des outils de base..."
  sudo pacman -S --needed --noconfirm base-devel git curl rsync tar xz
  ok "Outils de base installés."
}

install_yay() {
  if command -v yay >/dev/null; then
    ok "yay déjà installé."
    return
  fi
  log "Installation de yay-bin..."
  local dir="$WORKDIR/yay-build"
  rm -rf "$dir"
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$dir"
  ( cd "$dir" && makepkg -si --noconfirm )
  rm -rf "$dir"
  command -v yay >/dev/null || die "yay n'a pas pu être installé."
  ok "yay installé."
}

install_pacman_packages() {
  local -a pkgs=()
  mapfile -t pkgs < <(read_pkg_list "$PAYLOAD_DIR/packages/pacman.txt")
  if ((${#pkgs[@]})); then
    log "Installation des paquets officiels (${#pkgs[@]})..."
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
    ok "Paquets officiels installés."
  fi
}

install_aur_packages() {
  local -a pkgs=()
  mapfile -t pkgs < <(read_pkg_list "$PAYLOAD_DIR/packages/aur.txt")
  if ((${#pkgs[@]})); then
    log "Installation des paquets AUR (${#pkgs[@]})..."
    yay -S --needed --noconfirm --sudoloop "${pkgs[@]}"
    ok "Paquets AUR installés."
  fi
}

install_ii() {
  local dir="$WORKDIR/dots-hyprland"
  local ii_status=0
  log "Récupération de illogical-impulse (commit ${II_COMMIT:0:8})..."
  rm -rf "$dir"
  git clone --filter=blob:none "$II_REPO" "$dir"
  git -C "$dir" checkout --force "$II_COMMIT"
  git -C "$dir" submodule update --init --recursive
  log "Installation de illogical-impulse (cela peut prendre du temps)..."
  ( cd "$dir" && ./setup install -f --ignore-outdate --skip-sysupdate ) || ii_status=$?
  if (( ii_status != 0 )); then
    warn "L'installateur illogical-impulse a retourné le code $ii_status. Vérification de l'installation..."
  fi
  command -v hyprland >/dev/null || die "Hyprland n'a pas été installé. Consulte le journal: $LOG_FILE"
  command -v qs >/dev/null || die "Quickshell n'a pas été installé. Consulte le journal: $LOG_FILE"
  [[ -f "$HOME/.config/quickshell/ii/shell.qml" ]] || die "La configuration Quickshell est absente. Consulte le journal: $LOG_FILE"
  [[ -x "$HOME/.local/state/quickshell/.venv/bin/python" ]] || warn "Le venv Python de Quickshell est absent."
  ok "illogical-impulse installé."
}

backup_current() {
  local backup="$HOME/arch-config-backup-$(date +%Y%m%d-%H%M%S)"
  log "Sauvegarde des configurations actuelles dans $backup..."
  mkdir -p "$backup"
  if [[ -d "$HOME/.config" ]]; then
    rsync -a \
      --exclude='mozilla/' --exclude='discord/' --exclude='Signal AppImage/' \
      --exclude='opencode/' --exclude='PhoneBox/' \
      "$HOME/.config/" "$backup/.config/"
  fi
  if [[ -d "$HOME/.local/state/quickshell" ]]; then
    mkdir -p "$backup/.local/state/quickshell"
    rsync -a --exclude='.venv/' "$HOME/.local/state/quickshell/" "$backup/.local/state/quickshell/"
  fi
  local p
  for p in \
    .local/share/color-schemes \
    .local/share/kde-material-you-colors \
    .local/share/org.kde.syntax-highlighting \
    .local/share/icons/illogical-impulse.svg \
    Pictures/Wallpapers/main.jpg
  do
    if [[ -e "$HOME/$p" ]]; then
      mkdir -p "$backup/$(dirname "$p")"
      cp -a "$HOME/$p" "$backup/$p"
    fi
  done
  ok "Sauvegarde terminée: $backup"
}

fix_paths() {
  log "Adaptation des chemins à $HOME..."
  local files=(
    "$HOME/.bashrc"
    "$HOME/.config/fish/fish_variables"
    "$HOME/.config/illogical-impulse/config.json"
    "$HOME/.config/hypr/hyprlock/colors.conf"
    "$HOME/.config/QtProject.conf"
    "$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt"
  )
  local f
  for f in "${files[@]}"; do
    [[ -f "$f" ]] && sed -i "s|$OLD_HOME|$HOME|g" "$f"
  done
  grep -rIl --exclude-dir=.git "$OLD_HOME" \
    "$HOME/.config/hypr" "$HOME/.config/illogical-impulse" \
    "$HOME/.local/state/quickshell/user" 2>/dev/null |
  while IFS= read -r f; do sed -i "s|$OLD_HOME|$HOME|g" "$f"; done || true
  ok "Chemins adaptés."
}

apply_dotfiles() {
  backup_current
  log "Application des dotfiles..."
  cp -a "$PAYLOAD_DIR/dotfiles/." "$HOME/"
  fix_paths
  fc-cache -f >/dev/null 2>&1 || true
  ok "Dotfiles appliqués."
}

enable_services() {
  log "Activation des services..."
  sudo systemctl enable --now NetworkManager 2>/dev/null || warn "NetworkManager n'a pas pu être activé."
  sudo systemctl enable --now bluetooth 2>/dev/null || warn "Bluetooth n'a pas pu être activé."
  sudo systemctl enable fstrim.timer 2>/dev/null || true
  sudo systemctl enable systemd-timesyncd 2>/dev/null || true

  if (( ENABLE_SDDM )); then
    if systemctl is-enabled display-manager.service >/dev/null 2>&1; then
      warn "Un gestionnaire de connexion est déjà activé; SDDM ne sera pas activé."
    else
      sudo systemctl enable sddm 2>/dev/null || warn "SDDM n'a pas pu être activé."
    fi
  fi

  if [[ ! -f /etc/systemd/zram-generator.conf ]]; then
    printf '[zram0]\ncompression-algorithm = zstd\n' | sudo tee /etc/systemd/zram-generator.conf >/dev/null
    ok "Configuration zram créée."
  fi

  sudo groupadd -f i2c 2>/dev/null || true
  sudo usermod -aG video,i2c,input "$(id -un)" 2>/dev/null || warn "Impossible d'ajouter l'utilisateur aux groupes video/i2c/input."
  ok "Services activés."
}

print_summary() {
  echo
  printf '%s============================================================%s\n' "$C_GREEN" "$C_RESET"
  printf '%s Installation terminée !%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
  printf '%s============================================================%s\n' "$C_GREEN" "$C_RESET"
  echo
  echo "1. Redémarre la machine :"
  echo "     sudo reboot"
  echo
  echo "2. À l'écran SDDM, choisis la session :"
  echo "     Hyprland (uwsm-managed)"
  echo
  echo "3. Raccourcis utiles :"
  echo "     Super + /          liste des raccourcis"
  echo "     Super + Return     terminal"
  echo "     Ctrl + Super + T   changer de fond d'écran"
  echo
  echo "Journal d'installation : $LOG_FILE"
  echo "Sauvegarde des anciennes configs : ~/arch-config-backup-*"
  echo
  echo "En cas d'échec, consulte le journal puis relance le script : il est idempotent."
}

main() {
  parse_args "$@"
  check_system
  init_log
  extract_payload
  if (( DRY_RUN )); then
    echo "Mode simulation :"
    echo "  Paquets officiels : $(read_pkg_list "$PAYLOAD_DIR/packages/pacman.txt" | wc -l)"
    echo "  Paquets AUR      : $(read_pkg_list "$PAYLOAD_DIR/packages/aur.txt" | wc -l)"
    echo "  Dotfiles         : $(find "$PAYLOAD_DIR/dotfiles" -type f | wc -l) fichiers"
    echo "  Commit II        : $II_COMMIT"
    exit 0
  fi
  confirm
  sudo_init
  if (( SKIP_UPDATE )); then
    warn "Mise à jour système ignorée (--skip-update)."
  else
    log "Mise à jour du système..."
    sudo pacman -Syu --noconfirm
  fi
  install_bootstrap
  install_yay
  install_pacman_packages
  install_aur_packages
  install_ii
  apply_dotfiles
  enable_services
  print_summary
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
