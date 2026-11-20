# Arch Config Installer

Script autonome pour reproduire ma configuration **Arch Linux + Hyprland** sur une autre machine.

La configuration repose sur [illogical-impulse (end-4)](https://github.com/end-4/dots-hyprland), avec mes réglages personnels, mon fond d'écran, mes couleurs Material You et mes paquets supplémentaires.

---

## Ce que fait le script

1. Vérifie qu'on est bien sur Arch Linux, en utilisateur normal.
2. Met à jour le système et installe les outils de base.
3. Installe `yay` si nécessaire.
4. Installe les paquets officiels et AUR listés dans `packages/`.
5. Installe **illogical-impulse** depuis un commit épinglé (Hyprland, Quickshell, thèmes, polices, etc.).
6. Sauvegarde les configurations existantes dans `~/arch-config-backup-*`.
7. Applique mes dotfiles : Hyprland, Quickshell, Kitty, Fish, Fuzzel, Kvantum, Matugen, thème KDE, fond d'écran…
8. Active les services : NetworkManager, Bluetooth, SDDM, fstrim, timesyncd, zram.
9. Ajoute l'utilisateur aux groupes `video`, `i2c`, `input`.

Le script est **idempotent** : on peut le relancer sans casser l'installation.

---

## Prérequis

- Une installation **Arch Linux déjà bootable** (base, noyau, réseau, sudo).
- Un utilisateur normal membre du groupe `wheel`.
- Une connexion Internet.
- Environ **10 Go d'espace libre**.
- Ne **pas** lancer le script en root ou avec `sudo`.

> Le script ne partitionne pas le disque, ne touche pas au bootloader, au Secure Boot ni aux pilotes NVIDIA. Il part d'un Arch déjà installé.

---

## Utilisation depuis GitHub

> Avant de publier, remplace `jean4steaks` et `hyprland-setup` par tes valeurs dans ce README et dans `install.template.sh`, puis relance `./build.sh`. Sans cela, les liens de téléchargement resteront des exemples.

### 1. Créer le dépôt

Le dépôt local est déjà initialisé avec un commit. Crée un dépôt **vide** sur GitHub (sans README), puis :

```bash
cd ~/Documents/arch_script
git remote add origin https://github.com/jean4steaks/hyprland-setup.git
git push -u origin main
```

> Avec GitHub CLI : `gh repo create jean4steaks/hyprland-setup --public --source=. --remote=origin --push`.

### 2. Sur la nouvelle machine

```bash
curl -fLO https://raw.githubusercontent.com/jean4steaks/hyprland-setup/main/install.sh
bash install.sh
```

Ou en clonant le dépôt :

```bash
git clone https://github.com/jean4steaks/hyprland-setup.git
cd hyprland-setup
bash install.sh
```

Le script demande une confirmation, puis le mot de passe sudo. Il peut ensuite tourner longtemps (compilation de Quickshell et MicroTeX).

> Ne lance **pas** `curl … | bash` : `install.sh` contient une archive intégrée et doit être exécuté depuis un fichier téléchargé.

### 3. Après l'installation

```bash
sudo reboot
```

À l'écran SDDM, choisir la session **Hyprland (uwsm-managed)**.

> Si cette session ne démarre pas, choisis la session **Hyprland** simple.

Raccourcis utiles :

| Raccourci | Action |
|---|---|
| `Super + /` | Liste des raccourcis |
| `Super + Return` | Terminal |
| `Ctrl + Super + T` | Changer de fond d'écran |
| `Super + Tab` | Vue d'ensemble des espaces de travail |

---

## Options

```bash
bash install.sh --help
```

| Option | Effet |
|---|---|
| `-y`, `--yes` | Aucune confirmation |
| `-n`, `--dry-run` | Affiche ce qui serait fait, sans modifier le système |
| `--no-sddm` | Installe SDDM mais ne l'active pas |
| `--skip-update` | Ne lance pas `pacman -Syu` |

---

## Contenu du dépôt

```
.
├── install.sh              # script autonome généré (à télécharger)
├── install.template.sh     # source lisible du script
├── build.sh                # régénère install.sh
├── sync.sh                 # recapture la config actuelle dans dotfiles/
├── LICENSE                 # GPL-3.0 (fichiers issus de dots-hyprland)
├── packages/
│   ├── pacman.txt          # paquets officiels supplémentaires
│   └── aur.txt             # paquets AUR supplémentaires
└── dotfiles/
    ├── .bashrc
    ├── .config/…           # Hyprland, Fish, Kitty, Fuzzel, Kvantum, Matugen…
    ├── .local/…            # couleurs générées, thème terminal, état Quickshell
    └── Pictures/Wallpapers/main.jpg
```

`install.sh` contient une archive compressée de `packages/` et `dotfiles/` : il est autonome et n'a pas besoin du reste du dépôt pour fonctionner.

---

## Mettre à jour le snapshot

Après avoir modifié la configuration sur la machine d'origine :

```bash
./sync.sh     # recopie la configuration actuelle dans dotfiles/
./build.sh    # régénère install.sh
```

Puis :

```bash
git add .
git commit -m "Mise à jour de la configuration"
git push
```

`sync.sh` ne copie **pas** les données sensibles ou volumineuses : profils navigateurs, Discord, Signal, trousseaux de clés, clés SSH/GPG, historique, token OpenCode, machines virtuelles, etc.

---

## Points d'attention

- **Écran** : `dotfiles/.config/hypr/monitors.lua` contient la disposition de mes deux écrans (`HDMI-A-1` et `DP-2`). Sur une autre machine, adapter ce fichier ou le supprimer si un seul écran est utilisé.
- **Carte graphique** : les pilotes Intel, AMD et Nouveau sont installés. Pour NVIDIA, installer séparément `nvidia`, `nvidia-utils` et `libva-nvidia-driver`.
- **Bootloader / Secure Boot** : non gérés par ce script.
- **Identifiants** : rien de secret n'est inclus. Les clés API, mots de passe, tokens et trousseaux restent sur la machine d'origine.
- **Personnalisation** : les fichiers propres à illogical-impulse viennent du commit épinglé `cb1c428`. Mes réglages et fichiers générés sont dans `dotfiles/` et écrasent ceux de l'installateur.

---

## Dépannage

Le journal complet est écrit dans :

```
~/.cache/arch-config-installer/install-<date>.log
```

En cas d'échec d'un paquet, relancer le script : les paquets déjà installés sont ignorés.

Pour vérifier le contenu sans rien installer :

```bash
bash install.sh --dry-run
```

---

## Licence

Une grande partie des fichiers de configuration provient de [dots-hyprland (end-4)](https://github.com/end-4/dots-hyprland), distribué sous **GPL-3.0**. Le fichier [LICENSE](LICENSE) est inclus dans ce dépôt.
