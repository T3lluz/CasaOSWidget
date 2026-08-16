pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

// Single-line panel widget, same layout language as Power Deck:
// per-metric visibility, icons+values / values / icons, optional dots.
// Order comes from Plasmoid.configuration.metricOrder so the config
// page can rearrange the chips.
//
// Click handling mirrors KDE's DefaultCompactRepresentation.qml: we write
// directly to `plasmoidItem.expanded` (passed in from main.qml) instead
// of `Plasmoid.expanded`. A dedicated clickLayer sits above the metrics
// so Text relayout cannot swallow the press. hoverEnabled is off —
// Plasma owns the tooltip via toolTipMainText/SubText on the applet.
Item {
    id: root

    required property var api
    required property var plasmoidItem

    readonly property var defaultOrder: [
        "status", "name", "cpu", "cpuTemp", "ram", "disk", "netDown", "netUp"
    ]

    readonly property var orderedIds: parseOrder(Plasmoid.configuration.metricOrder)

    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int displayMode: Plasmoid.configuration.displayMode
    readonly property bool showIcons:  displayMode !== 1
    readonly property bool showValues: displayMode !== 2
    readonly property bool sepsOn: Plasmoid.configuration.showSeparators

    readonly property bool vStatus: Plasmoid.configuration.showStatusDot
    readonly property bool vName: Plasmoid.configuration.showName
        && root.showValues
        && String(Plasmoid.configuration.serverName || "").length > 0
    readonly property bool vCpu:  Plasmoid.configuration.showCpu
    readonly property bool vTemp: Plasmoid.configuration.showCpuTemp && root.api.cpuTemp > 0
    readonly property bool vRam:  Plasmoid.configuration.showRam
    readonly property bool vDisk: Plasmoid.configuration.showDisk
    readonly property bool vNetDown: Plasmoid.configuration.showNetwork
    readonly property bool vNetUp: Plasmoid.configuration.showNetwork

    readonly property string visStamp: [
        vStatus, vName, vCpu, vTemp, vRam, vDisk, vNetDown, vNetUp
    ].join(",")

    readonly property string dataStamp: [
        api.status, api.isConnected, api.cpuPercent, api.cpuTemp,
        api.memPercent, api.diskPercent, api.diskHealthy,
        api.netRxRate, api.netTxRate, api.diskUsed, api.diskTotal,
        showIcons, showValues, Plasmoid.configuration.tempUnit,
        Plasmoid.configuration.netUnit, Plasmoid.configuration.serverName
    ].join("|")

    readonly property int panelIconSize: Math.round(
        Math.min(isVertical ? width : height, Kirigami.Units.gridUnit * 2) * 0.92)

    implicitWidth: isVertical
        ? Math.max(Kirigami.Units.gridUnit * 1.75, verticalCol.implicitWidth + Kirigami.Units.smallSpacing * 2)
        : horizontalRow.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: isVertical
        ? verticalCol.implicitHeight + Kirigami.Units.smallSpacing * 2
        : Kirigami.Units.gridUnit * 1.75

    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

    function parseOrder(raw) {
        var known = {}
        var out = []
        var parts = String(raw || "").split(",")
        for (var i = 0; i < parts.length; i++) {
            var id = parts[i].trim()
            if (id === "network") {
                if (!known["netDown"]) {
                    known["netDown"] = true
                    out.push("netDown")
                }
                if (!known["netUp"]) {
                    known["netUp"] = true
                    out.push("netUp")
                }
                continue
            }
            if (defaultOrder.indexOf(id) !== -1 && !known[id]) {
                known[id] = true
                out.push(id)
            }
        }
        for (var j = 0; j < defaultOrder.length; j++) {
            if (!known[defaultOrder[j]])
                out.push(defaultOrder[j])
        }
        return out
    }

    function slotVisible(id) {
        switch (id) {
        case "status": return vStatus
        case "name": return vName
        case "cpu": return vCpu
        case "cpuTemp": return vTemp
        case "ram": return vRam
        case "disk": return vDisk
        case "netDown": return vNetDown
        case "netUp": return vNetUp
        }
        return false
    }

    function hasVisibleBefore(index) {
        for (var i = 0; i < index; i++) {
            if (slotVisible(orderedIds[i]))
                return true
        }
        return false
    }

    function slotKind(id) {
        switch (id) {
        case "cpu": return "cpu"
        case "cpuTemp": return "temp"
        case "ram": return "ram"
        case "disk": return "disk"
        case "netDown": return "down"
        case "netUp": return "up"
        }
        return "cpu"
    }

    function slotText(id, stamp) {
        switch (id) {
        case "cpu": return api.cpuPercent >= 0 ? Math.round(api.cpuPercent) + "%" : "—"
        case "cpuTemp": return api.formatTemp(api.cpuTemp)
        case "ram": return api.memPercent >= 0 ? Math.round(api.memPercent) + "%" : "—"
        case "disk": return api.diskPairCompact()
        case "netDown": return api.formatRate(api.netRxRate)
        case "netUp": return api.formatRate(api.netTxRate)
        }
        return ""
    }

    function slotAccent(id, stamp) {
        switch (id) {
        case "cpu": return Theme.cpu
        case "cpuTemp": return Theme.temp
        case "ram": return Theme.ram
        case "disk": return api.diskHealthy ? Theme.disk : Theme.danger
        case "netDown": return Theme.netRx
        case "netUp": return Theme.netTx
        }
        return Kirigami.Theme.textColor
    }

    function slotPercent(id, stamp) {
        switch (id) {
        case "cpu": return api.cpuPercent
        case "cpuTemp": return api.cpuTemp
        case "ram": return api.memPercent
        case "disk": return api.diskPercent
        }
        return -1
    }

    function statusColor() {
        if (api.isConnected)
            return Theme.success
        if (api.status === "connecting")
            return Theme.warning
        return Theme.danger
    }

    function runMiddleAction() {
        switch (Plasmoid.configuration.middleClickAction) {
        case "dashboard":
            root.plasmoidItem.openDashboard()
            break
        case "reboot":
            if (Plasmoid.configuration.skipRebootConfirm) {
                root.api.rebootServer()
            } else {
                root.plasmoidItem.expanded = true
                root.api.requestRebootConfirm()
            }
            break
        case "none":
            break
        default:
            root.api.refresh()
        }
    }

    function midActionLabel() {
        switch (Plasmoid.configuration.middleClickAction) {
        case "dashboard": return i18n("open dashboard")
        case "reboot":    return i18n("reboot server")
        case "none":      return i18n("(nothing)")
        default:          return i18n("refresh")
        }
    }

    RowLayout {
        id: horizontalRow
        visible: !root.isVertical
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing * 1.5

        Repeater {
            model: root.orderedIds

            delegate: RowLayout {
                id: hSlot
                required property int index
                required property string modelData

                spacing: Kirigami.Units.smallSpacing
                Layout.alignment: Qt.AlignVCenter
                visible: {
                    var _ = root.visStamp
                    return root.slotVisible(hSlot.modelData)
                }

                Sep {
                    show: {
                        var _ = root.visStamp
                        return root.sepsOn && root.hasVisibleBefore(hSlot.index)
                    }
                }

                Rectangle {
                    visible: hSlot.modelData === "status"
                    Layout.alignment: Qt.AlignVCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: {
                        var _ = root.dataStamp
                        return root.statusColor()
                    }

                    SequentialAnimation on opacity {
                        running: root.api.status === "connecting"
                        loops: Animation.Infinite
                        NumberAnimation { from: 1;   to: 0.3; duration: 700 }
                        NumberAnimation { from: 0.3; to: 1;   duration: 700 }
                    }
                }

                Text {
                    visible: hSlot.modelData === "name"
                    text: {
                        var _ = root.dataStamp
                        return Plasmoid.configuration.serverName
                    }
                    color: Kirigami.Theme.textColor
                    font.weight: Font.DemiBold
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    renderType: Text.NativeRendering
                    Layout.alignment: Qt.AlignVCenter
                }

                Metric {
                    visible: hSlot.modelData !== "status" && hSlot.modelData !== "name"
                    kind: root.slotKind(hSlot.modelData)
                    valueText: root.slotText(hSlot.modelData, root.dataStamp)
                    accent: root.slotAccent(hSlot.modelData, root.dataStamp)
                    percent: root.slotPercent(hSlot.modelData, root.dataStamp)
                    showIcon: root.showIcons
                    showValue: root.showValues
                }
            }
        }
    }

    ColumnLayout {
        id: verticalCol
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: root.orderedIds

            delegate: ColumnLayout {
                id: vSlot
                required property int index
                required property string modelData

                spacing: 3
                Layout.alignment: Qt.AlignHCenter
                visible: {
                    var _ = root.visStamp
                    return root.slotVisible(vSlot.modelData)
                }

                Sep {
                    vertical: true
                    show: {
                        var _ = root.visStamp
                        return root.sepsOn && root.hasVisibleBefore(vSlot.index)
                    }
                }

                Rectangle {
                    visible: vSlot.modelData === "status"
                    Layout.alignment: Qt.AlignHCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: {
                        var _ = root.dataStamp
                        return root.statusColor()
                    }
                }

                Text {
                    visible: vSlot.modelData === "name"
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        var _ = root.dataStamp
                        return Plasmoid.configuration.serverName
                    }
                    color: Kirigami.Theme.textColor
                    font.weight: Font.DemiBold
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    renderType: Text.NativeRendering
                }

                VMetric {
                    visible: vSlot.modelData !== "status" && vSlot.modelData !== "name"
                    kind: root.slotKind(vSlot.modelData)
                    valueText: root.slotText(vSlot.modelData, root.dataStamp)
                    accent: root.slotAccent(vSlot.modelData, root.dataStamp)
                    showIcon: root.showIcons
                    showValue: root.showValues
                }
            }
        }
    }

    MouseArea {
        id: clickLayer
        anchors.fill: parent
        z: 1000
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        property bool wasExpanded: false

        onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = false
                return
            }
            wasExpanded = root.plasmoidItem.expanded
        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = false
                return
            }
            if (mouse.button === Qt.MiddleButton) {
                root.runMiddleAction()
                return
            }
            root.plasmoidItem.expanded = !wasExpanded
        }
        onReleased: function(mouse) {
            if (mouse.button === Qt.RightButton)
                mouse.accepted = false
        }
    }

    component Sep: Rectangle {
        property bool show: false
        property bool vertical: false
        visible: show
        implicitWidth: 3
        implicitHeight: 3
        radius: 1.5
        color: Theme.muted
        Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    }

    component Metric: RowLayout {
        id: m
        required property string kind
        required property string valueText
        required property color accent
        property real percent: -1
        property bool showIcon: true
        property bool showValue: true

        Layout.alignment: Qt.AlignVCenter
        spacing: Kirigami.Units.smallSpacing

        MetricIcon {
            visible: m.showIcon
            kind: m.kind
            color: m.accent
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.panelIconSize
            Layout.preferredHeight: root.panelIconSize
        }

        Text {
            visible: m.showValue
            text: m.valueText
            color: Kirigami.Theme.textColor
            font.weight: Font.DemiBold
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            renderType: Text.NativeRendering
        }

        Rectangle {
            visible: Plasmoid.configuration.showMiniBars && m.percent >= 0
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
            Layout.preferredHeight: 4
            radius: 2
            color: Theme.alpha(Kirigami.Theme.textColor, 0.12)
            Layout.leftMargin: 2

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, m.percent / 100))
                height: parent.height
                radius: parent.radius
                color: m.accent
                Behavior on width { NumberAnimation { duration: 400; easing.type: Theme.easeOut } }
            }
        }
    }

    component VMetric: ColumnLayout {
        id: vm
        required property string kind
        required property string valueText
        required property color accent
        property bool showIcon: true
        property bool showValue: true

        Layout.alignment: Qt.AlignHCenter
        spacing: 0

        MetricIcon {
            visible: vm.showIcon
            kind: vm.kind
            color: vm.accent
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.panelIconSize
            Layout.preferredHeight: root.panelIconSize
        }
        Text {
            visible: vm.showValue
            Layout.alignment: Qt.AlignHCenter
            text: vm.valueText
            color: Kirigami.Theme.textColor
            font.weight: Font.DemiBold
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            renderType: Text.NativeRendering
        }
    }
}
