pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

// Wi-Fi (NetworkManager through Quickshell.Networking) for the status pill and the Control Center, plus
// airplane mode: Wi-Fi and Bluetooth off together, and turning it off brings back what was on before.
Singleton {
    id: root

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool enabled: Networking.wifiEnabled
    readonly property var network: device?.networks.values.find(n => n.connected) ?? null
    // Signal: 0 = off / not connected, else 1–4 arcs.
    readonly property int bars: !enabled || !network ? 0 : barsOf(network)
    readonly property string tip: bars > 0
        ? (network?.name ?? "Wi-Fi") + " · " + ["weak", "fair", "good", "strong"][bars - 1] + " signal"
        : enabled ? "Wi-Fi · not connected" : "Wi-Fi off"

    function barsOf(n: var): int { return Math.max(1, Math.min(4, Math.ceil((n?.signalStrength ?? 0) * 4))) }
    function iconOf(n: var): string { const b = barsOf(n); return b === 4 ? "wifi" : "wifi-" + b }
    function secured(n: var): bool {
        return n?.security !== undefined && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe
    }
    // Enterprise networks need more than a password; they can only be joined once NetworkManager knows them.
    function enterprise(n: var): bool {
        return [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.Leap,
                WifiSecurityType.DynamicWep].includes(n?.security)
    }
    function securityLabel(n: var): string {
        switch (n?.security) {
        case WifiSecurityType.Sae: return "WPA3"
        case WifiSecurityType.Wpa2Psk: return "WPA2"
        case WifiSecurityType.WpaPsk: return "WPA"
        case WifiSecurityType.StaticWep: return "WEP"
        case WifiSecurityType.Open: case WifiSecurityType.Owe: return "open"
        default: return enterprise(n) ? "802.1X" : ""
        }
    }

    // Connected first, then saved ones, then by signal. Hidden networks (no name) are left out.
    readonly property var networks: (device?.networks.values ?? [])
        .filter(n => n.name !== "")
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

    // The network page keeps the scanner on while it's shown.
    function setScanning(on: bool) { if (device) device.scannerEnabled = on }

    function toggle() { Networking.wifiEnabled = !Networking.wifiEnabled }

    // Last failure, shown under the network's row ("Wrong password for Home-5G").
    property string failedName: ""
    property string failText: ""
    function clearError() { failedName = ""; failText = "" }

    // A password attempt that fails is forgotten again, so NetworkManager doesn't keep a profile with the
    // wrong key and the row asks again.
    property string pskTried: ""
    function connect(n: var, psk: string) {
        clearError()
        if (psk !== "") {
            pskTried = n.name
            n.connectWithPsk(psk)
        } else {
            pskTried = ""
            n.connect()
        }
    }
    function disconnect(n: var) { n.disconnect() }
    function forget(n: var) { n.forget() }

    Instantiator {
        model: root.device?.networks ?? null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                const wrongKey = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiClientFailed
                                 || reason === ConnectionFailReason.WifiAuthTimeout
                root.failedName = modelData.name
                root.failText = wrongKey && root.secured(modelData) ? "Wrong password for " + modelData.name
                                                                    : "Couldn't connect to " + modelData.name
                if (root.pskTried === modelData.name && modelData.known) modelData.forget()
                root.pskTried = ""
            }
            function onConnectedChanged() { if (modelData.connected && root.failedName === modelData.name) root.clearError() }
        }
    }

    // --- Airplane mode
    readonly property var adapter: Bluetooth.defaultAdapter
    property bool airplane: false
    property bool savedWifi: true
    property bool savedBluetooth: true
    function setAirplane(on: bool) {
        if (on === airplane) return
        if (on) {
            savedWifi = enabled
            savedBluetooth = adapter?.enabled ?? false
            airplane = true
            Networking.wifiEnabled = false
            if (adapter) adapter.enabled = false
        } else {
            airplane = false
            Networking.wifiEnabled = savedWifi
            if (adapter) adapter.enabled = savedBluetooth
        }
    }
    // Turning a radio back on by hand ends airplane mode.
    onEnabledChanged: if (enabled && airplane) airplane = false
    readonly property bool bluetoothOn: adapter?.enabled ?? false
    onBluetoothOnChanged: if (bluetoothOn && airplane) airplane = false
}
