-- Keybinds (DESIGN.md §6). Shell surfaces are driven through `qs ipc call <target> <function>`
-- (`qs ipc show` lists them).
-- A bind with a description ("Category: Label") shows in the shell's cheatsheet (Super+K), which reads them
-- live with `hyprctl binds -j` and runs one through run_bind() on Enter. Binds that share a description form
-- one row ("Super 1 – 9"); the cheatsheet lists them in the order they're made. "… | [ ]" names keys bound
-- by keycode.

local mainMod     = "SUPER"
local terminal    = "kitty"
local browser     = "librewolf"
local fileManager = "nautilus"

local function ipc(args) return hl.dsp.exec_cmd("qs ipc call " .. args) end

local described = {}
local function bind(keys, action, desc, opts)
    opts = opts or {}
    if desc then
        opts.description = desc
        described[desc] = described[desc] or action
    end
    return hl.bind(keys, action, opts)
end
function run_bind(desc)
    if described[desc] then hl.dispatch(described[desc]) end
end

-- Shell surfaces. Keyboard layout: no bind; click the layout badge in the status pill.
bind(mainMod .. " + space",         ipc("launcher toggle"),          "Shell: App launcher")
bind(mainMod .. " + K",             ipc("cheatsheet toggle"),        "Shell: This cheatsheet")
bind(mainMod .. " + A",             ipc("control toggle"),           "Shell: Control Center")
bind(mainMod .. " + N",             ipc("notifications toggle"),     "Shell: Notifications & calendar")
bind(mainMod .. " + W",             ipc("wallpaper toggle"),         "Shell: Wallpaper & theme")
bind(mainMod .. " + V",             ipc("launcher mode clipboard"),  "Shell: Clipboard history")
bind(mainMod .. " + period",        ipc("launcher mode emoji"),      "Shell: Emoji picker")
bind(mainMod .. " + Escape",        ipc("power toggle"),             "Shell: Power menu")
bind(mainMod .. " + L",             ipc("lock lock"),                "Shell: Lock")

-- Capture
bind(mainMod .. " + SHIFT + S",     ipc("capture open"),             "Capture: Capture tool")
bind(mainMod .. " + SHIFT + R",     ipc("capture record"),           "Capture: Start / stop recording")
bind(mainMod .. " + SHIFT + C",     ipc("capture colorpicker"),      "Capture: Colour picker")
bind("Print",                       ipc("capture shot"),             "Capture: Full screen to clipboard")

-- Windows: focus / move with H J K L (and arrows). Super+L is lock, so focusing right is Super+Right only.
-- A list, not a table: pairs() has no order.
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
    bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }),       "Workspaces: Go to workspace")
    bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), "Workspaces: Send window to workspace")
end
bind(mainMod .. " + code:34",       hl.dsp.focus({ workspace = "r-1" }), "Workspaces: Previous / next workspace | [ ]")
bind(mainMod .. " + code:35",       hl.dsp.focus({ workspace = "r+1" }), "Workspaces: Previous / next workspace | [ ]")
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
bind(mainMod .. " + Tab",           ipc("overview toggle"),          "Workspaces: Overview")

-- Apps & system (browser is Super+Shift+Return, not §6's Super+B)
bind(mainMod .. " + Return",        hl.dsp.exec_cmd(terminal),       "Apps & system: Terminal (kitty)")
bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(browser),       "Apps & system: Browser")
bind(mainMod .. " + E",             hl.dsp.exec_cmd(fileManager),    "Apps & system: Files")
bind(mainMod .. " + G",             ipc("gamemode toggle"),          "Apps & system: Game mode")
bind(mainMod .. " + SHIFT + N",     ipc("notifications dnd"),        "Apps & system: Do not disturb")
-- Not in the cheatsheet: Enter there runs the bind, and this one ends the session.
hl.bind(mainMod .. " + M",          hl.dsp.exit())

-- Media keys (locked: they work on the lock screen too). Volume and brightness show the OSD.
local function media_binds()
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
end
media_binds()

-- While a password prompt (polkit) is up, Super shortcuts do nothing (DESIGN.md §4): Quickshell switches to
-- this submap, which only has the media keys. Esc and typing reach the prompt, which holds the keyboard.
hl.define_submap("prompt", media_binds)

-- Greeter / lock screen keys (Alt+U users, Alt+P power options) are handled inside those surfaces.

-- Key hints appear only while Alt is held (DESIGN.md §4). Non-consuming, so Alt+… binds and apps still get it.
hl.bind("ALT_L",       ipc("keyhints press"),   { non_consuming = true })
hl.bind("ALT + ALT_L", ipc("keyhints release"), { non_consuming = true, release = true })
