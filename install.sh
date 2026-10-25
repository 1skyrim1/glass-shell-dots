#!/usr/bin/env bash
# Reproduces the Glass Shell setup on a fresh Arch install. Safe to re-run.
# Every sudo step is printed and needs a "y" first. Run it as your user from a TTY login (not with sudo):
# the user services, gsettings and chsh steps need your login session.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo"

if [[ $EUID -eq 0 ]]; then echo "Run install.sh as your user, not as root (it asks for sudo itself)."; exit 1; fi
if [[ -z ${XDG_RUNTIME_DIR:-} || ! -S ${XDG_RUNTIME_DIR}/bus ]]; then
  echo "No user session bus: log in on a TTY (or in the desktop) and run install.sh from there."; exit 1
fi

# Print a sudo command, ask, then run it. Answering no skips just that step.
sudo_ask() {
  printf '\n\e[1msudo %s\e[0m\n' "$*"
  # From the terminal, not stdin: inside the system/ loop below stdin is find's file list.
  read -rp "Run this? [y/N] " answer </dev/tty
  if [[ $answer == [yY] ]]; then sudo "$@"; else echo "skipped"; fi
}

# Package list without comments and blank lines.
pkgs() { sed -e 's/#.*//' -e '/^\s*$/d' "$1"; }

# 0. Mirror (optional, default no): Omarchy's stable mirror, a tested snapshot of Arch. This machine was
#    built from it because the regular mirrors gave 404s at the time. On a fresh install from the regular
#    mirrors, switching to an older snapshot first can mean a partial upgrade, so the default keeps them.
#    If you do switch, it happens first so every install below comes from the same snapshot.
mirrorlist=system/etc/pacman.d/mirrorlist
if ! cmp -s "$mirrorlist" /etc/pacman.d/mirrorlist; then
  echo; read -rp "Use Omarchy's snapshot mirror instead of your current mirrors? [y/N] " answer
  [[ $answer == [yY] ]] && sudo_ask install -Dm644 "$mirrorlist" /etc/pacman.d/mirrorlist
fi

# 1. Official packages
mapfile -t pacman_pkgs < <(pkgs packages/pacman.txt)
sudo_ask pacman -Syu --needed "${pacman_pkgs[@]}"

# 2. AUR helper (paru, built from source)
if ! command -v paru >/dev/null; then
  build="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$build/paru"
  # makepkg calls sudo pacman itself to install build deps and the package
  echo; read -rp "Build paru now (makepkg -si will ask for sudo)? [y/N] " answer
  if [[ $answer == [yY] ]]; then (cd "$build/paru" && makepkg -si); fi
  rm -rf "$build"
fi

# 3. AUR packages (paru shows the PKGBUILD for review, then asks for sudo)
mapfile -t aur_pkgs < <(pkgs packages/aur.txt)
if command -v paru >/dev/null; then
  echo; read -rp "Install AUR packages: ${aur_pkgs[*]}? [y/N] " answer
  if [[ $answer == [yY] ]]; then paru -S --needed "${aur_pkgs[@]}"; fi
fi

# 4. System files: system/<path> -> /<path> (scripts keep their exec bit): greetd + its Hyprland, the lock
#    screen's PAM file, faillock, NetworkManager's iwd backend, the screen-share picker. The mirror is step 0.
while IFS= read -r -d '' file <&3; do
  [[ $file == "$mirrorlist" ]] && continue
  target="/${file#system/}"
  mode=644; [[ -x $file ]] && mode=755
  cmp -s "$file" "$target" 2>/dev/null && [[ $(stat -c %a "$target") == "$mode" ]] || sudo_ask install -Dm$mode "$file" "$target"
done 3< <(find system -type f -print0)

# The greeter (Phase 9) can't read $HOME; matugen's hook copies the theme and wallpaper here on every
# wallpaper change (home/matugen/.config/matugen/config.toml).
[[ -d /var/lib/glass-shell/greeter ]] || sudo_ask install -d -o "$USER" -g "$USER" -m 755 /var/lib/glass-shell/greeter

# The greeter runs this repo's Quickshell config (greeter.qml) as the greeter user, who can't read $HOME:
# copy it next to the theme. No sudo needed (the folder is ours); re-run after changing the shell.
if [[ -w /var/lib/glass-shell/greeter ]]; then
  rm -rf /var/lib/glass-shell/greeter/shell
  cp -r home/quickshell/.config/quickshell /var/lib/glass-shell/greeter/shell
fi

