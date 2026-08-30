"""Cursor artwork for the neu theme, as SVG paths on a 24x24 grid.

Drawn rather than recoloured, so the cursor is made of the same tokens as
everything else: --neu-text fill, --neu-accent-text edge, --neu-shadow-dark cast.
Hotspots are in the same 24-unit space and scale with the rendered size.

`aliases` is the standard X11 name soup. Every theme needs it -- apps ask for a
cursor by any of a dozen historical names, and a missing one falls back to the
system default, which is how a theme ends up looking half-applied.
"""

import math


# name -> (hotspot_x, hotspot_y, svg body, frames)
# `frames` > 1 rotates the body about the centre, for the busy spinner.

ARROW = """
  <path d="M4,2 L4,19.2 L8.4,15.1 L11.2,21.2 L13.9,19.9 L11.2,13.9 L17,13.5 Z"/>
"""

# A vertical bar with serifs. Drawn as a filled path so the outline stroke
# wraps the whole glyph rather than each stroke separately.
BEAM = """
  <path d="M8.6,3 h6.8 v1.9 h-2.5 v14.2 h2.5 V21 H8.6 v-1.9 h2.5 V4.9 H8.6 Z"/>
"""

HAND = """
  <path d="M8.8,12.4 V4.6 a1.55,1.55 0 0 1 3.1,0 v5.5
           a1.4,1.4 0 0 1 2.7,0.45 v0.45
           a1.4,1.4 0 0 1 2.7,0.4 v0.5
           a1.35,1.35 0 0 1 2.6,0.45 V16.1
           c0,3.05 -2.1,5.1 -5.15,5.1 h-2.4
           c-1.95,0 -3.15,-0.85 -4.05,-2.35 L3.7,14.5
           a1.5,1.5 0 0 1 2.5,-1.7 Z"/>
"""

CROSS = """
  <path d="M11.2,2 h1.6 v8.2 H21 v1.6 h-8.2 V21 h-1.6 v-9.2 H3 v-1.6 h8.2 Z"/>
"""

def _quad(x1, y1, x2, y2, w):
    """A filled rectangle from (x1,y1) to (x2,y2), `w` wide. Everything is
    fill-only geometry so the outline layer can dilate the whole shape with one
    stroke; a path carrying its own stroke-width would escape that."""
    dx, dy = x2 - x1, y2 - y1
    ln = math.hypot(dx, dy) or 1
    px, py = -dy / ln * w / 2, dx / ln * w / 2
    return (f'<path d="M{x1+px:.2f},{y1+py:.2f} L{x2+px:.2f},{y2+py:.2f} '
            f'L{x2-px:.2f},{y2-py:.2f} L{x1-px:.2f},{y1-py:.2f} Z"/>')


def _arrows(dirs, out=8.6, head=4.4, barb=3.4, shaft=3.0, start=0.4):
    """Double-headed arrows: a filled triangle head plus a filled shaft."""
    parts = []
    for dx, dy in dirs:
        hx, hy = 12 + dx * out, 12 + dy * out
        px, py = -dy, dx
        bx, by = hx - dx * head, hy - dy * head
        parts.append(f'<path d="M{hx:.2f},{hy:.2f} '
                     f'L{bx + px*barb:.2f},{by + py*barb:.2f} '
                     f'L{bx - px*barb:.2f},{by - py*barb:.2f} Z"/>')
        parts.append(_quad(12 + dx * start, 12 + dy * start,
                           hx - dx * (head - 0.6), hy - dy * (head - 0.6), shaft))
    return "\n  ".join(parts)


def _annulus(cx, cy, r_in, r_out, a0, a1):
    """A filled arc band. Used for the busy ring, which the DS draws as a
    stroked circle -- but a filled band takes the shared outline treatment."""
    def pt(r, a):
        return cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))
    large = 1 if abs(a1 - a0) > 180 else 0
    x0o, y0o = pt(r_out, a0); x1o, y1o = pt(r_out, a1)
    x1i, y1i = pt(r_in, a1);  x0i, y0i = pt(r_in, a0)
    return (f'<path d="M{x0o:.2f},{y0o:.2f} '
            f'A{r_out},{r_out} 0 {large} 1 {x1o:.2f},{y1o:.2f} '
            f'L{x1i:.2f},{y1i:.2f} '
            f'A{r_in},{r_in} 0 {large} 0 {x0i:.2f},{y0i:.2f} Z"/>')


