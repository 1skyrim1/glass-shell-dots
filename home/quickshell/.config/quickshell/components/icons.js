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

    // Popovers
    "check": { d: "M20 6 9 17l-5-5" },
    "music": { d: "M9 18V5l12-2v13" + circle(6, 18, 3) + circle(18, 16, 3) },
    "shuffle": { d: "M16 3h5v5M4 20 21 3M21 16v5h-5M15 15l6 6M4 4l5 5" },
    "repeat": { d: "m17 2 4 4-4 4M3 11v-1a4 4 0 0 1 4-4h14M7 22l-4-4 4-4M21 13v1a4 4 0 0 1-4 4H3" },
    "skip-back": { fill: true, d: "M19 20 9 12l10-8v16zM5 19V5h2v14H5z" },
    "skip-forward": { fill: true, d: "m5 4 10 8-10 8V4zM17 5h2v14h-2V5z" },
    "pause": { fill: true, d: "M6 4h4v16H6zM14 4h4v16h-4z" },
    "play": { fill: true, d: "M7 4v16l13-8z" },

    // Launcher (12–15)
    "search": { d: circle(11, 11, 8) + "M21 21l-4.3-4.3" },
    "eye-off": { d: "M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7ZM3 3l18 18" },
    "shield": { d: "M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" },
    "cpu": { d: box(4, 4, 16, 16, 2) + "M9 9h6v6H9zM9 1v3M15 1v3M9 20v3M15 20v3M20 9h3M20 14h3M1 9h3M1 14h3" },
    "download": { d: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3" },
    "globe-line": { d: circle(12, 12, 10) + "M2 12h20" },
    "clipboard": { d: box(9, 2, 6, 4, 1) + "M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" },
    "send": { d: "m22 2-7 20-4-9-9-4zM22 2 11 13" },
    "calendar": { d: box(3, 4, 18, 18, 2) + "M16 2v4M8 2v4M3 10h18" },
    "file": { d: "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zM14 2v6h6" },
    "image": { d: box(3, 3, 18, 18, 2) + circle(9, 9, 2) + "M21 15l-3.1-3.1a2 2 0 0 0-2.8 0L6 21" },
    "link": { d: "M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" },
    "text": { d: "M4 7h16M4 12h16M4 17h10" },
    "star": { fill: true, d: "M12 2 15 9l7 .5-5.5 4.7L18 21l-6-3.8L6 21l1.5-6.8L2 9.5 9 9z" },
    "calculator": { d: box(4, 2, 16, 20, 2) + "M8 6h8M16 14v4M16 10h.01M12 10h.01M8 10h.01M12 14h.01M8 14h.01M12 18h.01M8 18h.01" },
    "smile": { d: circle(12, 12, 10) + "M8 14s1.5 2 4 2 4-2 4-2M9 9h.01M15 9h.01" },

    // Control Center (16–17)
    "sliders": { d: "M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6" },
    "power": { d: "M12 2v10M18.4 6.6a9 9 0 1 1-12.77.04" },
    "chevron-right": { d: "m9 18 6-6-6-6" },
    "chevron-left": { d: "m15 18-6-6 6-6" },
    "moon": { d: "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" },
    "plane": { d: "M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z" },
    "lock": { d: box(3, 11, 18, 11, 2) + "M7 11V7a5 5 0 0 1 10 0v4" },
    "eye": { d: "M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z" + circle(12, 12, 3) },
    "headphones": { d: "M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3" },
    "speaker": { d: box(4, 2, 16, 20, 2) + circle(12, 14, 4) + "M12 6h.01" },
    "mouse": { d: box(5, 2, 14, 20, 7) + "M12 6v4" },
    "keyboard-plain": { d: box(2, 4, 20, 16, 2) + "M7 16h10" },
    "refresh": { d: "M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8M21 3v5h-5M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16M3 21v-5h5" },
    "mic-off": { d: "M2 2l20 20M18.89 13.23A7 7 0 0 0 19 12v-2M5 10v2a7 7 0 0 0 12 5M15 9.34V5a3 3 0 0 0-5.68-1.33M9 9v3a3 3 0 0 0 5.12 2.12M12 19v3" },
}

function get(name) { return icons[name] ?? icons["app-window"] }
