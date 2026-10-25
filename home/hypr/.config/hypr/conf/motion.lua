-- Window and workspace motion (DESIGN.md §5.3 "Windows", design/motion/05-MotionWindows). Speed is in 100 ms.
-- One soft-spring curve for everything that arrives or moves; closing uses an InCubic-like curve without
-- overshoot (§5.1). The shell's own motion is in Quickshell's Motion singleton; these are the Hyprland half.
-- Reduced motion (config.json "reducedMotion"): Quickshell calls `hyprctl eval 'motion_apply(true)'`
-- (qs services/GlassSync.qml): no pop-in scale, no overshoot, workspaces fade, everything 150 ms.

hl.curve("glass",    { type = "bezier", points = { {0.2, 0.9},  {0.1, 1.05} } })
hl.curve("glassOut", { type = "bezier", points = { {0.55, 0},   {1, 0.45}   } })
hl.curve("calm",     { type = "bezier", points = { {0.33, 1},   {0.68, 1}   } })

function motion_apply(reduced)
    local function anim(leaf, speed, curve, style)
        hl.animation({ leaf = leaf, enabled = true, speed = reduced and 1.5 or speed,
                       bezier = reduced and "calm" or curve, style = style })
    end
    anim("windowsIn",        2.8, "glass",    reduced and "popin 100%" or "popin 86%")  -- pops in at its tile
    anim("windowsOut",       2.0, "glassOut", reduced and "popin 100%" or "popin 90%")  -- shrinks and fades
    anim("windowsMove",      2.6, "glass")     -- neighbours make room; fullscreen grows to the edges (260 ms)
    anim("fadeIn",           2.8, "glass")
    anim("fadeOut",          2.0, "glassOut")
    anim("fade",             2.0, "glass")
    anim("border",           2.0, "glass")     -- the accent border fades onto the newly focused window
    anim("workspaces",       3.0, "glass",    reduced and "fade" or "slide")      -- higher number slides left
    anim("specialWorkspace", 3.0, "glass",    reduced and "fade" or "slidevert")  -- scratchpad drops in
end
motion_apply(false)
