.pragma library

// Fuzzy matching for the launcher. match() scores `text` against `query` and returns the matched
// character indices (drawn in accent 700), or null. Better: prefix > word start > substring > letters
// in order (preferring word starts). Case-insensitive.

const wordBreak = /[\s\-_.·/:()]/

function match(query, text) {
    const q = (query || "").toLowerCase(), t = (text || "").toLowerCase()
    if (q === "") return { score: 0, indices: [] }
    const run = (from, n) => Array.from({ length: n }, (_, i) => from + i)

    if (t.startsWith(q)) return { score: 100 - Math.min(20, t.length - q.length) * 0.2, indices: run(0, q.length) }
    for (let i = t.indexOf(q); i !== -1; i = t.indexOf(q, i + 1))
        if (wordBreak.test(t[i - 1])) return { score: 80 - i * 0.2, indices: run(i, q.length) }
    const sub = t.indexOf(q)
    if (sub !== -1) return { score: 60 - sub * 0.5, indices: run(sub, q.length) }

    // Letters in order: take each one at the next word start if there is one, else the next occurrence.
    const indices = []
    let at = 0, starts = 0
    for (const c of q) {
        if (c === " ") continue
        let found = -1
        for (let i = at; i < t.length; i++) {
            if (t[i] !== c) continue
            if (found === -1) found = i
            if (i === 0 || wordBreak.test(t[i - 1])) { found = i; starts++; break }
        }
        if (found === -1) return null
        indices.push(found)
        at = found + 1
    }
    const spread = indices[indices.length - 1] - indices[0] - indices.length + 1
    return { score: 30 + starts * 4 - spread * 0.5, indices: indices }
}

// Rich text with the matched characters in `color`, bold. For Text.StyledText.
function highlight(text, indices, color) {
    const set = new Set(indices || [])
    let out = "", open = false
    for (let i = 0; i < text.length; i++) {
        const hit = set.has(i)
        if (hit !== open) { out += hit ? `<font color="${color}"><b>` : "</b></font>"; open = hit }
        out += escape(text[i])
    }
    return open ? out + "</b></font>" : out
}

function escape(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}
