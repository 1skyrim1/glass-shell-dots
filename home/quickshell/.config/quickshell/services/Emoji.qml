pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../components/fuzzy.js" as Fuzzy

// Emoji, kaomoji and symbols for the : mode (14-Modes "Emoji"). data/emoji.json comes from
// emojibase-data (names, tags, GitHub shortcodes); kaomoji and symbols are short hand-made lists.
// Loaded the first time the mode opens.
Singleton {
    id: root

    property var emoji: []     // [{ glyph, name, tags, code }]
    property var kaomoji: []
    property var symbols: []
    property bool wanted: false
    function load() { wanted = true }

    function items(tab: string): var { return tab === "kaomoji" ? kaomoji : tab === "symbols" ? symbols : emoji }

    // Name and shortcode matches, then tag matches; only prefix / word / substring hits (no scattered
    // letters, which would match nearly every emoji).
    function search(tab: string, query: string): var {
        const q = query.trim().toLowerCase().replace(/^:|:$/g, "")
        if (q === "") return items(tab)
        const hits = []
        for (const e of items(tab)) {
            const n = Fuzzy.match(q, e.name), c = e.code ? Fuzzy.match(q, e.code) : null
            let score = Math.max(n && n.score >= 60 ? n.score : 0, c && c.score >= 60 ? c.score - 5 : 0)
            if (score === 0 && e.tags.split(" ").some(t => t.startsWith(q))) score = 40
            if (score > 0) hits.push([score, e])
        }
        return hits.sort((a, b) => b[0] - a[0]).map(h => h[1])
    }

    function byGlyph(g: string): var { return emoji.find(e => e.glyph === g) ?? { glyph: g, name: "", tags: "", code: "" } }

    // "U+1F525" (several for sequences; the emoji-style selector FE0F is left out).
    // (QML's JS splits strings into UTF-16 units, so surrogate pairs are joined by hand.)
    function codepoints(g: string): string {
        const out = []
        for (let i = 0; i < g.length; i++) {
            let c = g.charCodeAt(i)
            if (c >= 0xD800 && c < 0xDC00 && i + 1 < g.length) c = 0x10000 + ((c - 0xD800) << 10) + (g.charCodeAt(++i) - 0xDC00)
            if (c !== 0xFE0F) out.push("U+" + c.toString(16).toUpperCase())
        }
        return out.join(" ")
    }

    FileView {
        path: root.wanted ? Quickshell.shellDir + "/data/emoji.json" : ""
        onLoaded: {
            const d = JSON.parse(text())
            root.emoji = d.emoji.map(e => ({ glyph: e[0], name: e[1], tags: e[2], code: e[3] }))
            root.kaomoji = d.kaomoji.map(e => ({ glyph: e[0], name: e[1], tags: e[1], code: "" }))
            root.symbols = d.symbols.map(e => ({ glyph: e[0], name: e[1], tags: e[1], code: "" }))
        }
    }
}
