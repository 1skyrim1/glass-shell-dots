-- Glass Shell Hyprland config (Lua, Hyprland >= 0.56).
-- API reference: /usr/share/hypr/hyprland.lua and /usr/share/hypr/stubs/hl.meta.lua
--
-- Split by topic into conf/*.lua (require finds them through ~/.config/hypr/?.lua). Functions that Quickshell
-- calls with `hyprctl eval` (glass_apply, motion_apply, border_apply, run_bind) are globals in those files.

require("conf.devices")   -- screens, keyboard layouts
require("conf.look")      -- gaps, rounding, borders, glass blur
require("conf.motion")    -- window and workspace animations
require("conf.session")   -- autostart, lock / idle, environment
require("conf.binds")     -- keybinds and submaps
