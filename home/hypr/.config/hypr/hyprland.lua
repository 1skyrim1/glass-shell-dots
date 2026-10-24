-- Glass Shell Hyprland config (Lua, Hyprland >= 0.56). Minimal Phase 0 version.
-- API reference: /usr/share/hypr/hyprland.lua and /usr/share/hypr/stubs/hl.meta.lua

-- Any connected screen at its preferred mode
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- German first (same as the console, /etc/vconsole.conf), then Neo 2 and Bone. Left-click the layout
-- badge cycles them; right-click lists them (layout menu).
hl.config({
    input = {
        kb_layout  = "de,de,de",
        kb_variant = ",neo,bone",
        kb_model   = "pc105",
    },
})

-- Glass blur (DESIGN.md §1.2). Quickshell draws the tinted fill; Hyprland blurs what's behind it.
-- Every Quickshell surface uses a layer namespace starting with "glass-shell-".
-- (Namespace regexes must match the whole name, hence "glass-shell-.*" and not "^glass-shell-".)
-- Blur settings are global, so each glass strength has its own set; Quickshell calls
-- `hyprctl eval 'glass_apply("<strength>")'` whenever Config.glass changes (qs services/GlassSync.qml).
--   CSS blur px -> size × passes (dual kawase grows ~2× per pass), saturation -> vibrancy,
--   heavy's "brightness 1.25" -> blur brightness.
-- ignore_alpha: pixels below it aren't blurred. It sits just under the fill alpha (but above the
-- soft shadow) so only the glass shapes blur, not the shadows around them.
local glass = {
    subtle   = { size = 3, passes = 1, vibrancy = 0.0, brightness = 1.0,  ignore_alpha = 0.5  },
    balanced = { size = 6, passes = 3, vibrancy = 0.5, brightness = 1.0,  ignore_alpha = 0.3  },
    heavy    = { size = 3, passes = 1, vibrancy = 0.8, brightness = 1.25, ignore_alpha = 0.05 },
}

-- One layer rule per strength; only the active one is enabled.
local glass_rules = {}
for name, g in pairs(glass) do
    glass_rules[name] = hl.layer_rule({
        name         = "glass-blur-" .. name,
        match        = { namespace = "glass-shell-.*" },
        blur         = true,
        ignore_alpha = g.ignore_alpha,
        enabled      = false,
    })
end

-- Global so `hyprctl eval` can reach it.
function glass_apply(strength)
    local g = glass[strength] or glass.balanced
    hl.config({
        decoration = {
            blur = {
                enabled    = true,
                size       = g.size,
                passes     = g.passes,
                vibrancy   = g.vibrancy,
                brightness = g.brightness,
                contrast   = 1.0,
                noise      = 0.01,
            },
        },
    })
    for name, rule in pairs(glass_rules) do
        rule:set_enabled(name == (glass[strength] and strength or "balanced"))
    end
end

-- Default until Quickshell starts and applies Config.glass.
glass_apply("balanced")

hl.on("hyprland.start", function()
    hl.exec_cmd("qs")
    -- Clipboard history (launcher ; mode): cliphist stores every copy, then tells the shell when and
    -- where from it was copied.
    hl.exec_cmd("wl-paste --watch sh -c 'cliphist store; qs ipc call clipboard stored'")
end)

-- Window geometry (DESIGN.md §1.4), design px × 0.8 for this 1280 × 720 logical screen: gaps_out 12,
-- gaps_in 5, rounding 14, border 2. Quickshell reserves the 48 px above the pills (surfaces/Bar.qml), so
-- tiled windows start at y = 60. Border colours (matugen) and animations come in later phases.
hl.config({
    general    = { gaps_out = 10, gaps_in = 4, border_size = 2 },
    decoration = { rounding = 11 },
})

