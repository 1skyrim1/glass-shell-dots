# Glass Shell — design spec

A keyboard-first Hyprland + Quickshell desktop for an Arch laptop (16:9), inspired by Apple's Liquid Glass.
Everyday use: programming, Discord, web, occasional games.

This file is the single source of truth for building it. The pictures in `screens/` and `motion/`
show exactly how things should look; `source/` has the original design files with every exact value.

---

## 0. How to use this folder

| Path | What it is |
|---|---|
| `DESIGN.md` | This spec: tokens, every surface, interactions, motion, keybinds, implementation notes |
| `PHASES.md` | The build order, with a ready prompt per phase |
| `screens/NN-Name.jpg` | One picture per screen, key hints hidden (the default look) |
| `screens/NN-Name-keys.jpg` | The same screen with key hints visible (what holding Alt shows) |
| `motion/NN-MotionX-fK-PPpct.jpg` | Frames of each animation; `PP` = position in the loop (%) |
| `source/*.dc.html` | Original artboards (HTML/CSS). Exact colours, sizes, radii, keyframes. Ignore the `{{…}}` template bits and `/_blob/…` image links (wallpapers are placeholders). |
| `source/canvas.json` | Board layout plus all design notes (the `notes` object) |

All designs are drawn at **1600 × 900** (16:9). Scale every pixel value by `screenWidth / 1600`
(e.g. 1920 × 1080 → ×1.2) or design in logical pixels if the laptop uses fractional scaling.

Placeholders in the pictures: `[username]`, "Guest", the calendar events, Discord messages, track names
and the wallpapers are sample content, not real data.

---

## 1. Design tokens

### 1.1 Colour roles (all from matugen, except the fixed status colours)
Values shown are the "Dusk" wallpaper's dark scheme. In code, never hard-code these — read matugen's output.

| Role in this spec | Dusk value | matugen role |
|---|---|---|
| accent | `#E6B6FF` | `primary` |
| on-accent | `#3A1A4D` | `on_primary` |
| accent container (lit pill, avatar bg) | `#5E3876` (pills use it at 60 % alpha) | `primary_container` |
| on-container | `#F6D9FF` | `on_primary_container` |
| text | `#EEE6F2` / `#F4EEF7` | `on_surface` |
| text muted | `#CDBFD6` | `on_surface_variant` |
| text faint (labels, hints) | `#B9AEC2`, `#9A8FA3` | `outline` |
| secondary accent (prefix chars, urgent dot, brightness fill) | `#FFB59C` | `tertiary` |
| glass tint | `rgb(22,14,30)` | `surface` (dim) |
| error | `#FF6B6B`, container `rgba(140,30,34,.55)`, text `#FFE1DE` | `error` / `error_container` |
| warning (fixed) | `#FFB36B`, container `rgba(110,60,16,.45)`, text `#FFE2C7` | — |
| success / sharing (fixed) | container `rgba(20,80,50,.5)`, border `rgba(140,230,180,.5)`, text `#D4F7E2` | — |
| good (mic level, progress) | `#C5E3B4` | — |

Second palette for reference (Fjord wallpaper): accent `#9ECAFF`, secondary `#BBC7DB`, tertiary `#7FD8C3`,
surface `#111418`, error `#FFB4AB` — see `screens/20-Wallpaper.jpg`.

matugen also themes: Hyprland active border (= accent), kitty, GTK, Qt, the greeter.

### 1.2 Glass recipe
Every surface is the same material with three intensities. **Strength is a config value**
(`glass: "subtle" | "balanced" | "heavy"`, default `balanced`), not a UI option.

| Strength | Fill (surface colour) | Blur behind | Saturation | Border | Top highlight |
|---|---|---|---|---|---|
| subtle | 82 % | 6 px | 100 % | 1 px white 8 % | none |
| **balanced** | **44 %** | **26 px** | **170 %** | **1 px white 13 %** | **inset 1 px white 20 %** |
| heavy | 6 % (+ brightness 1.25) | 4 px | 220 % | 1 px white 35 % | inset 1 px white 55 % + faint accent glow at the bottom |

