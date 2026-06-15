pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Single-line panel widget.
//
// Click handling mirrors KDE's DefaultCompactRepresentation.qml: we write
// directly to `plasmoidItem.expanded` (passed in from main.qml) instead
// of `Plasmoid.expanded`. The attached property mostly works the same,
// but a small subset of Plasma 6 setups don't propagate the write to
// the popup window — using the PlasmoidItem instance is the documented
// pattern in plasma-desktop and is what every shipped applet uses.
//
// On top of that, a dedicated `clickLayer` MouseArea is anchored over
// the whole widget as the last child so animating Text/Rectangle nodes
// can never swallow the press, plus a TapHandler is registered as a
// belt-and-braces fallback for the rare case where MouseArea events
// don't propagate (see KDE bug 518024).
Item {
    id: root

    required property var api
    required property var theme
    required property var plasmoidItem      // PlasmoidItem instance from main.qml

    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int displayMode: Plasmoid.configuration.displayMode  // 0 = icons+values, 1 = values only, 2 = icons only
    readonly property bool showIcons:  displayMode !== 1
    readonly property bool showValues: displayMode !== 2

    implicitWidth: isVertical
        ? Math.max(Kirigami.Units.gridUnit * 2.5, verticalCol.implicitWidth + Kirigami.Units.smallSpacing * 2)
        : horizontalRow.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: isVertical
        ? verticalCol.implicitHeight + Kirigami.Units.smallSpacing * 2
        : Math.max(Kirigami.Units.gridUnit * 1.6, horizontalRow.implicitHeight)

    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

    // ---- click handling --------------------------------------------
    function toggleExpanded() {
        root.plasmoidItem.expanded = !root.plasmoidItem.expanded
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

    // --- horizontal layout ----------------------------------------------
    RowLayout {
        id: horizontalRow
        visible: !root.isVertical
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing * 1.5

        Rectangle {
            visible: Plasmoid.configuration.showStatusDot
            Layout.alignment: Qt.AlignVCenter
            width: 8; height: 8; radius: 4
            color: root.api.isConnected ? root.theme.success
                : (root.api.status === "connecting" ? root.theme.warning : root.theme.danger)

            SequentialAnimation on opacity {
                running: root.api.status === "connecting"
                loops: Animation.Infinite
                NumberAnimation { from: 1;   to: 0.3; duration: 700 }
                NumberAnimation { from: 0.3; to: 1;   duration: 700 }
            }
        }

        Metric {
            visible: Plasmoid.configuration.showCpu
            theme: root.theme
            kind: "cpu"
            valueText: root.api.cpuPercent >= 0 ? Math.round(root.api.cpuPercent) + "%" : "—"
            percent: root.api.cpuPercent
            accent: root.theme.cpu
            showIcon: root.showIcons
            showValue: root.showValues
        }

        Metric {
            visible: Plasmoid.configuration.showCpuTemp && root.api.cpuTemp > 0
            theme: root.theme
            kind: "cpu"
            valueText: root.api.formatTemp(root.api.cpuTemp)
            accent: root.theme.warning
            showIcon: false
            showValue: root.showValues
        }

        Metric {
            visible: Plasmoid.configuration.showRam
            theme: root.theme
            kind: "ram"
            valueText: root.api.memPercent >= 0 ? Math.round(root.api.memPercent) + "%" : "—"
            percent: root.api.memPercent
            accent: root.theme.ram
            showIcon: root.showIcons
            showValue: root.showValues
        }

        Metric {
            visible: Plasmoid.configuration.showDisk
            theme: root.theme
            kind: "disk"
            valueText: root.api.diskPairCompact()
            percent: root.api.diskPercent
            accent: root.api.diskHealthy ? root.theme.disk : root.theme.danger
            showIcon: root.showIcons
            showValue: root.showValues
        }

        Metric {
            visible: Plasmoid.configuration.showNetwork
            theme: root.theme
            kind: "down"
            valueText: root.api.formatRate(root.api.netRxRate)
            accent: root.theme.netRx
            showIcon: root.showIcons
            showValue: root.showValues
        }

        Metric {
            visible: Plasmoid.configuration.showNetwork
            theme: root.theme
            kind: "up"
            valueText: root.api.formatRate(root.api.netTxRate)
            accent: root.theme.netTx
            showIcon: root.showIcons
            showValue: root.showValues
        }
    }

    // --- vertical layout (rotated panel) --------------------------------
    ColumnLayout {
        id: verticalCol
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: 3

        Rectangle {
            visible: Plasmoid.configuration.showStatusDot
            Layout.alignment: Qt.AlignHCenter
            width: 8; height: 8; radius: 4
            color: root.api.isConnected ? root.theme.success
                : (root.api.status === "connecting" ? root.theme.warning : root.theme.danger)
        }
        VMetric {
            visible: Plasmoid.configuration.showCpu
            theme: root.theme; kind: "cpu"; accent: root.theme.cpu
            valueText: root.api.cpuPercent >= 0 ? Math.round(root.api.cpuPercent) + "%" : "—"
            showIcon: root.showIcons; showValue: root.showValues
        }
        VMetric {
            visible: Plasmoid.configuration.showCpuTemp && root.api.cpuTemp > 0
            theme: root.theme; kind: "cpu"; accent: root.theme.warning
            valueText: root.api.formatTemp(root.api.cpuTemp)
            showIcon: false; showValue: root.showValues
        }
        VMetric {
            visible: Plasmoid.configuration.showRam
            theme: root.theme; kind: "ram"; accent: root.theme.ram
            valueText: root.api.memPercent >= 0 ? Math.round(root.api.memPercent) + "%" : "—"
            showIcon: root.showIcons; showValue: root.showValues
        }
        VMetric {
            visible: Plasmoid.configuration.showDisk
            theme: root.theme; kind: "disk"; accent: root.theme.disk
            valueText: root.api.diskPairCompact()
            showIcon: root.showIcons; showValue: root.showValues
        }
        VMetric {
            visible: Plasmoid.configuration.showNetwork
            theme: root.theme; kind: "down"; accent: root.theme.netRx
            valueText: root.api.formatRate(root.api.netRxRate)
            showIcon: root.showIcons; showValue: root.showValues
        }
        VMetric {
            visible: Plasmoid.configuration.showNetwork
            theme: root.theme; kind: "up"; accent: root.theme.netTx
            valueText: root.api.formatRate(root.api.netTxRate)
            showIcon: root.showIcons; showValue: root.showValues
        }
    }

    // --- click overlay --------------------------------------------------
    // Sits above the metric layouts so re-laying-out Text nodes can't
    // swallow the press. Sampled-on-press avoids the popup-dismiss race
    // (Plasma closes the popup on the press that precedes our click,
    // so we toggle from the *pressed* state, not the current one).
    MouseArea {
        id: clickLayer
        anchors.fill: parent
        z: 1000
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        property bool wasExpanded: false

        onPressed: function(mouse) {
            wasExpanded = root.plasmoidItem.expanded
        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                root.runMiddleAction()
                return
            }
            root.plasmoidItem.expanded = !wasExpanded
        }

        // TapHandler fallback — TapHandler uses Qt's pointer event API
        // which propagates through QML items the legacy MouseArea filter
        // sometimes misses (see KDE bug 518024 for the Kirigami.Icon
        // event-absorption variant of this problem).
        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: root.toggleExpanded()
        }

        PC3.ToolTip.visible: containsMouse && !root.plasmoidItem.expanded
        PC3.ToolTip.delay: 600
        PC3.ToolTip.text: {
            if (!root.api.isConfigured) return i18n("Click to configure CasaOS Homelab")
            if (root.api.isConnected) {
                return i18n("%1 · CasaOS %2\nCPU %3%   RAM %4%   Disk %5\n↓ %6   ↑ %7\nClick to expand · middle-click to %8",
                    Plasmoid.configuration.serverName || i18n("Homelab"),
                    root.api.casaVersion || "?",
                    Math.round(root.api.cpuPercent),
                    Math.round(root.api.memPercent),
                    root.api.diskPairText(),
                    root.api.formatRate(root.api.netRxRate),
                    root.api.formatRate(root.api.netTxRate),
                    root.midActionLabel())
            }
            return root.api.statusMessage || i18n("Disconnected")
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

    // ---- shared metric chip (horizontal) -------------------------------
    component Metric: RowLayout {
        id: m
        required property var theme
        required property string kind
        required property string valueText
        required property color accent
        property real percent: -1
        property bool showIcon: true
        property bool showValue: true

        Layout.alignment: Qt.AlignVCenter
        spacing: 4

        MetricIcon {
            visible: m.showIcon
            kind: m.kind
            color: m.accent
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }

        Text {
            visible: m.showValue
            text: m.valueText
            color: m.theme.text
            font.weight: Font.Bold
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            renderType: Text.NativeRendering
        }

        Rectangle {
            visible: Plasmoid.configuration.showMiniBars && m.percent >= 0
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
            Layout.preferredHeight: 4
            radius: 2
            color: m.theme.trackBg
            Layout.leftMargin: 2

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, m.percent / 100))
                height: parent.height
                radius: parent.radius
                color: m.accent
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    // ---- shared metric chip (vertical) ---------------------------------
    component VMetric: ColumnLayout {
        id: vm
        required property var theme
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
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        Text {
            visible: vm.showValue
            Layout.alignment: Qt.AlignHCenter
            text: vm.valueText
            color: vm.accent
            font.weight: Font.Bold
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            renderType: Text.NativeRendering
        }
    }
}