-- Keybinds (DESIGN.md §6). Shell surfaces are driven through `qs ipc call <target> <function>`
-- (`qs ipc show` lists them). TODO = the surface arrives in a later phase; the IPC call already exists.
-- A bind with a description ("Category: Label") shows in the shell's cheatsheet (Super+Shift+Space),
-- which reads them live with `hyprctl binds -j` and runs one through run_bind() on Enter. Binds that
-- share a description form one row ("Super 1 – 9"). "… | [ ]" names keys bound by keycode.
local mainMod  = "SUPER"
local ipc      = function(args) return hl.dsp.exec_cmd("qs ipc call " .. args) end
local terminal = "kitty"
local browser     = "librewolf"
local fileManager = "nautilus"

local described = {}
local function bind(keys, action, desc, opts)
    opts = opts or {}
    if desc then
        opts.description = desc
        described[desc] = described[desc] or action
    end
    return hl.bind(keys, action, opts)
end
-- Global so `hyprctl eval` can reach it.
function run_bind(desc)
    if described[desc] then hl.dispatch(described[desc]) end
end

-- Shell surfaces
bind(mainMod .. " + space",	ipc("launcher toggle"),          "Shell: App launcher")
bind(mainMod .. " + K",		ipc("cheatsheet toggle"),        "Shell: This cheatsheet")
bind(mainMod .. " + A",         ipc("control toggle"),           "Shell: Control Center")        -- TODO Phase 5
bind(mainMod .. " + N",         ipc("notifications toggle"),     "Shell: Notifications & calendar") -- TODO Phase 6
bind(mainMod .. " + W",         ipc("wallpaper toggle"),         "Shell: Wallpaper & theme")     -- TODO Phase 7
bind(mainMod .. " + V",         ipc("launcher mode clipboard"),  "Shell: Clipboard history")
bind(mainMod .. " + period",    ipc("launcher mode emoji"),      "Shell: Emoji picker")
bind(mainMod .. " + Escape",    ipc("power toggle"),             "Shell: Power menu")            -- TODO Phase 9
bind(mainMod .. " + L",         ipc("lock lock"),                "Shell: Lock")                  -- TODO Phase 9
-- Keyboard layout: no bind; click the layout badge in the status pill.

-- Capture
bind(mainMod .. " + SHIFT + S",     ipc("capture region"),           "Capture: Capture tool")        -- TODO Phase 8
bind(mainMod .. " + SHIFT + R",     ipc("capture record"),           "Capture: Start / stop recording") -- pill only until Phase 8
bind(mainMod .. " + SHIFT + C",     ipc("capture colorpicker"),      "Capture: Colour picker")       -- TODO Phase 8
bind("Print",                       ipc("capture screen"),           "Capture: Full screen to clipboard") -- TODO Phase 8

-- Windows: focus / move with H J K L (and arrows). Super+L is lock, so focusing right is Super+Right only.
-- A list, not a table: pairs() has no order, and the cheatsheet lists binds in the order they're made.
local dirs = { { "H", "left" }, { "J", "down" }, { "K", "up" }, { "L", "right" },
               { "left", "left" }, { "down", "down" }, { "up", "up" }, { "right", "right" } }
for _, d in ipairs(dirs) do
    local key, dir = d[1], d[2]
    local letter = #key == 1
    if key ~= "L" then
        bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }), (letter or key == "right") and "Windows: Move focus" or nil)
    end
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }), letter and "Windows: Move window" or nil)
end

