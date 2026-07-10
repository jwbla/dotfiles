-- Hyprland Lua config (format introduced in Hyprland 0.55, replaces hyprland.conf)
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",
    position = "1920x0",
    scale    = 1,
})


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "ghostty"
local fileManager = "dolphin"
local menu        = "wofi --show drun"
local dbman       = "sqlitebrowser"
local freetube    = "flatpak run io.freetubeapp.FreeTube"


-------------------
---- AUTOSTART ----
-------------------

-- Autostart necessary processes (notification daemons, status bars, etc.)
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(terminal)
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "36")
hl.env("HYPRCURSOR_SIZE", "36")

-- Force Qt/KDE apps to use qt6ct (dark palette configured in ~/.config/qt6ct)
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 1,
        gaps_out = 1,

        border_size = 4,

        col = {
            -- candy apple red, crayola yellow, grabber blue
            -- active_border = { colors = {"rgba(ff0800ee)", "rgba(fce883ee)", "rgba(2b6be4ee)"}, angle = 45 },
            -- tron blue, grabber blue
            -- active_border = { colors = {"rgba(7dfdfeee)", "rgba(2b6be4ee)"}, angle = 45 },
            -- i dunno catpuccin attempt to mimic tron theme
            -- active_border = { colors = {"rgba(89dcebee)", "rgba(b4befeee)"}, angle = 45 },
            -- Green and Purple
            -- active_border = { colors = {"rgba(ba98f5ff)", "rgba(8bfa37ff)"}, angle = 45 },
            -- Pink and Purple
            active_border   = { colors = {"rgba(ac4fc6ff)", "rgba(ff007fff)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding = 5,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 0.9,

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
    dwindle = {
        preserve_split = true, -- You probably want this
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0, -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
    },
})

-- Animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("linear",   { type = "bezier", points = { {0, 0},     {1, 1}      } })

hl.animation({ leaf = "windows",    enabled = true, speed = 7,   bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7,   bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 7,   bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6,   bezier = "default" })
-- animated window border
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "us",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
        },
    },

    gestures = {
        workspace_swipe_distance = 300,
        workspace_swipe_invert   = true,
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name          = "razer-razer-naga-trinity-1",
    sensitivity   = -0.5,
    accel_profile = "flat",
})
hl.device({
    name          = "razer-razer-naga-trinity",
    sensitivity   = -0.5,
    accel_profile = "flat",
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- See https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Q",     hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C",     hl.dsp.window.close())
hl.bind(mainMod .. " + E",     hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",     hl.dsp.exec_cmd("copyq toggle"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + T",     hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(mainMod .. " + F",     hl.dsp.exec_cmd("librewolf"))
hl.bind(mainMod .. " + W",     hl.dsp.exec_cmd("chromium"))
hl.bind(mainMod .. " + G",     hl.dsp.exec_cmd(freetube))
hl.bind(mainMod .. " + D",     hl.dsp.exec_cmd(dbman))

hl.bind(mainMod .. " + M",     hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + z",     hl.dsp.exec_cmd("hyprlock"))

-- Move focus with mainMod + vim keys
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Workspace switcher with wofi
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("~/.local/bin/workspace_switcher.sh"))

-- Tmux project picker with wofi
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("~/.local/bin/tmux-wofi.sh"))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Move windows around
hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.swap({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.swap({ direction = "right" }))

-- Volume keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))

-- Media keys (locked = active even when locked/inhibited)
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("playerctl stop"),       { locked = true })

-- Brightness keys
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.local/bin/brightness.sh --inc 250"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.local/bin/brightness.sh --dec 250"))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Bind workspaces 9 and 10 to second monitor (HDMI-A-1) when it's connected.
-- When HDMI-A-1 exists, ws 9 and 10 live there and the rest stay on the primary.
-- If the monitor is not connected, these workspaces fall back to the primary monitor.
hl.workspace_rule({ workspace = "9",  monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1" })
