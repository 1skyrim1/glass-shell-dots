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

## Install the desktop (Phase 0)

```sh
cd ~/glass-shell
./install.sh   # packages (pacman + paru/AUR), system/ files, services, stow home/*, first matugen theme;
               # asks before every sudo step
Hyprland       # start it from the TTY; Super+Return = kitty; Quickshell (qs) starts with it
```

## Glass Shell basics (Phase 1)

- Settings: `home/quickshell/.config/quickshell/config.json` (glass strength, reduced motion, idle times), reloads live.
- Colours: chosen with the wallpaper switcher (Phase 7, `Super+W`).
- IPC: `qs ipc show` lists every target; `qs ipc call test toggle` shows the glass test surface,
  `qs ipc call glass set heavy` switches glass strength (QML and Hyprland blur together).

## The bar (Phase 2)

- Five pills (`surfaces/Bar.qml`, `surfaces/bar/`): workspaces + focused window, media (while playing), clock,
  status, bell. Recording and Hyprland submaps split off the clock; volume / brightness / layout OSDs drop out of it.
- All binds from DESIGN.md §6 are in `hyprland.lua`; ones whose surface comes later call a `qs ipc` target
  that only logs a TODO for now. `Super+R` = resize mode (H J K L, Esc).
- Try states by hand: `qs ipc call capture record` (red pill), `qs ipc call notifications dnd`,
  `qs ipc call gamemode toggle`, `qs ipc call keepawake toggle`, `qs ipc call battery simulate 12`
  (`-- -1` for the real battery), `qs ipc call volume up`, `qs ipc call brightness down`.

## Wallpaper and theme (Phase 7)

- `Super+W`: ←/→ (H/L) preview a wallpaper's palette live (pills, panels, window border, kitty), Enter applies it
  (ripple from the thumbnail), R random, Esc reverts. Click a thumbnail to preview, click again to apply.
- Wallpapers: `home/wallpapers/.local/share/wallpapers/` (png / jpg / webp, listed by file name; restow after
  adding one). Each wallpaper is one theme.
- Applying runs `matugen image <wallpaper> -m dark --prefer darkness` with `home/matugen/.config/matugen/config.toml`:
  Quickshell `~/.local/state/glass-shell/colors.json`, Hyprland border `hypr-colors.lua`, kitty `~/.config/kitty/colors.conf`,
  GTK `~/.config/gtk-{3,4}.0/gtk.css`, Qt `~/.config/qt6ct/colors/matugen.conf`, greeter `/var/lib/glass-shell/greeter/`.
  `preview.toml` is the kitty-only run used while browsing.
- IPC: `qs ipc call wallpaper list`, `… set fjord`, `… next` / `prev` / `random` / `apply`.

## Session: lock, greeter, polkit, power, idle (Phase 9)

- **Lock** `Super+L` (or `loginctl lock-session`; it also locks before every suspend). Alt+P = power options
  (Reboot / Power off arm first: press the key again within 3 s). 3 wrong passwords → 10 s wait.
  `qs ipc call lock preview` shows the lock screen without locking (fake auth: `wrong` fails, anything else
  unlocks, Esc leaves).
- **Power menu** `Super+Esc`: L lock · S suspend · O log out · R reboot · P power off (R / P: press twice).
  Log out / reboot / power off close every window first and name the app that's holding things up (e.g. kitty
  asking "really close?"): Enter closes it anyway, Esc cancels so you can answer it yourself.
  `qs ipc call session preview poweroff` shows that screen without doing anything.
- **Idle** (times in `config.json` → `idle`): 10 s dim + countdown in the clock pill → lock at 5 min → screen off at
  7 min → suspend at 15 min on battery. Skipped while a video plays or Keep awake is on.
  `qs ipc call idle test 20` squeezes it to 20 s (with the preview lock), `… test 0` goes back.
- **Polkit**: Quickshell is the polkit agent (hyprpolkitagent isn't needed). 3 wrong passwords cancel the request
  and leave a notification. faillock (`system/etc/security/faillock.conf`): 3 failures → 30 s.
- **Battery**: at 5 % a red toast that ignores DND; at 3 % the laptop suspends. Try with `qs ipc call battery simulate 5`.
- **Greeter** (greetd on tty1, `system/etc/greetd/`): Alt+U users (only with several users), Alt+P power options.
  It runs a copy of `home/quickshell/.config/quickshell` from `/var/lib/glass-shell/greeter/shell`: re-run
  `install.sh` (or copy it) after changing the shell. Try it inside the session:
  `GLASS_GREETER_TEST=1 qs -p ~/.config/quickshell/greeter.qml` (adds a Guest, fake auth; Enter on Guest quits).
  Your picture: `~/.face` (install.sh copies it for the greeter).

### If something goes wrong

- **Greeter fails**: it falls back to the text login (agreety) on tty1 by itself; `Ctrl+Alt+Backspace` in the
  greeter also drops to it. `Ctrl+Alt+F2` always gives a normal TTY login.
- **Back to the plain text login**: `sudo systemctl disable greetd` and reboot
  (or now: `sudo systemctl stop greetd && sudo systemctl start getty@tty1`). getty@tty1 stays enabled.
- **Stuck lock screen** (qs crashed while locked, Hyprland shows "lockdead"): `Ctrl+Alt+F2`, log in, then
  `HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$UID/hypr) hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`, go back with
  `Ctrl+Alt+F1` and unlock normally.