-- Resize mode: Super+R, then H J K L (or arrows) resize the focused window until Esc / Enter.
-- The shell shows a "RESIZE" pill next to the clock while it's active (it lists these keys).
bind(mainMod .. " + R",             hl.dsp.submap("resize"),         "Windows: Resize mode")
hl.define_submap("resize", function()
    local step = 40
    local resize = {
        H = { -step, 0 }, J = { 0, step }, K = { 0, -step }, L = { step, 0 },
        left = { -step, 0 }, down = { 0, step }, up = { 0, -step }, right = { step, 0 },
    }
    for key, d in pairs(resize) do
        hl.bind(key, hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }), { repeating = true })
    end
    hl.bind("Escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)
bind(mainMod .. " + Q",             hl.dsp.window.close(),           "Windows: Close window")
bind(mainMod .. " + F",             hl.dsp.window.fullscreen(),      "Windows: Fullscreen")
bind(mainMod .. " + T",             hl.dsp.window.float({ action = "toggle" }), "Windows: Toggle floating")
-- Super+S toggles a scratchpad kitty that's started the first time it's shown.
hl.workspace_rule({ workspace = "special:scratchpad", on_created_empty = terminal })
bind(mainMod .. " + S",             hl.dsp.workspace.toggle_special("scratchpad"), "Windows: Scratchpad terminal")
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Workspaces. [ and ] are bound by key position (the keys right of P on a US layout; Ü and + on this
-- German one), since the German layout has no plain [ ].
for i = 1, 9 do
    bind(mainMod .. " + " .. i,           hl.dsp.focus({ workspace = i }),       "Workspaces: Go to workspace")
    bind(mainMod .. " + SHIFT + " .. i,   hl.dsp.window.move({ workspace = i }), "Workspaces: Send window to workspace")
end
bind(mainMod .. " + code:34",       hl.dsp.focus({ workspace = "r-1" }), "Workspaces: Previous / next workspace | [ ]")
bind(mainMod .. " + code:35",       hl.dsp.focus({ workspace = "r+1" }), "Workspaces: Previous / next workspace | [ ]")
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
bind(mainMod .. " + Tab",           ipc("overview toggle"),          "Workspaces: Overview")          -- TODO Phase 10
bind("ALT + Tab",                   ipc("switcher next"),            "Workspaces: Window switcher")   -- TODO Phase 10
hl.bind("ALT + SHIFT + Tab",        ipc("switcher prev"))                                            -- TODO Phase 10

-- Apps & system (browser is Super+Shift+Return, not §6's Super+B)
bind(mainMod .. " + Return",        hl.dsp.exec_cmd(terminal),       "Apps & system: Terminal (kitty)")
bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(browser),       "Apps & system: Browser")
bind(mainMod .. " + E",             hl.dsp.exec_cmd(fileManager),    "Apps & system: Files")
bind(mainMod .. " + G",             ipc("gamemode toggle"),          "Apps & system: Game mode")
bind(mainMod .. " + SHIFT + N",     ipc("notifications dnd"),        "Apps & system: Do not disturb")
-- Not in the cheatsheet: Enter there runs the bind, and this one ends the session.
hl.bind(mainMod .. " + M",          hl.dsp.exit())

-- Media keys (locked: they work on the lock screen too). Volume and brightness show the OSD.
hl.bind("XF86AudioRaiseVolume",  ipc("volume up"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  ipc("volume down"),     { locked = true, repeating = true })
hl.bind("XF86AudioMute",         ipc("volume mute"),     { locked = true })
hl.bind("XF86AudioMicMute",      ipc("volume micmute"),  { locked = true })
hl.bind("XF86MonBrightnessUp",   ipc("brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", ipc("brightness down"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay",         ipc("media toggle"),    { locked = true })
hl.bind("XF86AudioPause",        ipc("media toggle"),    { locked = true })
hl.bind("XF86AudioNext",         ipc("media next"),      { locked = true })
hl.bind("XF86AudioPrev",         ipc("media prev"),      { locked = true })

-- Greeter / lock screen keys (Alt+U users, Alt+P power options) are handled inside those surfaces (Phase 9).

-- Key hints appear only while Alt is held (DESIGN.md §4). Non-consuming, so Alt+… binds and apps still get it.
hl.bind("ALT_L", hl.dsp.exec_cmd("qs ipc call keyhints press"), { non_consuming = true })
hl.bind("ALT + ALT_L", hl.dsp.exec_cmd("qs ipc call keyhints release"), { non_consuming = true, release = true })