Variants (balanced):
- **Pill**: as above + drop shadow `0 10 34 black 38 %`.
- **Panel / sheet** (Control Center, launcher, notification center, popovers): fill 50–55 %, blur 34 px, saturation 180 %, border white 14–16 %, highlight white 22–24 %, shadow `0 30 80 black 50 %`.
- **Dialog** (polkit): fill 58 %, blur 40 px, shadow `0 40 100 black 60 %`.
- **Lit** (pill whose panel is open, toggled-on state): fill = accent container 60 %, border accent 50 %.
- Plus a bottom inner line white 4 % for depth.

**Implementation note — blur:** Quickshell can't blur what's behind its own windows. The blur comes
from Hyprland layer rules on Quickshell's layer namespaces (blur + an alpha threshold so only the drawn
shapes blur). Saturation = Hyprland blur `vibrancy`. Because Hyprland's blur settings are global,
changing glass strength must update both the QML fill/border values **and** the Hyprland blur settings
(at runtime via `hyprctl keyword` or the Lua config).

### 1.3 Typography
- **Geist** (UI): 400 / 500 / 600 / 700.
- **Geist Mono**: key caps, numbers that change (timers, sizes, hex), code.
- **Outfit SemiBold 600**: only the big clock on the greeter and lock screen (156 px, letter-spacing −4 px, tabular figures).

| Use | Size / weight |
|---|---|
| Pill text | 13 px (clock time 14 px 600, date 13 px muted) |
| Secondary text | 12–12.5 px |
| Panel title | 15 px 600 |
| Section label | 11.5 px, uppercase, letter-spacing 0.6 px, faint |
| List row | 13–14.5 px |
| Launcher field | 16–19 px |
| Key cap | Geist Mono 11 px, pad 2×6, radius 6, bg white 10 %, border white 16 % |
| Greeter/lock date | 20 px 500 · name 21 px 600 |

### 1.4 Shape & spacing
| Thing | Value |
|---|---|
| Pill height / radius | 38 / 19 |
| Pill padding | 12–14 px around text; 6 px around a round element (so it sits concentric) |
| Gap between pills | 8 px · bar inset from screen edge 12 px (top 10 px) |
| Round inner element in a pill | 26 px circle |
| Session chips (greeter/lock) | height 44, radius 22 |
| Popovers | radius 22, padding 10 |
| Panels / launcher sheet | radius 26, padding 12–16 |
| Dialogs / large sheets | radius 30 |
| Tiles | radius 16–18 |
| List rows | height 44–58, radius 12–16 |
| Windows | Hyprland `gaps_out` 12, `gaps_in` 5, rounding 14, active border 2 px accent |
| Reserved top area | 48 px (10 + 38) so windows start at y = 60 |

---

## 2. The bar: five pills

`screens/08-Main.jpg`, `screens/09-Bar.jpg`. No full-width bar — separate glass islands that hug their content.

```
[ workspace dots | icon + window title ] [ media ]        [ date  time ]        [ DE wifi bt vol batt% ] [ bell ]
 left, x = 12                                               centred                 right, ends at x = −58   right
```

1. **Workspace pill** (left). Five dots, no numbers:
   - active: accent capsule 18 × 8
   - has windows: filled dot 8 × 8, text colour 62 %
   - empty: ring 8 × 8, 1.5 px, text colour 32 %
   - urgent: tertiary dot with a 3 px halo
   - Then a 1 × 16 divider, then the focused window: app icon 14 px in accent + window title (500 weight), max 220 px with ellipsis. Title hides on empty workspaces → pill shrinks to just the dots.
   - Click a dot = go there. Scroll = cycle. Hover a dot 400 ms = workspace peek popover.
2. **Media pill** — only while something plays. 26 px accent-container circle with 3 animated equalizer bars + title (max 110 px). Click = media popover. Scroll = previous / next track.
3. **Clock pill** (centred). `Tue 20 Oct` muted + `06:47` 600. Click = notification center.
4. **Status pill**: layout badge (`DE`, Geist Mono 11, chip bg white 8 %), Wi-Fi, Bluetooth, volume, battery icon + `78%`. Click = Control Center. Scroll = volume. Left-click on DE = next layout, right-click = layout menu.
5. **Bell pill** (38 × 38). Tertiary dot when unread. Click = notification center. Right-click = DND menu.

