pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The cheatsheet's binds (15-Cheatsheet), read live from Hyprland (`hyprctl binds -j`), so they always
// match Hyprland's conf/binds.lua. Only binds with a description show; it reads "Category: Label", optionally
// "… | caps" to name keys Hyprland can't (binds by keycode, e.g. "| [ ]"). Binds sharing a description
// and modifiers become one row ("Super 1 – 9", "Super H J K L").
Singleton {
    id: root

    readonly property var categories: ["Shell", "Capture", "Windows", "Workspaces", "Apps & system", "Inside surfaces"]
    // [{ category, label, mods: [..], keys: [..], desc, runnable }], in category order then conf/binds.lua order.
    property var rows: []
    property int count: 0   // described binds in conf/binds.lua

    // Keys every surface understands (DESIGN.md §4 "Keyboard"); not Hyprland binds.
    readonly property var surfaceRows: [
        { label: "Move", mods: [], keys: ["↑ ↓ ← →", "H J K L"] },
        { label: "Act / open", mods: [], keys: ["Enter"] },
        { label: "Next section or mode", mods: [], keys: ["Tab"] },
        { label: "Jump to item n", mods: [], keys: ["Alt", "1 – 9"] },
        { label: "Close", mods: [], keys: ["Esc"] }
    ].map(r => Object.assign(r, { category: "Inside surfaces", desc: "", runnable: false }))

    function reload() { proc.running = true }

    // Runs a bind's action through conf/binds.lua's run_bind() (after the sheet has closed, so it acts on
    // the window that had focus).
    function run(row: var) {
        if (!row.runnable) return
        Quickshell.execDetached(["sh", "-c", 'sleep 0.2; hyprctl eval "run_bind($1)"', "sh", JSON.stringify(row.desc)])
    }

    readonly property var keyNames: ({
        space: "Space", Return: "Return", Escape: "Esc", Tab: "Tab", period: ".", comma: ",", Print: "Print",
        left: "←", right: "→", up: "↑", down: "↓", minus: "-", plus: "+", slash: "/"
    })
    function keyName(k: string): string { return keyNames[k] ?? (k.length === 1 ? k.toUpperCase() : k) }
    function modNames(mask: int): var {
        const m = []
        if (mask & 64) m.push("Super")
        if (mask & 1) m.push("Shift")
        if (mask & 4) m.push("Ctrl")
        if (mask & 8) m.push("Alt")
        return m
    }
    // One row's keys: digits as a range, letters in one cap, arrows in one cap, anything else alone.
    readonly property string letterOrder: "HJKLABCDEFGIMNOPQRSTUVWXYZ"
    readonly property string arrowOrder: "↑↓←→"
    function caps(keys: var): var {
        const digits = keys.filter(k => /^\d$/.test(k)).sort()
        const letters = keys.filter(k => /^[A-Z]$/.test(k)).sort((a, b) => letterOrder.indexOf(a) - letterOrder.indexOf(b))
        const arrows = keys.filter(k => arrowOrder.includes(k) && k.length === 1).sort((a, b) => arrowOrder.indexOf(a) - arrowOrder.indexOf(b))
        const rest = keys.filter(k => !digits.includes(k) && !letters.includes(k) && !arrows.includes(k))
        const out = []
        if (digits.length > 2) out.push(`${digits[0]} – ${digits[digits.length - 1]}`)
        else out.push(...digits)
        if (letters.length > 1) out.push(letters.join(" "))
        else out.push(...letters)
        if (arrows.length > 1) out.push(arrows.join(" "))
        else out.push(...arrows)
        return out.concat(rest)
    }

    Process {
        id: proc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let binds
                try { binds = JSON.parse(text) } catch (e) { console.warn("Binds: bad hyprctl output", e); return }
                const groups = new Map()
                let count = 0
                for (const b of binds) {
                    if (!b.has_description || b.submap !== "") continue
                    count++
                    const id = b.description + "|" + b.modmask
                    if (!groups.has(id)) groups.set(id, { desc: b.description, mask: b.modmask, keys: [] })
                    if (b.key !== "") groups.get(id).keys.push(root.keyName(b.key))
                }
                const rows = []
                for (const g of groups.values()) {
                    const m = g.desc.match(/^([^:]+):\s*(.*?)(?:\s*\|\s*(.*))?$/)
                    if (!m) continue
                    const keys = m[3] ? m[3].split(/\s+/) : root.caps(g.keys)
                    rows.push({ category: m[1].trim(), label: m[2], mods: root.modNames(g.mask), keys: keys,
                                desc: g.desc, runnable: g.keys.length <= 1 && !m[3] })
                }
                rows.push(...root.surfaceRows)
                // (QML's JS has no flatMap.)
                root.rows = root.categories.reduce((all, c) => all.concat(rows.filter(r => r.category === c)), [])
                    .concat(rows.filter(r => !root.categories.includes(r.category)))
                root.count = count
            }
        }
    }
}
