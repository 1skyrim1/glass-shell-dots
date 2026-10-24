pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Bluetooth (bluez through Quickshell.Bluetooth) for the Control Center: the adapter, its devices, scanning
// and pairing. Quickshell has no pairing agent, so while the Wi-Fi & Bluetooth page is open a bluetoothctl
// runs as bluez's default agent; it prints the code the other device wants ("Passkey: 482913") or asks to
// confirm one ("Confirm passkey 482913 (yes/no)"), which the pairing card shows (17-ControlPages).
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false
    readonly property var all: adapter?.devices.values ?? []
    readonly property var connected: all.filter(d => d.connected)

    function toggle() { if (adapter) adapter.enabled = !adapter.enabled }
    function setScanning(on: bool) { if (adapter && adapter.enabled && adapter.discovering !== on) adapter.discovering = on }

    // New devices (found by a scan, with a real name) first: they slide in at the top. Then connected, then
    // paired ones. The device being paired stays in the list even if it stops advertising.
    function named(d: var): bool { return d.name !== "" && d.name.replace(/[-:]/g, "") !== d.address.replace(/:/g, "") }
    readonly property var devices: all
        .filter(d => d.paired || d.connected || (named(d) && (scanning || d === pairingDevice)))
        .sort((a, b) => (a.paired - b.paired) || (b.connected - a.connected) || a.name.localeCompare(b.name))

    // "Headphones · 80 %"
    function batteryOf(d: var): string { return d?.batteryAvailable ? Math.round(d.battery * 100) + " %" : "" }
    // Lucide icon for bluez's device icon name.
    function iconOf(d: var): string {
        const i = d?.icon ?? ""
        return i.startsWith("audio") ? "headphones" : i === "input-keyboard" ? "keyboard" : i === "input-mouse" ? "mouse"
             : i === "input-gaming" ? "gamepad" : i.startsWith("phone") ? "app-window" : "bluetooth"
    }

    // Enter on a row: connect or disconnect a paired device, pair a new one.
    function activate(d: var) {
        if (!d) return
        if (!d.paired) pair(d)
        else if (d.connected) d.disconnect()
        else d.connect()
    }
    function forget(d: var) { if (d?.paired) d.forget() }

    // --- Pairing
    property var pairingDevice: null
    property string pairCode: ""        // the code to type / compare
    property bool needsConfirm: false   // the code has to be confirmed here ("Pair" instead of "Waiting…")
    property bool agentWanted: false    // the page that can pair is open

    function pair(d: var) {
        cancelPair()
        pairingDevice = d
        d.pair()
    }
    function cancelPair() {
        if (pairingDevice?.pairing) pairingDevice.cancelPair()
        if (needsConfirm) agent.write("no\n")
        pairingDevice = null
        pairCode = ""
        needsConfirm = false
    }
    function confirm() {
        if (!needsConfirm) return
        agent.write("yes\n")
        needsConfirm = false
    }

    // Paired: trust it (so it reconnects by itself) and connect.
    readonly property bool pairedNow: pairingDevice?.paired ?? false
    onPairedNowChanged: {
        const d = pairingDevice
        if (!pairedNow || !d) return
        d.trusted = true
        d.connect()
        pairingDevice = null
        pairCode = ""
        needsConfirm = false
    }
    // Pairing ended without success (refused, timed out, cancelled on the device).
    readonly property bool pairingNow: pairingDevice?.pairing ?? false
    onPairingNowChanged: if (pairingDevice && !pairingNow && !pairedNow) failTimer.restart()
    // bluez flips `pairing` off a moment before `paired` on; only give up if it stays unpaired.
    Timer {
        id: failTimer
        interval: 800
        onTriggered: if (root.pairingDevice && !root.pairingDevice.pairing && !root.pairingDevice.paired) root.cancelPair()
    }

    Process {
        id: agent
        running: root.agentWanted && root.enabled
        command: ["bluetoothctl", "--agent", "KeyboardDisplay"]
        stdinEnabled: true
        onStarted: write("default-agent\n")
        // Prompts end without a newline, so read raw chunks and keep a short tail to match across them.
        property string tail: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                const text = (agent.tail + data).replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/\r/g, "\n")
                agent.tail = text.slice(-200)
                let m
                if ((m = text.match(/Confirm passkey (\d+)[^\n]*$/))) {
                    root.pairCode = m[1].padStart(6, "0")
                    root.needsConfirm = true
                    agent.tail = ""
                } else if ((m = text.match(/(?:Passkey|PIN code): (\w+)[^\n]*$/m))) {
                    root.pairCode = /^\d+$/.test(m[1]) ? m[1].padStart(6, "0") : m[1]
                    agent.tail = ""
                } else if (/(Request authorization|Authorize service)[^\n]*\(yes\/no\)/.test(text)) {
                    // Only ever for a device we asked to pair (or one already paired).
                    agent.write("yes\n")
                    agent.tail = ""
                }
            }
        }
    }
}
