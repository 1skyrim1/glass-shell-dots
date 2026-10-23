.pragma library

// Stroke icons used in the design files (Lucide, 24 × 24 viewBox, stroke 2, round caps). Shapes such as
// <rect>, <circle> and <polygon> are written out as path data so one PathSvg can draw each icon.
// `fill` is drawn filled instead of stroked; `w` is the viewBox width when it isn't 24.

const box = (x, y, w, h, r) =>
    `M${x + r} ${y}h${w - 2 * r}a${r} ${r} 0 0 1 ${r} ${r}v${h - 2 * r}a${r} ${r} 0 0 1 -${r} ${r}` +
    `h-${w - 2 * r}a${r} ${r} 0 0 1 -${r} -${r}v-${h - 2 * r}a${r} ${r} 0 0 1 ${r} -${r}z`
const circle = (cx, cy, r) => `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 -${2 * r} 0`
const speaker = "M11 5 6 9H2v6h4l5 4V5z"

const icons = {
    // Focused-window app icons
    "terminal": { d: "m4 17 6-6-6-6M12 19h8" },
    "message-circle": { d: "M21 11.5a8.4 8.4 0 0 1-9 8.5 8.4 8.4 0 0 1-3.8-.9L3 21l1.9-5.7A8.5 8.5 0 1 1 21 11.5z" },
    "globe": { d: circle(12, 12, 10) + "M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" },
    "gamepad": { d: box(2, 6, 20, 12, 4) + "M6 12h4M8 10v4M15 11h.01M18 13h.01" },
    "folder": { d: "M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z" },
    "code": { d: "m16 18 6-6-6-6M8 6l-6 6 6 6" },
    "app-window": { d: box(2, 4, 20, 16, 2) + "M10 4v4M2 8h20M6 4v4" },

    // Status pill
    "wifi": { d: "M12 20h.01M2 8.82a15 15 0 0 1 20 0M5 12.86a10 10 0 0 1 14 0M8.5 16.43a5 5 0 0 1 7 0" },
    "wifi-3": { d: "M12 20h.01M5 12.86a10 10 0 0 1 14 0M8.5 16.43a5 5 0 0 1 7 0" },
    "wifi-2": { d: "M12 20h.01M8.5 16.43a5 5 0 0 1 7 0" },
    "wifi-1": { d: "M12 20h.01" },
    "wifi-off": { d: "M12 20h.01M8.5 16.43a5 5 0 0 1 7 0M5 12.86a10 10 0 0 1 5.17-2.69M19 12.86a10 10 0 0 0-2-1.52M2 8.82a15 15 0 0 1 4.18-2.64M22 8.82a15 15 0 0 0-11.29-3.76M2 2l20 20" },
    "bluetooth": { d: "m7 7 10 10-5 5V2l5 5L7 17" },
    "mic": { d: box(9, 2, 6, 12, 3) + "M19 10v2a7 7 0 0 1-14 0v-2M12 19v3" },
    "volume-0": { d: speaker },
    "volume-1": { d: speaker + "M15.54 8.46a5 5 0 0 1 0 7.07" },
    "volume-2": { d: speaker + "M15.54 8.46a5 5 0 0 1 0 7.07M19.07 4.93a10 10 0 0 1 0 14.14" },
    "volume-x": { d: speaker + "M22 9l-6 6M16 9l6 6" },
    // Battery outline; the charge level is drawn separately (StatusPill), it changes width.
    "battery": { w: 28, d: box(2, 6, 20, 12, 3) + "M25 10v4" },
    "coffee": { d: "M17 8h1a4 4 0 1 1 0 8h-1M3 8h14v9a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4ZM6 2v2M10 2v2M14 2v2" },

    // Bell pill
    "bell": { d: "M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0" },
    "bell-off": { d: "M13.73 21a2 2 0 0 1-3.46 0M18.63 13A17.89 17.89 0 0 1 18 8M6.26 6.26A5.86 5.86 0 0 0 6 8c0 7-3 9-3 9h14M18 8a6 6 0 0 0-9.33-5M1 1l22 22" },

    // OSDs
    "sun": { d: circle(12, 12, 4) + "M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41" },
    "keyboard": { d: box(2, 4, 20, 16, 2) + "M6 8h.01M10 8h.01M14 8h.01M18 8h.01M8 12h.01M12 12h.01M16 12h.01M7 16h10" },
}

function get(name) { return icons[name] ?? icons["app-window"] }
