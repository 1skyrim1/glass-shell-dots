# Glass Shell

A keyboard-first Hyprland + Quickshell desktop (Liquid Glass look), built from scratch on a fresh Arch install.

- `design/` — the complete design handoff: `DESIGN.md` (spec), `PHASES.md` (build order + prompts),
  `screens/`, `motion/`, `source/`
- `CLAUDE.md` — rules for Claude Code

## Rebuild this setup on a fresh Arch install

What `install.sh` does: installs `packages/pacman.txt` (pacman) and `packages/aur.txt` (paru, built first), copies
`system/` to `/` (greetd + the greeter's Hyprland, the lock screen's PAM file, faillock, NetworkManager's iwd backend,
the screen-share picker), enables bluetooth, power-profiles-daemon, sshd, iwd and NetworkManager, stows every package
in `home/`, makes zsh your login shell, sets GTK to dark, makes the first matugen theme and turns on the greeter.
It's safe to re-run, prints every sudo command and asks before running it.

1. **Install Arch** with `archinstall`:
   - profile **minimal** (no desktop)
   - network: **NetworkManager** (systemd-networkd + iwd also works; install.sh switches it over)
   - audio: **PipeWire**
   - a user with sudo (wheel)
   - keyboard layout and locale as you like (this machine: `de`, en_US). Disks, bootloader, zram and locale aren't
     part of install.sh.
2. **Reboot**, log in on the TTY and connect to Wi-Fi: `nmtui` (or `iwctl` if you chose networkd).
3. **Get the repo** to `~/glass-shell`:
   ```sh
   sudo pacman -S --needed git base-devel
   git clone <your remote> ~/glass-shell     # or copy the folder over (USB stick, scp)
   ```
   This repo has no remote yet; push it somewhere (e.g. a private GitHub repo) to be able to clone it.
4. **Run the installer** as your user, from the TTY login (not with sudo; it needs your login session):
   ```sh
   cd ~/glass-shell
   ./install.sh
   ```
   - **Mirror question:** answer **no** unless the regular mirrors fail. This machine uses Omarchy's snapshot mirror
     (`system/etc/pacman.d/mirrorlist`) because the regular ones gave 404s at the time; switching a newer install to an
     older snapshot can mean a partial upgrade.
   - paru shows each AUR PKGBUILD (Geist, Geist Mono, Outfit fonts, the powerlevel10k prompt) before building it.
   - chsh asks for your password to make zsh the login shell (prompt: powerlevel10k, `home/zsh/.p10k.zsh`).
5. **Reboot.** greetd takes over tty1 with the Glass Shell greeter. Log in, and the desktop starts.
   - Without rebooting: `start-hyprland` from the TTY.
   - `Ctrl+Alt+F2` always has a plain TTY login. See "If something goes wrong" below.
6. **Optional:**
   - your own picture: replace `home/face/.face`, which is a generated placeholder (any PNG / JPG, square), then re-run
     `./install.sh` so the greeter gets a copy too.
   - Claude Code: `curl -fsSL https://claude.ai/install.sh | bash` (`~/.local/bin` is on zsh's PATH).

After changing the shell, re-run `./install.sh`: it copies the shell to the greeter
(`/var/lib/glass-shell/greeter/shell`) and installs changed `system/` files.

How this repo was built (design handoff, one Claude Code session per phase): `design/PHASES.md`.

## Glass Shell basics (Phase 1)

- Settings: `home/quickshell/.config/quickshell/config.json` (glass strength, reduced motion, idle times), reloads live.
- Colours: chosen with the wallpaper switcher (Phase 7, `Super+W`).
- IPC: `qs ipc show` lists every target; `qs ipc call test toggle` shows the glass test surface,
  `qs ipc call glass set heavy` switches glass strength (QML and Hyprland blur together).

## The bar (Phase 2)

- Five pills (`surfaces/Bar.qml`, `surfaces/bar/`): workspaces + focused window, media (while playing), clock,
  status, bell. Recording and Hyprland submaps split off the clock; volume / brightness / layout OSDs drop out of it.
- All binds from DESIGN.md §6 are in `hypr/conf/binds.lua` (`hyprland.lua` just requires the `conf/` files); ones whose surface comes later call a `qs ipc` target
  that only logs a TODO for now. `Super+R` = resize mode (H J K L, Esc).
- Try states by hand: `qs ipc call capture record` (opens the capture tool in record mode; while recording, the same call stops it), `qs ipc call notifications dnd`,
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
  Your picture: `~/.face`, stowed from `home/face/.face` (install.sh copies it for the greeter).

### If something goes wrong

- **Greeter fails**: it falls back to the text login (agreety) on tty1 by itself; `Ctrl+Alt+Backspace` in the
  greeter also drops to it. `Ctrl+Alt+F2` always gives a normal TTY login.
- **Back to the plain text login**: `sudo systemctl disable greetd` and reboot
  (or now: `sudo systemctl stop greetd && sudo systemctl start getty@tty1`). getty@tty1 stays enabled.
- **Stuck lock screen** (qs crashed while locked, Hyprland shows "lockdead"): `Ctrl+Alt+F2`, log in, then
  `HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$UID/hypr) hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`, go back with
  `Ctrl+Alt+F1` and unlock normally.

## Windows, overview (Phase 10)

- **Window motion** (`hypr/conf/motion.lua` → `motion_apply`): windows pop in from 86 % (280 ms), close by shrinking to
  90 % (200 ms), workspaces slide (300 ms), all on one soft-spring curve. The shell's own durations are in
  `services/Motion.qml`.
- **Reduced motion:** set `"reducedMotion": true` in `config.json`. Every grow / split / zoom becomes a 150 ms fade,
  with no overshoot and no shake. Hyprland follows too (Quickshell calls `motion_apply(true)`).
- **Overview** `Super+Tab`: workspaces 1–5 and the scratchpad with live previews.
  - ←→↑↓ or H J K L move between cards; Tab picks a window inside the card.
  - Enter goes there; Shift+Enter moves the window you came from to that workspace; X closes the selected window.
  - `/` filters by title or app (Esc leaves the field); Esc closes. `Super+1–5` while it's open zooms into that card.
  - Try: `qs ipc call overview toggle`.
- **Fullscreen** (`Super+F`, games): the pills float away and come back when another window or workspace takes focus.
  Toasts wait until you leave fullscreen (one catch-up toast); critical ones, OSDs, panels and the overview
  still show over the fullscreen window. Maximized windows don't count.
- **Password prompts** (polkit): while one is up, Hyprland is in a bind-less `prompt` submap, so Super shortcuts
  do nothing; Esc cancels.

