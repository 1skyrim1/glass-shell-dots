-- Window geometry, borders and the glass blur.

-- Window geometry (DESIGN.md §1.4), design px × 0.8 for this 1280 × 720 logical screen: gaps_out 12,
-- gaps_in 5, rounding 14, border 2. Quickshell reserves the 48 px above the pills (surfaces/Bar.qml), so
-- tiled windows start at y = 60.
hl.config({
    general    = { gaps_out = 10, gaps_in = 4, border_size = 1 },
    decoration = { rounding = 11 },
})

-- Border colours: the wallpaper's accent (matugen primary) on the active window, white 8 % on the others.
-- matugen writes ~/.local/state/glass-shell/hypr-colors.lua (one border_apply call) for the colours at start;
-- while running, Quickshell calls `hyprctl eval 'border_apply("<hex>")'` so the border follows the wallpaper
-- switcher's live preview (qs services/GlassSync.qml).
function border_apply(hex)
    hl.config({ general = { col = { active_border = "rgb(" .. hex .. ")", inactive_border = "rgba(ffffff14)" } } })
end
pcall(dofile, (os.getenv("HOME") or "") .. "/.local/state/glass-shell/hypr-colors.lua")

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

function glass_apply(strength)
    if not glass[strength] then strength = "balanced" end
    local g = glass[strength]
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
        rule:set_enabled(name == strength)
    end
end

-- Default until Quickshell starts and applies Config.glass.
glass_apply("balanced")
