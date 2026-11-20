-- ============================================================
--  Placement des écrans
--  Chargé automatiquement par ~/.config/hypr/hyprland.lua
--  (fichier perso : non écrasé par les mises à jour des dots)
--
--  position = "X x Y" en pixels.
--  L'écran placé en "0x0" est celui du coin supérieur gauche.
--  Pour échanger gauche/droite : mets HDMI-A-1 en 0x0
--  et DP-2 en 1920x0.
--  Après modification : hyprctl reload
-- ============================================================

hl.monitor({
    output   = "HDMI-A-1",          -- iiyama PL2466H
    mode     = "1920x1080@60",
    position = "0x0",               -- à gauche
    scale    = 1,
})

hl.monitor({
    output   = "DP-2",              -- AOC 27G2G8
    mode     = "1920x1080@60",
    position = "1920x0",            -- à droite
    scale    = 1,
})
