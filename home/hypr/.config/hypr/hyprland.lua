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
end)

local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())

-- Key hints appear only while Alt is held (DESIGN.md §4). Non-consuming, so Alt+… binds and apps still get it.
hl.bind("ALT_L", hl.dsp.exec_cmd("qs ipc call keyhints press"), { non_consuming = true })
hl.bind("ALT + ALT_L", hl.dsp.exec_cmd("qs ipc call keyhints release"), { non_consuming = true, release = true })
