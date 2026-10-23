# Glass Shell

A keyboard-first Hyprland + Quickshell desktop (Liquid Glass look), built from scratch on a fresh Arch install.

- `design/` — the complete design handoff: `DESIGN.md` (spec), `PHASES.md` (build order + prompts),
  `screens/`, `motion/`, `source/`
- `CLAUDE.md` — rules for Claude Code

## Start on a fresh Arch install

1. Install Arch (e.g. `archinstall`): **minimal** profile (no desktop), NetworkManager, PipeWire, a user with sudo.
2. Reboot, log in on the TTY, connect to Wi-Fi with `nmtui`.
3. Base tools and Claude Code:
   ```sh
   sudo pacman -S --needed git curl unzip base-devel
   curl -fsSL https://claude.ai/install.sh | bash
   ```
   Log out and back in (or open a new TTY) so `claude` is on your PATH, then check with `claude --version`.
4. Put this folder at `~/glass-shell` (clone it from your private GitHub repo, or unzip it from a USB stick).
5. Make it a repo:
   ```sh
   cd ~/glass-shell
   git init && git add -A && git commit -m "Design handoff"
   ```
6. `claude`, sign in (on a TTY it shows a link; open it on your phone or another computer and paste the code back),
   then follow `design/PHASES.md`, starting with Phase 0.
