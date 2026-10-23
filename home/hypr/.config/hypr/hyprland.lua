-- Glass Shell Hyprland config (Lua, Hyprland >= 0.56). Minimal Phase 0 version.
-- API reference: /usr/share/hypr/hyprland.lua and /usr/share/hypr/stubs/hl.meta.lua

-- Any connected screen at its preferred mode
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Same layout as the console (/etc/vconsole.conf)
hl.config({
    input = {
        kb_layout = "de",
        kb_model  = "pc105",
    },
})

local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
