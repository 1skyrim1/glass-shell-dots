#!/usr/bin/env bash
# Reproduces the Glass Shell setup on a fresh Arch install. Safe to re-run.
# Every sudo step is printed and needs a "y" first.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo"

# Print a sudo command, ask, then run it. Answering no skips just that step.
sudo_ask() {
  printf '\n\e[1msudo %s\e[0m\n' "$*"
  read -rp "Run this? [y/N] " answer
  if [[ $answer == [yY] ]]; then sudo "$@"; else echo "skipped"; fi
}

# Package list without comments and blank lines.
pkgs() { sed -e 's/#.*//' -e '/^\s*$/d' "$1"; }

# 0. Mirror: Omarchy's stable mirror (a tested snapshot of Arch). First, so every install below comes
#    from it; mixing it with packages from a newer regular mirror makes installs fail with 404s.
mirrorlist=system/etc/pacman.d/mirrorlist
cmp -s "$mirrorlist" /etc/pacman.d/mirrorlist || sudo_ask install -Dm644 "$mirrorlist" /etc/pacman.d/mirrorlist

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
#    screen's PAM file, faillock, NetworkManager, the mirror.
while IFS= read -r -d '' file; do
  target="/${file#system/}"
  mode=644; [[ -x $file ]] && mode=755
  cmp -s "$file" "$target" 2>/dev/null && [[ $(stat -c %a "$target") == "$mode" ]] || sudo_ask install -Dm$mode "$file" "$target"
done < <(find system -type f -print0)

# The greeter (Phase 9) can't read $HOME; matugen's hook copies the theme and wallpaper here on every
# wallpaper change (home/matugen/.config/matugen/config.toml).
[[ -d /var/lib/glass-shell/greeter ]] || sudo_ask install -d -o "$USER" -g "$USER" -m 755 /var/lib/glass-shell/greeter

# The greeter runs this repo's Quickshell config (greeter.qml) as the greeter user, who can't read $HOME:
# copy it next to the theme. No sudo needed (the folder is ours); re-run after changing the shell.
if [[ -w /var/lib/glass-shell/greeter ]]; then
  rm -rf /var/lib/glass-shell/greeter/shell
  cp -r home/quickshell/.config/quickshell /var/lib/glass-shell/greeter/shell
  # The user's picture for the greeter (the lock screen reads ~/.face itself).
  mkdir -p /var/lib/glass-shell/greeter/faces
  if [[ -f $HOME/.face ]]; then cp -f "$HOME/.face" "/var/lib/glass-shell/greeter/faces/$USER"; fi
fi

# 5. Services
systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service
for unit in bluetooth power-profiles-daemon; do
  systemctl is-enabled -q "$unit" || sudo_ask systemctl enable --now "$unit"
done

# 6. Network: NetworkManager (iwd backend) replaces systemd-networkd. Last, so a drop
#    can't break the installs above. iwd and systemd-resolved stay as they are.
if ! systemctl is-active -q NetworkManager; then
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

# 7. Dotfiles: every folder in home/ is a stow package.
#    --no-folding links files, not whole dirs, so ~/.config never becomes a link into the repo.
for pkg in home/*/; do
  stow -d home -t "$HOME" --no-folding --restow "$(basename "$pkg")"
done

# Where the capture tool saves screenshots and recordings (Phase 8).
mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Videos/Captures"

# Screen sharing asks the shell's picker (home/hypr/.config/hypr/xdph.conf); the portal reads it at start.
systemctl --user try-restart xdg-desktop-portal-hyprland

# The notification center's local khal calendar (home/khal).
mkdir -p "$HOME/.local/share/khal/calendars/personal"

# GTK: dark libadwaita everywhere, adw-gtk3 for GTK3 apps; the colours are matugen's gtk.css.
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark

# 8. First colour theme: matugen writes Quickshell's colors.json, Hyprland's border, kitty, GTK, Qt and the
#    greeter's copy (config.toml). Later the wallpaper switcher (Super+W) re-runs it.
if [[ ! -f $HOME/.local/state/glass-shell/colors.json || ! -f $HOME/.config/kitty/colors.conf ]]; then
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
