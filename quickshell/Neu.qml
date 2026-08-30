pragma Singleton

import QtQuick
import Quickshell

// Runtime colour maths for the neu shell, ported from the design system so the
// desktop tints things the same way the web kit does:
//   shade()    <- src/shade.ts        (mixes in OKLCh, which keeps a hue vivid
//                                      as it lightens; sRGB washes it to grey)
//   onAccent() <- src/themes.ts       (readable ink for text on a brand face)
//   tier()     <- --neu-shadow-*      (offset / blur / reach per shadow tier)
//
// Static values live in Theme.qml (generated). This is only the parts that have
// to be computed at runtime.
Singleton {
    id: neu

    // ---- shadow ramp ---------------------------------------------------

    readonly property var _raised: ({
        xxs: { o: Theme.shadowXxsOffset, b: Theme.shadowXxsBlur, gap: Theme.shadowXxsGap },
        xs:  { o: Theme.shadowXsOffset,  b: Theme.shadowXsBlur,  gap: Theme.shadowXsGap  },
        s:   { o: Theme.shadowSOffset,   b: Theme.shadowSBlur,   gap: Theme.shadowSGap   },
        m:   { o: Theme.shadowMOffset,   b: Theme.shadowMBlur,   gap: Theme.shadowMGap   },
        l:   { o: Theme.shadowLOffset,   b: Theme.shadowLBlur,   gap: Theme.shadowLGap   },
        xl:  { o: Theme.shadowXlOffset,  b: Theme.shadowXlBlur,  gap: Theme.shadowXlGap  }
    })

    readonly property var _inset: ({
        xs: { o: Theme.insetXsOffset, b: Theme.insetXsBlur },
        s:  { o: Theme.insetSOffset,  b: Theme.insetSBlur  },
        m:  { o: Theme.insetMOffset,  b: Theme.insetMBlur  },
        l:  { o: Theme.insetLOffset,  b: Theme.insetLBlur  }
    })

    function tier(name) { return _raised[name] || _raised.m; }
    function insetTier(name) { return _inset[name] || _inset.s; }

    // Space siblings by this so their shadows meet instead of overlapping.
    function reach(name) { return tier(name).gap; }

    // ---- colour --------------------------------------------------------

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    /** color-mix(in srgb, a p%, b) -- gamma-encoded lerp, p in 0..1. */
    function mix(a, b, p) {
        return Qt.rgba(a.r * p + b.r * (1 - p),
                       a.g * p + b.g * (1 - p),
                       a.b * p + b.b * (1 - p),
                       a.a * p + b.a * (1 - p));
    }

    function _lin(u) { return u <= 0.04045 ? u / 12.92 : Math.pow((u + 0.055) / 1.055, 2.4); }
    function _unlin(u) { return u <= 0.0031308 ? 12.92 * u : 1.055 * Math.pow(u, 1 / 2.4) - 0.055; }

    function _toOklab(c) {
        const r = _lin(c.r), g = _lin(c.g), b = _lin(c.b);
        const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
        const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
        const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
        return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s];
    }

    function _fromOklab(lab, a) {
        const l = Math.pow(lab[0] + 0.3963377774 * lab[1] + 0.2158037573 * lab[2], 3);
        const m = Math.pow(lab[0] - 0.1055613458 * lab[1] - 0.0638541728 * lab[2], 3);
        const s = Math.pow(lab[0] - 0.0894841775 * lab[1] - 1.2914855480 * lab[2], 3);
        const cl = (v) => Math.min(1, Math.max(0, _unlin(v)));
        return Qt.rgba(cl(+4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                       cl(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                       cl(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s), a);
    }

    /** color-mix(in oklch, c, white|black |pct|%). pct > 0 lightens. */
    function shade(c, pct) {
        const t = Math.abs(pct) / 100;
        const lab = _toOklab(c);
        const C = Math.hypot(lab[1], lab[2]);
        const H = Math.atan2(lab[2], lab[1]);
        // White and black are chroma-zero, so their hue is powerless: only L and
        // C move and the hue rides through unchanged.
        const L = lab[0] * (1 - t) + (pct > 0 ? 1 : 0) * t;
        const C2 = C * (1 - t);
        return _fromOklab([L, C2 * Math.cos(H), C2 * Math.sin(H)], c.a);
    }

    function luminance(c) {
        return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
    }

    function contrast(a, b) {
        const la = luminance(a), lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    /** Readable ink for text sitting on `face`, matching onAccent() in themes.ts. */
    function onAccent(face) {
        const split = Math.sqrt(1.05 * 0.05) - 0.05;
        const dark = luminance(face) > split;
        const themed = dark ? "#11111b" : "#cdd6f4";
        const maxed = dark ? "#000000" : "#ffffff";
        return contrast(Qt.color(themed), face) >= 4.5 ? themed : maxed;
    }

    // ---- categorical assignment ----------------------------------------

    readonly property var domain: [
        Theme.neuDomain1, Theme.neuDomain2, Theme.neuDomain3, Theme.neuDomain4,
        Theme.neuDomain5, Theme.neuDomain6, Theme.neuDomain7, Theme.neuDomain8
    ]

    /** Deterministic per-key colour (djb2), matching colorForKey() in swatch.ts. */
    function colorForKey(key) {
        let h = 5381;
        for (let i = 0; i < key.length; i++) h = ((h << 5) + h + key.charCodeAt(i)) | 0;
        return domain[Math.abs(h) % domain.length];
    }
}
