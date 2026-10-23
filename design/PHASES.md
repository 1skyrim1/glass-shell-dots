# Build phases

One Claude Code session per phase. For each phase:

1. `cd ~/glass-shell && claude`
2. Press **Shift+Tab** until it says *plan mode*, paste the prompt, read the plan, then approve it.
3. Let it build. From Phase 1 on it runs the shell with live reload and compares its own screenshots with the design.
4. Look at the result yourself, ask for fixes, then commit (`git add -A && git commit -m "phase N"`).
5. Run `/clear` (or quit and start `claude` again) before the next phase.

Every prompt tells Claude to read `design/DESIGN.md` and the pictures. The standing rules are in `CLAUDE.md`.

Phase 0 runs on the bare TTY (no desktop yet). Everything after it runs in kitty inside Hyprland.

---

## Phase 0 — Bootstrap the fresh system (run from the TTY)

```
This is a fresh Arch install with no desktop yet; I'm on a TTY. Read CLAUDE.md and design/DESIGN.md
(especially §7 and §8). Then:
1. Check the system: network, sudo, AUR helper (if none, propose installing paru or yay), GPU driver.
2. Create the repo layout from DESIGN.md §8 in this folder (install.sh, packages/, system/, home/).
3. Fill packages/pacman.txt and packages/aur.txt with what §7 needs: Hyprland, xdg-desktop-portal-hyprland,
   Quickshell, PipeWire/WirePlumber, NetworkManager, bluez, upower, power-profiles-daemon, brightnessctl,
   hyprsunset, matugen, kitty, zsh, grim, slurp, wl-clipboard, cliphist, hyprpicker, a screen recorder,
   libqalculate, fd, greetd, the fonts Geist, Geist Mono and Outfit, git, stow, neovim. Tell me which ones are AUR.
4. Write install.sh so it installs those lists, enables the needed services, and stows home/*.
   Show me the script, then run it once I approve.
5. Create a minimal home/hypr/.config/hypr/hyprland.lua (Super+Return = kitty, Super+Q close,
   Super+M exit) so I can start Hyprland from the TTY. Confirm Lua config works with the installed Hyprland.
6. Report the installed Quickshell version and which modules from §7 it has (Hyprland, Pipewire, Mpris,
   UPower, Notifications, SystemTray, Bluetooth, Pam, Greetd, polkit, networking, IdleMonitor).
Ask before every sudo command.
```

When it's done: quit Claude, start Hyprland from the TTY (`Hyprland`), open kitty with Super+Return and continue there.

## Phase 1 — Foundation

```
Phase 1 of design/PHASES.md: the foundation, following design/DESIGN.md §1, §4 and §5.1.
Build: a Theme singleton that reads matugen's JSON (with the role mapping in §1.1) and reloads on change;
a Config singleton (glass strength, reduced motion, idle times); a GlassRect component with the three
strengths and the pill / panel / dialog / lit variants from §1.2, including the Hyprland layer blur rules
in hyprland.lua and syncing Hyprland's blur settings with the strength; a Motion singleton with the
durations and easings from §5.1; a KeyHint component that only shows while Alt is held; an IpcHandler per
surface so every bind in §6 can call `qs ipc call …`. Generate a first matugen theme from one wallpaper.
Add a small test window that shows a pill, a panel and a dialog. Screenshot it with grim and compare
with design/screens/10-Popovers.jpg (bottom row).
```

## Phase 2 — The five pills and OSDs

```
Phase 2: the bar from design/DESIGN.md §2, matching design/screens/08-Main.jpg and 09-Bar.jpg exactly
(sizes in §1.4). Workspace pill (5 dots with active / occupied / empty / urgent, focused window icon +
title with ellipsis), media pill (only while playing), clock, status pill, bell. Temporary pills that split
off the clock (recording placeholder, key-mode/submap), tinted states (low battery, DND, game mode).
OSDs for volume, brightness and keyboard layout dropping out of the clock (no workspace OSD).
Add all keybinds from §6 to hyprland.lua (surfaces that don't exist yet can be left as TODO).
Animations from §5.3 rows "Workspace switch", "Media pill", "Recording … pill", "OSD" — compare with the
frames in design/motion/03-MotionPills-*. Screenshot and compare after each pill.
```

