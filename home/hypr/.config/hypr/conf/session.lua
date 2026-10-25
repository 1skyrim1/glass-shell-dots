-- What starts with Hyprland, the lock / idle side of the session, environment.

hl.on("hyprland.start", function()
    -- GLASS_SHELL_LOGIN: this is a fresh log in, so the pills drop in (the second half of the greeter's motion).
    hl.exec_cmd("GLASS_SHELL_LOGIN=1 qs")
    -- Clipboard history (launcher ; mode): cliphist stores every copy, then tells the shell when and
    -- where from it was copied.
    hl.exec_cmd("wl-paste --watch sh -c 'cliphist store; qs ipc call clipboard stored'")
end)

-- Session (DESIGN.md §3.8, §4): the lock and the idle chain live in Quickshell (no hyprlock / hypridle).
-- allow_session_lock_restore: if qs dies while locked, the session stays locked and a restarted qs takes the
-- lock over (from a TTY: HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$UID/hypr) hyprctl dispatch 'hl.dsp.exec_cmd("qs")').
-- Input wakes a screen the idle chain turned off.
hl.config({
    misc = {
        allow_session_lock_restore = true,
        key_press_enables_dpms     = true,
        mouse_move_enables_dpms    = true,
    },
})

-- Qt apps take their colours from qt6ct, which reads matugen's scheme (~/.config/qt6ct/colors/matugen.conf).
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