**Temporary pills that split off the clock** (`09-Bar`):
- Recording (right of the clock): red container, red dot with halo, `01:24` mono, stop on click.
- Sharing (right of the clock): green container, "Sharing <window>", Stop button (`25-SharePicker`).
- Key mode / Hyprland submap (left of the clock): accent container, `RESIZE` + its keys. Shown while any submap is active.
- Idle countdown: the clock pill itself turns into "Locking in 8 s" with a ring (`30-SessionStates`).

**Tinted states**: low battery 15 % → status pill stretches left and turns warning-coloured for 5 s;
do not disturb → bell pill lit with a crossed bell; game mode / keep awake → small accent circles at the start of the status pill.

**OSDs** drop out of the clock pill: 290 × 46, radius 23. Volume (accent fill), brightness (tertiary fill),
keyboard layout. Fade 1.2 s after the last press. **No workspace OSD.** Suppressed while Control Center is open.

**Pill states** (`10-Popovers`, bottom row): rest · hover (lighter, scale 1.04, 120 ms, specular edge follows cursor) ·
press (scale 0.95, springs back to ~1.02) · open (lit) · keyboard focus (2 px accent ring + 4 px 20 % halo) · disabled (45 %).

---

## 3. Surfaces

Each entry: trigger · where it comes from · contents · keys. Pictures named in brackets.

### 3.1 Pill popovers (`10-Popovers`)
- **Workspace peek**: hover dot 400 ms. 290 px wide. "Workspace 2 · 2 windows", live preview (120 px tall), list of windows (icon + title).
- **Media**: click media pill. 360 px. Cover 76 px r14, title 15/600, artist, seek bar (5 px, knob 13 px), times in mono, shuffle · prev · play/pause (50 px light circle) · next · repeat, player chips (Spotify / Firefox · YouTube) when several MPRIS players exist. Keys: Space, ←/→ seek, Tab player.
- **Tooltips**: hover 600 ms, glass, 30 px tall, radius 15, one line, never covers the pill.
- **Layout menu**: right-click DE. List of layouts with a check.
- **Bell menu**: right-click bell. DND for 1 h / until tomorrow / until off, clear all.

### 3.2 Overview & Alt+Tab (`11-Overview`)
Super+Tab: background blurred, filter field at top, workspace cards 400 × 225 in a 3 × 2 grid with live window previews; the
active card has the accent border; a scratchpad card. Alt+Tab: horizontal strip of app tiles (64 px, r18) with a ring on the
selected one; only shows if Alt is held > 120 ms.

### 3.3 Launcher family
- **Launcher** (`12-Launcher`): Super+Space. Sheet 660 px, centred, top ≈ 150. Field 56 px with search icon + mode chip on the right. Sections "Best match", "Apps". Rows 58 px, icon tile 40 px r12, matched characters in accent 700. First result pre-selected (accent container + 1 px accent border). Mode chips at the bottom (`=` Calculator, `;` Clipboard, `:` Emoji, `>` Command, `/` Files, `?` Shortcuts). Dims the desktop 34 %.
- **States** (`13-LauncherStates`): just opened (recent apps row + suggestions), no results (install with pacman / web search / run in kitty), files (`/`, fd over ~), command (`>`, output shown in the sheet, history).
- **Modes** (`14-Modes`): calculator (big result, hex/bin, history), clipboard (list + preview pane, pin), emoji (8-column grid, recent, Emoji / Kaomoji / Symbols tabs).
- **Cheatsheet** (`15-Cheatsheet`): Super+Shift+Space. Same sheet, 1260 px, three columns of binds grouped, filter, category tabs. Binds are read from `hyprland.lua`. Keycaps always visible here.

