-- Hyprland for the greeter only (greetd → glass-greeter.sh). It shows the Quickshell greeter and nothing else.
-- Monitor and keyboard match the session's hypr/conf/devices.lua; the glass blur rule is the balanced one.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.config({
    input = {
        kb_layout  = "de,de,de",
        kb_variant = ",neo,bone",
        kb_model   = "pc105",
    },
    decoration = {
        blur = { enabled = true, size = 6, passes = 3, vibrancy = 0.5, brightness = 1.0, contrast = 1.0, noise = 0.01 },
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_autoreload = true,
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
    },
    ecosystem = { no_update_news = true, no_donation_nag = true },
})

-- Glass: Hyprland blurs what's behind the greeter's chips and popovers (layer "glass-shell-greeter").
hl.layer_rule({ name = "glass-blur", match = { namespace = "glass-shell-.*" }, blur = true, ignore_alpha = 0.3 })

-- The greeter; when it quits (session started, or it crashed) Hyprland exits too, so greetd can go on
-- (glass-greeter.sh falls back to the text login if no session was started).
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p /var/lib/glass-shell/greeter/shell/greeter.qml; hyprctl dispatch 'hl.dsp.exit()'")
end)

-- Emergency exit to the text login.
hl.bind("CTRL + ALT + BackSpace", hl.dsp.exit())

-- Media keys work here too.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