## Phase 3 — Popovers

```
Phase 3: the pill popovers from design/DESIGN.md §3.1 and design/screens/10-Popovers.jpg: workspace peek,
media popover (MPRIS, player switcher), tooltips, keyboard-layout menu, bell menu, plus the shared
hover / press / open / focus / disabled states. Popovers grow from their pill (§5.2).
```

## Phase 4 — Launcher family

```
Phase 4: launcher, modes and cheatsheet from design/DESIGN.md §3.3, matching design/screens/12–15
(and the -keys variants). Modes: apps, = calculator (qalc), ; clipboard (cliphist, with preview pane and pins),
: emoji, > command, / files (fd), ? shortcuts, ! web. States from 13-LauncherStates. The sheet drips out of
the clock pill (design/motion/02-MotionLauncher-*). Cheatsheet reads binds from hyprland.lua.
```

## Phase 5 — Control Center

```
Phase 5: Control Center from design/DESIGN.md §3.4, matching design/screens/16-Control.jpg and
17-ControlPages.jpg. Tiles, sliders, media card, power profile, background apps (SystemTray with menus),
sub-pages Sound / Wi-Fi & Bluetooth (password entry, pairing code) / night light. Grows from the status
pill (design/motion/01-MotionControl-*); sub-pages push (04-MotionOverlays, Control Center frame).
```

## Phase 6 — Notifications and calendar

```
Phase 6: notification server, toasts and notification center from design/DESIGN.md §3.5, matching
design/screens/18-Notifications.jpg and 19-NotifStates.jpg. Toast stack (max 3, hover fans out and pauses),
critical, reminders, inline reply, groups, progress, DND with catch-up summary, calendar with event dots
(tell me which calendar source you suggest before building it). Toast motion from 02-MotionLauncher.
Follow the cross-effect rules in §4.
```

## Phase 7 — Wallpaper and theming pipeline

```
Phase 7: wallpaper switcher from design/DESIGN.md §3.6 (design/screens/20-Wallpaper.jpg) and the matugen
pipeline: Quickshell, Hyprland borders, kitty, GTK, Qt and the greeter. Wallpapers live in
home/wallpapers. Live accent preview while browsing, Enter = circular ripple from the thumbnail
(design/motion/07-MotionWallpaper-*), Esc reverts, R random. No options in the UI.
```

## Phase 8 — Capture

```
Phase 8: the capture tool from design/DESIGN.md §3.7, matching design/screens/21–25: region, window,
screen, screenshot vs record, thumbnail card, annotate editor, colour picker, countdown, recording pill +
saved toast + trim, and the screen-share picker hooked into xdg-desktop-portal-hyprland. Capture motion
from design/motion/04-MotionOverlays-* (Capture frame). Propose the recording tool before building.
```

## Phase 9 — Session: lock, greeter, polkit, power, idle

```
Phase 9: design/DESIGN.md §3.8 and design/screens/26–32. Lock screen (WlSessionLock + PAM), greetd greeter
with user switcher and power options (Alt+U / Alt+P), polkit dialog, SSH/GPG prompt style if possible,
power menu with the arm-then-confirm behaviour, idle chain from §4 (no hypridle/hyprlock), all edge
cases in 30-SessionStates. Log-in / lock / unlock animation from design/motion/06-MotionSession-*.
greetd and PAM files go in system/ and are installed by install.sh. Before enabling greetd, make sure
I can still log in on a TTY if the greeter fails (tell me how to switch back).
```

## Phase 10 — Windows, overview, polish, reproducibility

```
Phase 10: Hyprland window and workspace animations from design/DESIGN.md §5.3 (design/motion/05-MotionWindows-*),
overview + Alt+Tab (design/screens/11-Overview.jpg), fullscreen behaviour, the remaining cross-effect rules
in §4, and reduced motion. Then do a full pass: screenshot every surface, compare with every picture in
design/screens/, list the differences and fix them. Finally check that install.sh plus packages/ would
rebuild this exact setup on another fresh Arch install, and update README.md with the steps.
```
