import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    // ---- connection ----
    property alias cfg_serverUrl: serverUrlField.text
    property alias cfg_serverName: serverNameField.text
    property alias cfg_username: usernameField.text
    property alias cfg_password: passwordField.text
    property alias cfg_refreshInterval: refreshSpin.value
    property alias cfg_requestTimeoutMs: timeoutSpin.value

    // ---- appearance ----
    property int cfg_displayMode
    property alias cfg_showCpu: cpuCheck.checked
    property alias cfg_showCpuTemp: cpuTempCheck.checked
    property alias cfg_showRam: ramCheck.checked
    property alias cfg_showDisk: diskCheck.checked
    property alias cfg_showNetwork: netCheck.checked
    property alias cfg_showStatusDot: statusCheck.checked
    property alias cfg_showMiniBars: barsCheck.checked
    property string cfg_tempUnit
    property string cfg_netUnit
    property alias cfg_historyLength: historySpin.value

    // ---- behavior ----
    property string cfg_middleClickAction
    property alias cfg_skipRebootConfirm: skipRebootCheck.checked
    property alias cfg_browserCommand: browserField.text

    Kirigami.FormLayout {
        // ============ Connection ===================================
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Connection")
        }

        QQC2.TextField {
            id: serverUrlField
            Kirigami.FormData.label: i18n("Server URL:")
            placeholderText: "http://192.168.1.10  or  http://100.x.y.z"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        }

        QQC2.Label {
            Kirigami.FormData.label: " "
            text: i18n("HTTP or HTTPS. Tailscale and LAN both work — protocol is optional, http:// is added automatically.")
            wrapMode: Text.Wrap
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            opacity: 0.7
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }

        QQC2.TextField {
            id: serverNameField
            Kirigami.FormData.label: i18n("Display name:")
            placeholderText: i18n("Homelab")
        }

        QQC2.TextField {
            id: usernameField
            Kirigami.FormData.label: i18n("Username:")
            placeholderText: "casaos"
        }

        QQC2.TextField {
            id: passwordField
            Kirigami.FormData.label: i18n("Password:")
            echoMode: TextInput.Password
            placeholderText: i18n("CasaOS account password")
        }

        QQC2.SpinBox {
            id: refreshSpin
            Kirigami.FormData.label: i18n("Refresh interval:")
            from: 2
            to: 120
            stepSize: 1
            textFromValue: function(value) { return value + " s" }
            valueFromText: function(text) { return parseInt(text) }
        }

        QQC2.SpinBox {
            id: timeoutSpin
            Kirigami.FormData.label: i18n("Request timeout:")
            from: 1000
            to: 30000
            stepSize: 500
            textFromValue: function(value) { return (value / 1000).toFixed(1) + " s" }
            valueFromText: function(text) { return parseInt(parseFloat(text) * 1000) }
        }

        // ============ Panel display ================================
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel display")
        }

        QQC2.ComboBox {
            id: displayCombo
            Kirigami.FormData.label: i18n("Display style:")
            model: [
                i18n("Icons + values"),
                i18n("Values only"),
                i18n("Icons only")
            ]
            currentIndex: root.cfg_displayMode
            onActivated: function(index) { root.cfg_displayMode = index }
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        }

        QQC2.CheckBox {
            id: cpuCheck
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("CPU usage")
        }
        QQC2.CheckBox {
            id: cpuTempCheck
            text: i18n("CPU temperature")
        }
        QQC2.CheckBox {
            id: ramCheck
            text: i18n("RAM usage")
        }
        QQC2.CheckBox {
            id: diskCheck
            text: i18n("Disk usage (compact form, e.g. 245/931)")
        }
        QQC2.CheckBox {
            id: netCheck
            text: i18n("Network down / up rates")
        }
        QQC2.CheckBox {
            id: statusCheck
            text: i18n("Connection status dot")
        }
        QQC2.CheckBox {
            id: barsCheck
            text: i18n("Inline progress bars next to values")
        }

        // ============ Units ========================================
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Units")
        }

        QQC2.ComboBox {
            id: tempCombo
            Kirigami.FormData.label: i18n("Temperature:")
            model: ["°C", "°F"]
            currentIndex: root.cfg_tempUnit === "F" ? 1 : 0
            onActivated: function(index) { root.cfg_tempUnit = (index === 1 ? "F" : "C") }
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
        }

        QQC2.ComboBox {
            id: netCombo
            Kirigami.FormData.label: i18n("Network rate:")
            property var keys: ["mbps", "mbytes", "kbytes", "auto"]
            model: [i18n("Mbps"), i18n("MB/s"), i18n("KB/s"), i18n("Auto (B/K/M/G)")]
            currentIndex: Math.max(0, keys.indexOf(root.cfg_netUnit))
            onActivated: function(index) { root.cfg_netUnit = keys[index] }
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        }

        QQC2.SpinBox {
            id: historySpin
            Kirigami.FormData.label: i18n("History samples:")
            from: 15
            to: 600
            stepSize: 15
            textFromValue: function(value) { return value + " samples" }
            valueFromText: function(text) { return parseInt(text) }
        }

        // ============ Behavior =====================================
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Behavior")
        }

        QQC2.ComboBox {
            id: middleCombo
            Kirigami.FormData.label: i18n("Middle-click action:")
            property var keys: ["refresh", "dashboard", "reboot", "none"]
            model: [i18n("Refresh data"), i18n("Open dashboard"), i18n("Reboot server"), i18n("Nothing")]
            currentIndex: Math.max(0, keys.indexOf(root.cfg_middleClickAction))
            onActivated: function(index) { root.cfg_middleClickAction = keys[index] }
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        }

        QQC2.CheckBox {
            id: skipRebootCheck
            Kirigami.FormData.label: i18n("Reboot:")
            text: i18n("Skip confirmation dialog (dangerous)")
        }

        QQC2.TextField {
            id: browserField
            Kirigami.FormData.label: i18n("Browser command:")
            placeholderText: "xdg-open"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        }

        QQC2.Label {
            Kirigami.FormData.label: " "
            text: i18n("Command used to open the CasaOS dashboard URL. Defaults to xdg-open.")
            wrapMode: Text.Wrap
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            opacity: 0.7
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
