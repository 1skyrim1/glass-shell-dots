# Glass Shell

A keyboard-first Hyprland + Quickshell desktop for this laptop, built from scratch on a fresh Arch install.
This repo is new and separate from any older dotfiles.

## Source of truth
- `design/DESIGN.md` is the spec and wins over anything else.
- `design/screens/` shows how each surface must look (`-keys` = key hints visible); `design/motion/` shows animation
  frames; `design/source/` has the original HTML/CSS with exact values. Treat `design/` as read-only.
- Build in the phases from `design/PHASES.md`. Only do the phase you're asked for.

## Rules
- Repo layout and deployment: DESIGN.md §8 (stow packages under `home/`, system files under `system/`,
  `install.sh` + `packages/*.txt` kept up to date with every package and system change).
- Designs are drawn at 1600×900; scale pixel values to this laptop's logical resolution.
- Colours only from matugen roles (DESIGN.md §1.1). No hard-coded hex in QML except the fixed status colours.
- All glass goes through one GlassRect component; all durations and easings through one Motion singleton.
- Every surface gets an IpcHandler; Hyprland binds (`hyprland.lua` → `conf/binds.lua`) call `qs ipc call …`.
- Key hints are hidden and only appear while Alt is held.
- After visible changes: run the shell, take a screenshot with `grim`, open it, and compare it with the matching
  picture in `design/screens/`. Fix differences before saying a step is done.
- Explanations go as comments in the code. Keep it lightweight.
- Ask before installing packages, running sudo, or changing anything outside this repo.
