pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Laptop battery (UPower). `warning` is the 5 s amber stretch of the status pill when the charge drops
// to 15 % on battery (§2 "Tinted states").
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool present: device?.isLaptopBattery ?? false
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool pluggedIn: charging || device?.state === UPowerDeviceState.FullyCharged
    readonly property int percent: simulated >= 0 ? simulated : Math.round((device?.percentage ?? 0) * 100)
    readonly property int minutesLeft: simulated >= 0 ? simulated * 2 : Math.round((device?.timeToEmpty ?? 0) / 60)
    readonly property int lowAt: 15

    property bool warning: false

    // `qs ipc call battery simulate 12` fakes a charge level to try the low-battery state; -1 = real.
    property int simulated: -1

    onPercentChanged: {
        if (percent <= lowAt && percent > 0 && (!pluggedIn || simulated >= 0) && !warned) {
            warned = true
            warning = true
            hold.restart()
        } else if (percent > lowAt) {
            warned = false
        }
    }
    // Warn once per drop below the threshold.
    property bool warned: false

    Timer {
        id: hold
        interval: Motion.warnHold
        onTriggered: root.warning = false
    }
}