R2 = 0.7071

EW   = _arrows([(-1, 0), (1, 0)])
NS   = _arrows([(0, -1), (0, 1)])
NWSE = _arrows([(-R2, -R2), (R2, R2)])
NESW = _arrows([(R2, -R2), (-R2, R2)])
MOVE = _arrows([(-1, 0), (1, 0), (0, -1), (0, 1)], out=8.2, head=4.0, barb=3.0,
               shaft=2.6, start=0.3)

FORBIDDEN = """
  <path d="M12,3.2 a8.8,8.8 0 1 1 0,17.6 a8.8,8.8 0 1 1 0,-17.6 Z
           M12,5.9 a6.1,6.1 0 0 0 -4.6,10.1 L17.5,8.2 A6.1,6.1 0 0 0 12,5.9 Z
           M12,18.1 a6.1,6.1 0 0 0 4.6,-10.1 L6.5,15.8 A6.1,6.1 0 0 0 12,18.1 Z"
        fill-rule="evenodd"/>
"""

# The busy ring, matching the DS spinner: a 270-degree arc that rotates.
BUSY = _annulus(12, 12, 6.4, 9.6, -90, 170)

SHAPES = {
    "left_ptr":            (4,  2,  ARROW,     1),
    "xterm":               (12, 12, BEAM,      1),
    "hand2":               (11, 3,  HAND,      1),
    "crosshair":           (12, 12, CROSS,     1),
    "fleur":               (12, 12, MOVE,      1),
    "sb_h_double_arrow":   (12, 12, EW,        1),
    "sb_v_double_arrow":   (12, 12, NS,        1),
    "bd_double_arrow":     (12, 12, NWSE,      1),
    "fd_double_arrow":     (12, 12, NESW,      1),
    "circle":              (12, 12, FORBIDDEN, 1),
    "watch":               (12, 12, BUSY,      12),
}

# Every other name X11 clients ask for, mapped onto a shape above.
ALIASES = {
    "left_ptr": ["default", "arrow", "top_left_arrow", "left_arrow"],
    "xterm": ["text", "ibeam", "vertical-text"],
    "hand2": ["hand", "hand1", "pointer", "pointing_hand", "grab", "openhand",
              "grabbing", "closedhand", "dnd-none", "dnd-move", "e29285e634086352946a5f7f218b5c1a"],
    "crosshair": ["cross", "cross_reverse", "diamond_cross", "tcross", "cell", "color-picker"],
    "fleur": ["move", "all-scroll", "size_all", "grabbing2", "4498f0e0c1937ffe01fd06f973665830",
              "9081237383d90e509aa00f00170e968f"],
    "sb_h_double_arrow": ["ew-resize", "h_double_arrow", "col-resize", "split_h",
                          "sb_h_double_arrow2", "size_hor", "left_side", "right_side",
                          "e-resize", "w-resize", "028006030e0e7ebffc7f7070c0600140"],
    "sb_v_double_arrow": ["ns-resize", "v_double_arrow", "row-resize", "split_v",
                          "size_ver", "top_side", "bottom_side", "n-resize", "s-resize",
                          "00008160000006810000408080010102"],
    "bd_double_arrow": ["nwse-resize", "size_fdiag", "top_left_corner",
                        "bottom_right_corner", "nw-resize", "se-resize",
                        "c7088f0f3e6c8088236ef8e1e3e70000"],
    "fd_double_arrow": ["nesw-resize", "size_bdiag", "top_right_corner",
                        "bottom_left_corner", "ne-resize", "sw-resize",
                        "fcf1c3c7cd4491d801f1e1c78f100000"],
    "circle": ["not-allowed", "forbidden", "no-drop", "crossed_circle", "dnd-no-drop",
               "03b6e0fcb3499374a867c041f52298f0"],
    "watch": ["wait", "progress", "left_ptr_watch", "half-busy",
              "3ecb610c1bf2410f44200f48c40d3599", "08e8e1c95fe2fc01f976f1e063a24ccd"],
}