# 5. Services
systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service
for unit in bluetooth power-profiles-daemon sshd; do
  systemctl is-enabled -q "$unit" || sudo_ask systemctl enable --now "$unit"
done

# 6. Network: NetworkManager with iwd as its Wi-Fi backend (system/etc/NetworkManager/conf.d). Last, so a drop
#    can't break the installs above. Works from either archinstall choice: systemd-networkd (+ iwd) is
#    replaced; an already running NetworkManager is restarted once iwd runs, to pick up the backend.
systemctl is-enabled -q iwd || sudo_ask systemctl enable --now iwd
if systemctl is-active -q NetworkManager; then
  # The backend file is newer than the running NetworkManager (/proc/<pid> dates from its start): restart it.
  nm_pid=$(systemctl show -p MainPID --value NetworkManager)
  if [[ /etc/NetworkManager/conf.d/wifi-backend.conf -nt /proc/$nm_pid ]]; then
    echo; echo "Restarting NetworkManager to switch Wi-Fi to iwd (the connection drops for a moment)."
    sudo_ask systemctl restart NetworkManager
  fi
else
  # networkd has several sockets (netlink, varlink, ...) that restart it; stop all of them.
  mapfile -t networkd_units < <(systemctl list-unit-files --no-legend 'systemd-networkd*.socket' | awk '{print $1}')
  sudo_ask systemctl disable --now systemd-networkd.service "${networkd_units[@]}"
  sudo_ask systemctl enable --now NetworkManager
  sleep 5
  if ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
    echo "network ok"
  else
    echo "No network yet. Try: nmtui. To revert:"
    echo "  sudo systemctl disable --now NetworkManager && sudo systemctl enable --now systemd-networkd"
  fi
fi

# 7. Dotfiles: every folder in home/ is a stow package (zsh's .zshrc and face's ~/.face land in ~).
#    --no-folding links files, not whole dirs, so ~/.config never becomes a link into the repo.
command -v stow >/dev/null || { echo "stow is missing (step 1 skipped?); stopping here."; exit 1; }
for pkg in home/*/; do
  stow -d home -t "$HOME" --no-folding --restow "$(basename "$pkg")"
done

# The user's picture for the greeter (the lock screen reads ~/.face itself; home/face has a generated one).
if [[ -w /var/lib/glass-shell/greeter && -f $HOME/.face ]]; then
  mkdir -p /var/lib/glass-shell/greeter/faces
  cp -fL "$HOME/.face" "/var/lib/glass-shell/greeter/faces/$USER"
fi

# Where the capture tool saves screenshots and recordings (Phase 8).
mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Videos/Captures"

# Screen sharing asks the shell's picker (home/hypr/.config/hypr/xdph.conf → /usr/local/bin/glass-share-picker);
# the portal reads its config at start.
systemctl --user try-restart xdg-desktop-portal-hyprland || true

# zsh as the login shell (asks for your password).
if [[ $(getent passwd "$USER" | cut -d: -f7) != /usr/bin/zsh ]] && command -v zsh >/dev/null; then
  echo; read -rp "Make zsh your login shell (chsh)? [y/N] " answer
  [[ $answer == [yY] ]] && chsh -s /usr/bin/zsh
fi

# The notification center's local khal calendar (home/khal).
mkdir -p "$HOME/.local/share/khal/calendars/personal"

# GTK: dark libadwaita everywhere, adw-gtk3 for GTK3 apps; the colours are matugen's gtk.css.
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark

# 8. First colour theme: matugen writes Quickshell's colors.json, Hyprland's border, kitty, GTK, Qt and the
#    greeter's copy (config.toml). Later the wallpaper switcher (Super+W) re-runs it.
if command -v matugen >/dev/null && [[ ! -f $HOME/.local/state/glass-shell/colors.json || ! -f $HOME/.config/kitty/colors.conf ]]; then
  matugen image "$HOME/.local/share/wallpapers/dusk.png" -m dark --prefer darkness --continue-on-error -q
fi

# 9. Log in with the Glass Shell greeter (greetd) instead of the text login on tty1.
#    If the greeter fails it falls back to a text login by itself; Ctrl+Alt+F2 always has a normal login.
#    To switch back: sudo systemctl disable greetd (getty@tty1 takes tty1 again after a reboot).
if ! systemctl is-enabled -q greetd; then
  echo; echo "greetd replaces the text login on tty1 from the next boot (fallback: Ctrl+Alt+F2)."
  sudo_ask systemctl enable greetd
fi

echo; echo "Done. Reboot to get the greeter, or start the desktop from a TTY with: start-hyprland"