### 3.4 Control Center (`16-Control`, `17-ControlPages`)
Super+A or click the status pill. 410 px panel under the status pill (right-aligned to it), the pill stays lit.
- Header: battery %, time left, two round buttons: sliders (opens the Quickshell config in nvim) and power (morphs into the power menu).
- Wide tiles: Wi-Fi, Bluetooth (both with ›). Tile body = toggle, › = shared "Wi-Fi & Bluetooth" page scrolled to that section.
- 3 × 2 small tiles: Night light, Do not disturb, Game mode, Keep awake, Microphone, Airplane. Number keys 1–8 toggle.
- Sliders: volume (with device name → Sound page), brightness.
- Media card, power profile segmented control (Saver / Balanced / Performance), background apps (tray) row.
- Sub-pages (push from the right): **Sound** (outputs, inputs with live mic level, per-app volume), **Wi-Fi & Bluetooth** (networks; a secured network's row grows into a password field + Cancel / Connect; Bluetooth scan with a pairing code), **background-app menu** (tray menu), **Night light** grows in place (temperature slider, schedule).

### 3.5 Notifications (`18-Notifications`, `19-NotifStates`)
- Toasts: 340 px under the bell, right-aligned. App tile 26 px r8, header line, body, timer line (3 px, accent). Max 3 visible as a stack (older ones scale 95 % / 90 %, tucked behind). Hover fans the stack out and pauses timers.
- Notification center: Super+N, the clock or the bell. 800 px panel under the clock: left column calendar (30 px weekday title, month grid with event dots, "Today" event list), right column notifications (DND toggle, grouped cards, inline reply field).
- States: critical (red container, never times out, breaks through DND), calendar reminder (Snooze 5 min / Dismiss), inline reply typing + send button, expanded group, progress (updates in place), empty center + DND ("All caught up"), catch-up summary after DND/game mode, another calendar day selected.
- Timers: 5 s, 10 s with actions, never for critical.

### 3.6 Wallpaper switcher (`20-Wallpaper`)
Super+W. Sheet at the bottom with thumbnails (194 × 109, selected one larger with accent ring and halo). A row below
with the name, 4 palette dots and "previewing live". **No options.** ←/→ preview accents live, Enter applies, R random, Esc reverts.

### 3.7 Capture (`21`–`25`)
- **Region** (`21-CaptureRegion`): Super+Shift+S. Freeze + dim (58 %), selection with accent 2 px border and 8 handles, size readout pill, loupe with hex. Toolbar at the bottom (74 px tall, radius 37): Region / Window / Screen, Screenshot ↔ Record segmented, Delay / Copy + save options, Capture button, ×. After capture: thumbnail card bottom-left for 6 s (Annotate E, Save as S, Delete X).
- **Window & recording** (`22-CaptureWindow`): hovered window gets a 3 px accent outline + halo and a name/size pill; record options Mic / Desktop audio / Cursor / fps+format; red Start button. The toolbar moves to the free side of the screen.
- **Annotate** (`23-Annotate`): full-screen editor over the blurred desktop. Image centred with shadow. Top-left file info, top-right Copy / Save as / Done. Bottom toolbar: Select V, Arrow A, Rectangle R, Pen P, Text T, Highlight H, Blur B, Crop C · 5 colours · 3 stroke sizes · undo/redo.
- **Extras** (`24-CaptureExtras`): colour picker (frozen screen, loupe 8× with a pixel box, chip with swatch + hex + rgb), countdown (glass circle, Outfit number, red draining ring), Screen mode (whole screen accent frame), recording saved toast (video thumb + duration, Copy / Open folder / Trim) and a trim filmstrip.
- **Share picker** (`25-SharePicker`): when an app asks to share the screen. Sheet 1000 px: app icon + "Discord wants to share your screen", Screen / Window / Region tabs, 3-column grid of window thumbnails with number keys, "share audio" and "remember" checkboxes, Cancel / Share.

### 3.8 Session (`26`–`32`)
- **Login** (`26-Login`): greetd + Quickshell greeter. Wallpaper dimmed 22 %. Clock Outfit 600 156 px at top 118, date below. Avatar 104 px (ring white 28 %) at top 486, name, then the **coloured password pill** (320 × 52, accent container 45 % + accent border + 5 px accent halo, accent go button 40 px). Bottom-left user chip (avatar 34 + name + chevron) — only if > 1 user. Bottom-right battery chip + power chip.
- **User switcher** (`27-LoginUsers`): popover grows up from the chip: rows with avatar 40, name, last login; the centre avatar/name/field follow the selection (Guest: "No password · press Enter").
- **Lock** (`28-Lock`): identical layout over the blurred desktop (blur 30, brightness 0.62), small lock icon before the date, field says "Enter password". Battery + power bottom-right. No user switcher, no notifications, no media.
- **Power options** (`29-LockPower`): popover grows up from the power chip: Suspend S, Reboot R, Power off P. Reboot/Power off arm first (row turns red, "click or press P again", 3 s ring). Lock screen has no Log out.
- **Edge cases** (`30-SessionStates`): wrong password (red pill, shake, faillock wait), checking (spinner), Caps Lock chip (also names the layout), idle countdown, polkit wrong password (tries left), power-menu confirm, critical battery toast, "Powering off" screen (names the app that blocks), SSH/GPG passphrase prompt (same dialog as polkit).
- **Polkit** (`31-Polkit`): dim + blur, dialog 460 px r30: shield icon + requesting app's icon, "Authentication required", the action sentence, user row, password field with accent ring, collapsible Details (program, action id, PID), Cancel / Authenticate. Only one at a time, always centred.
- **Power menu** (`32-Power`): Super+Esc. Dim + blur, five 150 × 150 tiles r34: Lock L, Suspend S, Log out O, Reboot R, Power off P. Nothing else on screen. Letters only visible with key hints.

---

## 4. Interaction rules

**One thing at a time**
- Only one panel is open at once (launcher, Control Center, notification center, wallpaper switcher, cheatsheet, overview, power menu). Opening another merges the old one back into its pill while the new one grows out of its own.
- Esc closes the topmost thing; a click outside closes too. Focus returns to the previous window.
- Popovers close when a panel opens.

**Layers, top to bottom**: lock screen → password prompts → capture tool → power menu → panels & popovers → toasts & OSDs → pills → windows.

**Cross-effects**
- Locking closes every panel and cancels password prompts.
- Capture hides toasts, OSDs and its own UI from the image; recordings also hide the red pill.
- OSDs are suppressed while Control Center is open.
- While the notification center is open, new notifications go into the list (no toast).
- Fullscreen, game mode and DND hold toasts back and show one catch-up toast afterwards; critical always shows.
- Fullscreen hides the pills; switching window/workspace brings them back.
- While a password prompt is up, Super shortcuts are ignored except Esc.
- Changing the wallpaper recolours everything at once (pills, panels, borders, kitty, GTK, Qt, greeter).

**Mouse**: left click opens, right-click gives options, scroll changes the value under the cursor. Hover is never required.

**Keyboard**: Super + letter opens; Super + Shift + letter captures; Esc closes. Inside surfaces: arrows or H J K L, Enter,
Tab, Alt+1–9. **Holding Alt in any open surface fades in its key hints** (hidden otherwise). Compare `NN-Name.jpg` with `NN-Name-keys.jpg`.

**Idle chain**: dim + 10 s countdown → lock at 5 min → screen off at 7 min → suspend at 15 min on battery (no suspend on AC).
Skipped while video plays or Keep awake is on.

---

## 5. Motion

Frames in `motion/`; exact keyframes in `source/Motion*.dc.html` (they play at half speed — halve the durations there, or use the real values below).

### 5.1 System
| Size | Used for | Duration | Easing |
|---|---|---|---|
| Micro | hover, press, toggle, colour change | 120 ms | OutCubic |
| Small | popovers, tooltips, OSD fill, title cross-fade | 180–220 ms | OutCubic |
| Medium | launcher, Control Center, notification center, sheets | 320–420 ms open | OutBack (overshoot 1.15) |
| Large | lock, log in, wallpaper ripple, overview zoom | 450–700 ms | InOutCubic |
| Closing | everything | ≈ 60 % of opening | InCubic, no overshoot |

### 5.2 Patterns
- **Grow from the pill**: a droplet the pill's size appears on top of it, stretches, a short neck forms, then it springs into the panel. Content fades in + moves up 6–10 px once the shape is 60 % done. The pill itself never moves and stays lit while open. (`01-MotionControl`, `02-MotionLauncher`)
- **Split / merge**: temporary pills bud off the clock with a thin neck that snaps; leaving merges back. (`03-MotionPills`)
- **Rise**: full-screen overlays dim + blur first (200 ms), then rise or scale in from 92 %. (`04-MotionOverlays`)
- **Shake**: errors shake sideways 4× with damping (±8, ±8, ±5, ±4 px; 300 ms).
- **Stagger**: tiles and rows arrive 30–40 ms apart.
- **Push**: sub-pages slide in from the right while the previous page slides left and fades; panel height springs (300 ms).
- **Reduced motion** (config flag): every grow/split becomes a 150 ms fade; no overshoot; no shake.

### 5.3 Per surface
| Surface | Animation | Real timing |
|---|---|---|
| Control Center | grows from status pill | 400 ms open / 220 ms close |
| Launcher, cheatsheet | drips from clock to centre, desktop dims | 400 / 240 ms |
| Notification center | drips from clock, two columns fade up | 420 / 240 ms |
| Toast | bell widens along the top, drops, timer drains, merges back leaving a dot | 300 ms in / 240 ms out |
| Popovers | grow from their pill | 200 ms |
| Workspace switch (pill) | capsule stretches toward the new dot then lets go; title blurs up / new title rises; pill width animates | 260 / 180 / 220 ms |
| Media pill | slides out from behind the workspace pill with overshoot; tucks back 10 s after playback stops | 320 / 220 ms |
| Recording / sharing / key-mode pill | split off the clock, colour change, merge back | 380 / 200 / 300 ms |
| OSD | droplet from clock → OSD; later presses only move the fill (120 ms/step); pulled back after 1.2 s | 300 / 240 ms |
| Wallpaper | sheet rises; browsing cross-fades accents only (240 ms); Enter = circular ripple of the new wallpaper from the selected thumbnail, sheet sinks; matugen/kitty/GTK/Qt reload during the ripple | sheet 320 ms, ripple 700 ms |
| Log in | spinner in the go button; avatar + field sink & fade; the big clock shrinks and flies up into the clock pill; other pills drop in from the top; windows fade in from 96 % | 700 ms |
| Lock | pills float up and fade; desktop blurs + darkens; the clock grows out of its pill; avatar + field rise | 500 ms |
| Unlock | like log in, but only the blur clears | 450 ms |
| Log out / power off | fade to black | 400 ms |
| Power menu | dim + blur, tiles rise 40 ms apart with a small bounce; armed tile turns red | 200 + 300 ms |
| Polkit | dim, dialog scales from 92 %; wrong password = shake + red field | 260 ms / 300 ms |
| Capture | soft flash on freeze, dim, toolbar rises, selection draws; on capture a flash, selection flies to the corner thumbnail | 80 ms flash, 300 ms fly |
| Windows (Hyprland) | windowsIn popin 86 % 280 ms · windowsOut popin 90 % 200 ms · workspaces slide 300 ms · fade 200 ms · one soft-spring bezier, e.g. (0.2, 0.9, 0.1, 1.05) | — |
| Overview | current workspace zooms out into its card; others fade in; background blurs | 380 ms |
| Alt+Tab | fade + scale from 94 %; ring glides between icons | 160 ms |
| Fullscreen | window grows to the edges; pills float up and fade | 260 ms |

---

## 6. Keybinds

| Bind | Action |
|---|---|
| Super+Space | Launcher |
| Super+Shift+Space | Shortcut cheatsheet |
| Super+V / Super+. | Clipboard / Emoji (launcher modes) |
| Super+A | Control Center |
| Super+N | Notification center |
| Super+Shift+N | Toggle do not disturb |
| Super+W | Wallpaper switcher |
| Super+Tab / Alt+Tab | Overview / window switcher |
| Super+Esc | Power menu |
| Super+L | Lock |
| Super+Shift+S | Capture tool |
| Super+Shift+R | Start / stop recording |
| Super+Shift+C | Colour picker |
| Print | Full screen to clipboard |
| Super+1–9 / Super+Shift+1–9 | Go to / send to workspace |
| Super+[ / ] | Previous / next workspace |
| Super+H J K L / +Shift | Focus / move window |
| Super+R | Resize mode (submap: H J K L, Esc) |
| Super+Q / F / T | Close / fullscreen / float |
| Super+S | Scratchpad terminal |
| Super+Return / B / E | kitty / browser / files |
| Super+G | Game mode |
| Super+Ctrl+Space | Next keyboard layout |
| Greeter / lock: Alt+U, Alt+P | User switcher (greeter only), power options |

---

## 7. Implementation notes (suggested stack — verify against the installed versions)

| Need | Suggested |
|---|---|
| Shell | Quickshell (QML). One top-layer window per screen for the bar, panels and their morph animation, with an input mask/region so clicks pass through empty areas. Panels must live in a window big enough for the droplet animation. |
| IPC for binds | Quickshell `IpcHandler` + `qs ipc call <target> <fn>` from `hyprland.lua` |
| Workspaces, title, submap, layout | `Quickshell.Hyprland` (events, focused window, active submap, keyboard layout) |
| Audio | `Quickshell.Services.Pipewire` (devices, per-app nodes) |
| Media | `Quickshell.Services.Mpris` |
| Battery, power profiles | `Quickshell.Services.UPower` (+ power-profiles-daemon) |
| Notifications | `Quickshell.Services.Notifications` (NotificationServer) |
| Tray | `Quickshell.Services.SystemTray` |
| Bluetooth | `Quickshell.Bluetooth` (bluez) |
| Wi-Fi | Quickshell networking module if available, otherwise `nmcli` via `Process` |
| Lock | `WlSessionLock` (Quickshell.Wayland); auth via PAM (`Quickshell.Services.Pam`) |
| Greeter | greetd + Quickshell greeter (`Quickshell.Services.Greetd`) running in a minimal Hyprland session; avatar from `~/.face` / AccountsService |
| Polkit | Quickshell's polkit agent if the installed version has one; otherwise keep hyprpolkitagent until it does |
| Idle | `IdleMonitor` / `IdleInhibitor` (Quickshell.Wayland) — no hypridle |
| Colours | matugen with templates for Quickshell (JSON), Hyprland, kitty, GTK, Qt, greeter |
| Screenshots | grim + slurp (or Quickshell screencopy for the frozen frame), wl-clipboard |
| Recording | gpu-screen-recorder or wf-recorder |
| Colour picker | hyprpicker (or own loupe over a screencopy) |
| Clipboard history | cliphist + wl-clipboard |
| Calculator / files / emoji | qalc (libqalculate), fd, a bundled emoji JSON |
| Brightness / night light | brightnessctl / hyprsunset |
| Share picker | xdg-desktop-portal-hyprland's custom picker setting pointing at a Quickshell picker; check xdph's expected output format |
| Fonts | Geist, Geist Mono, Outfit |

## 8. Repository & conventions

This is built on a **fresh Arch install** in a **new, separate repo** (`~/glass-shell`). It does not reuse or touch any older dotfiles.

```
~/glass-shell/
├── CLAUDE.md                  rules for Claude Code
├── README.md
├── install.sh                 reproduces the whole setup on a fresh Arch install (grows phase by phase)
├── packages/pacman.txt        one package per line
├── packages/aur.txt
├── design/                    this handoff (read-only reference)
├── system/                    files outside $HOME (greetd, PAM, portal config), installed by install.sh with sudo
└── home/                      GNU stow packages, one per app
    ├── hypr/.config/hypr/hyprland.lua
    ├── quickshell/.config/quickshell/…
    ├── matugen/.config/matugen/…
    ├── kitty/.config/kitty/…
    └── gtk/ qt/ fonts/ wallpapers/ …
```

- Deploy with `stow -d home -t ~ <package>`; never edit files in `~/.config` directly.
- Hyprland is configured in Lua (`hyprland.lua`); confirm the installed Hyprland supports it in Phase 0, otherwise ask.
- Every package that gets installed is added to `packages/*.txt`, and every system change to `install.sh`.
- Explanations go in code comments; keep it lightweight.
