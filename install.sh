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

# 4. System files: system/<path> -> /<path>
while IFS= read -r -d '' file; do
  target="/${file#system/}"
  cmp -s "$file" "$target" 2>/dev/null || sudo_ask install -Dm644 "$file" "$target"
done < <(find system -type f -print0)

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

# 8. First colour theme (matugen -> ~/.local/state/glass-shell/colors.json, read by Quickshell).
if [[ ! -f $HOME/.local/state/glass-shell/colors.json ]]; then
  matugen image "$HOME/.local/share/wallpapers/dusk.png" -m dark --prefer darkness -q
fi

echo; echo "Done. Start the desktop with: Hyprland"
