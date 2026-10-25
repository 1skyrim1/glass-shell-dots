-- Screens and input.

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
