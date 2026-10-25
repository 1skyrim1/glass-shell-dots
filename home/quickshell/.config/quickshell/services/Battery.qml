pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Laptop battery (UPower). `warning` is the 5 s amber stretch of the status pill when the charge drops
// to 15 % on battery (§2 "Tinted states"). At 5 % a red critical toast that can't time out drops from the
// bell (even in DND); at 3 % on battery the laptop suspends (30-SessionStates "Critical battery").
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool present: device?.isLaptopBattery ?? false
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool pluggedIn: charging || device?.state === UPowerDeviceState.FullyCharged
    readonly property int percent: simulated >= 0 ? simulated : Math.round((device?.percentage ?? 0) * 100)
    readonly property int minutesLeft: simulated >= 0 ? simulated * 2 : Math.round((device?.timeToEmpty ?? 0) / 60)
    readonly property int lowAt: 15
    readonly property int criticalAt: 5
    readonly property int suspendAt: 3

    property bool warning: false

    // `qs ipc call battery simulate 12` fakes a charge level to try the low-battery state; -1 = real.
    property int simulated: -1

    onPercentChanged: {
        checkCritical()
        if (percent <= lowAt && percent > 0 && (!pluggedIn || simulated >= 0) && !warned) {
            warned = true
            warning = true
            hold.restart()
        } else if (percent > lowAt) {
            // Charged back up (or plugged in and the charge rose): the amber stretch goes at once.
            warned = false
            warning = false
        }
    }
    // Warn once per drop below the threshold.
    property bool warned: false

    property var criticalToast: null
    function checkCritical() {
        if (Theme.greeter) return   // the greeter only shows the level
        const draining = !pluggedIn || simulated >= 0
        if (percent <= criticalAt && percent > 0 && draining && !criticalToast) {
            criticalToast = Notifs.make({
                app: "Battery at " + percent + " %",
                body: "Suspending at " + suspendAt + " % unless you plug in",
                icon: "battery",
                critical: true,
                actions: [
                    { text: "Suspend now", run: () => Session.suspend() },
                    { text: "Saver mode", run: () => PowerProfiles.profile = PowerProfile.PowerSaver }
                ]
            })
        } else if ((percent > criticalAt || !draining) && criticalToast) {
            Notifs.dismiss(criticalToast)
            criticalToast = null
        }
        // Never for a simulated level.
        if (percent <= suspendAt && percent > 0 && !pluggedIn && simulated < 0 && !suspended) {
            suspended = true
            Session.suspend()
        } else if (percent > suspendAt) {
            suspended = false
        }
    }
    onPluggedInChanged: checkCritical()
    property bool suspended: false

    Timer {
        id: hold
        interval: Motion.warnHold
        onTriggered: root.warning = false
    }
}
