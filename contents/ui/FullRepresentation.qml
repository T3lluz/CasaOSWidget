pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Minimal, modern, data-rich popup styled to the Power-Deck app pack.
// No opaque background of our own — we sit on the Plasma popup's
// `backgroundColor` and layer translucent text-tinted cards on top, so
// the look follows the user's color scheme (THEME_GUIDE §2). All colors,
// type and motion route through the `Theme` singleton + `Kirigami.*`.
PlasmaExtras.Representation {
    id: root

    required property var api
    required property var plasmoidItem

    collapseMarginsHint: true

    // Landscape dashboard: ~4:3 (wider than tall) so the popup uses
    // horizontal space instead of stacking every card into a tall strip.
    readonly property int edgeMargin: Kirigami.Units.smallSpacing * 1.5
    readonly property int graphHeight: Kirigami.Units.gridUnit * 2.6
    readonly property int popupWidth: Kirigami.Units.gridUnit * 40
    // Two visible app rows; extra apps scroll inside the card.
    readonly property int appsMaxHeight: Kirigami.Units.gridUnit * 6.4
    readonly property int popupContentHeight: body.implicitHeight
    Layout.preferredWidth: popupWidth
    Layout.minimumWidth: Kirigami.Units.gridUnit * 34
    Layout.maximumWidth: Kirigami.Units.gridUnit * 48
    Layout.preferredHeight: popupContentHeight
    Layout.minimumHeight: popupContentHeight
    Layout.maximumHeight: popupContentHeight
    implicitHeight: popupContentHeight
    implicitWidth: popupWidth

    // --- background ------------------------------------------------------
    // Intentionally NO background element. We let the Plasma popup style
    // provide its own translucent, blurred dialog background (same as
    // Power-Deck, THEME_GUIDE §2) and only layer faint text-tinted cards
    // on top. Painting an opaque Rectangle here would defeat the blur and
    // make the popup look flat/solid instead of matching the Plasma theme.

    // --- restart confirmation -------------------------------------------
    Kirigami.PromptDialog {
        id: rebootDialog
        title: i18n("Reboot %1?", Plasmoid.configuration.serverName || i18n("server"))
        subtitle: i18n("This will send a reboot signal to CasaOS. The widget will reconnect once the server is back online.")
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: i18n("Reboot")
                icon.name: "system-reboot"
                onTriggered: {
                    rebootDialog.close()
                    root.api.rebootServer()
                }
            }
        ]
    }

    function triggerReboot() {
        if (Plasmoid.configuration.skipRebootConfirm) {
            root.api.rebootServer()
        } else {
            rebootDialog.open()
        }
    }

    Connections {
        target: root.api
        function onRebootConfirmRequested() {
            root.triggerReboot()
        }
    }

    // --- temporary status toast (after reboot / errors) ------------------
    Rectangle {
        id: toast
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Kirigami.Units.largeSpacing
        z: 99
        radius: Kirigami.Units.smallSpacing * 1.5
        color: Kirigami.Theme.backgroundColor
        border.color: Theme.alpha(toast.success ? Theme.green : Theme.red, 0.45)
        border.width: 1
        opacity: 0
        visible: opacity > 0
        implicitWidth: toastLabel.implicitWidth + Kirigami.Units.largeSpacing * 2
        implicitHeight: toastLabel.implicitHeight + Kirigami.Units.smallSpacing * 2

        property string message: ""
        property bool success: true

        Text {
            id: toastLabel
            anchors.centerIn: parent
            text: (toast.success ? "✓  " : "✗  ") + toast.message
            color: toast.success ? Theme.green : Theme.red
            font.weight: Font.DemiBold
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            renderType: Text.NativeRendering
        }

        Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
    }
    Timer {
        id: toastHide
        interval: 4500
        onTriggered: toast.opacity = 0
    }
    Connections {
        target: root.api
        function onRestartRequested(success, message) {
            toast.success = success
            toast.message = message
            toast.opacity = 1
            toastHide.restart()
        }
    }

    // --- shared building blocks -----------------------------------------
    // The single most important primitive (THEME_GUIDE §2): a faint
    // text-tinted card that reads as "lifted" on any color scheme.
    component SectionCard: Rectangle {
        id: cardRoot
        default property alias content: inner.data
        property string title: ""
        // §5e section header: a recolored glyph badge + uppercase title and
        // an optional right-aligned value chip.
        property string iconKind: ""
        property color glyphColor: Theme.iconHeader
        property string trailingText: ""
        property color trailingColor: Theme.success

        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.smallSpacing * 1.5
        color: Theme.alpha(Kirigami.Theme.textColor, 0.045)
        border.width: 1
        border.color: Theme.alpha(Kirigami.Theme.textColor, 0.08)

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                visible: cardRoot.title.length > 0
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                spacing: Kirigami.Units.smallSpacing * 1.5

                MetricIcon {
                    visible: cardRoot.iconKind.length > 0
                    kind: cardRoot.iconKind
                    color: cardRoot.glyphColor
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 1.1)
                    Layout.preferredHeight: Layout.preferredWidth
                }

                Text {
                    text: cardRoot.title.toUpperCase()
                    color: Kirigami.Theme.textColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6
                    renderType: Text.NativeRendering
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: cardRoot.trailingText.length > 0
                    text: cardRoot.trailingText
                    color: cardRoot.trailingColor
                    font.weight: Font.Bold
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    renderType: Text.NativeRendering
                }
            }

            ColumnLayout {
                id: inner
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing
            }
        }
    }

    component KeyValueRow: RowLayout {
        id: kv
        required property string label
        required property string value
        property string valueColor: ""

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Text {
            text: kv.label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            renderType: Text.NativeRendering
        }
        Item { Layout.fillWidth: true }
        Text {
            text: kv.value.length ? kv.value : "—"
            color: kv.valueColor.length ? kv.valueColor : Kirigami.Theme.textColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 12
            renderType: Text.NativeRendering
        }
    }

    // A labelled sparkline sitting on its own inset background, so adjacent
    // graphs read as clearly separate panels.
    component LabeledGraph: ColumnLayout {
        id: lg
        property string label: ""
        property color accent: Kirigami.Theme.textColor
        property string valueText: ""
        property alias samples: lgSpark.samples
        property bool autoScale: false
        property real chartHeight: root.graphHeight

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 1
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Text {
                text: lg.label
                color: lg.accent
                font.weight: Font.DemiBold
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                renderType: Text.NativeRendering
            }
            Item { Layout.fillWidth: true }
            Text {
                text: lg.valueText
                color: Kirigami.Theme.textColor
                font.weight: Font.Bold
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: lg.chartHeight
            Layout.minimumHeight: lg.chartHeight
            radius: Kirigami.Units.smallSpacing * 1.25
            color: Theme.alpha(Kirigami.Theme.textColor, 0.05)
            border.width: 1
            border.color: Theme.alpha(Kirigami.Theme.textColor, 0.08)
            clip: true

            SparklineChart {
                id: lgSpark
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                lineColor: lg.accent
                gridColor: Theme.alpha(Kirigami.Theme.textColor, 0.08)
                baselineColor: Theme.alpha(Kirigami.Theme.textColor, 0.12)
                autoScale: lg.autoScale
            }
        }
    }

    component HeaderButton: Rectangle {
        id: hb
        required property string kind
        property string tip: ""
        property color accent: Kirigami.Theme.textColor
        signal clicked()

        Layout.preferredWidth: Kirigami.Units.iconSizes.medium + 6
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium + 6
        radius: Kirigami.Units.smallSpacing * 1.25
        color: hbArea.containsMouse ? Theme.alpha(Kirigami.Theme.textColor, 0.07) : "transparent"
        border.width: 1
        border.color: hbArea.containsMouse ? Theme.alpha(Kirigami.Theme.textColor, 0.12) : "transparent"
        scale: hbArea.pressed ? 0.94 : 1.0

        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }

        MetricIcon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            kind: hb.kind
            color: hbArea.containsMouse ? hb.accent : Kirigami.Theme.disabledTextColor
        }

        MouseArea {
            id: hbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hb.clicked()
        }

        PC3.ToolTip.visible: hbArea.containsMouse && hb.tip.length > 0
        PC3.ToolTip.delay: 400
        PC3.ToolTip.text: hb.tip
    }

    // --- main scrollable body -------------------------------------------
    QQC2.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

        RowLayout {
            id: body
            width: parent.width
            spacing: Kirigami.Units.smallSpacing

            // ---- left gauge rail (full height) ----------------------
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7.5
                Layout.maximumWidth: Kirigami.Units.gridUnit * 8.5
                Layout.leftMargin: root.edgeMargin
                Layout.topMargin: root.edgeMargin
                Layout.bottomMargin: root.edgeMargin
                implicitHeight: Kirigami.Units.gridUnit * 22
                radius: Kirigami.Units.smallSpacing * 1.5
                color: Theme.alpha(Kirigami.Theme.textColor, 0.045)
                border.width: 1
                border.color: Theme.alpha(Kirigami.Theme.textColor, 0.08)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: 0

                    GaugeRing {
                        label: i18n("CPU")
                        percent: root.api.cpuPercent
                        accentColor: Theme.cpu
                        subText: {
                            var parts = []
                            if (root.api.cpuTemp > 0) parts.push(root.api.formatTemp(root.api.cpuTemp))
                            if (root.api.cpuCores > 0) parts.push(i18n("%1 cores", root.api.cpuCores))
                            if (root.api.cpuWatts > 0) parts.push(root.api.formatWatts(root.api.cpuWatts))
                            return parts.join(" · ")
                        }
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 1
                    }
                    GaugeRing {
                        label: i18n("RAM")
                        percent: root.api.memPercent
                        accentColor: Theme.ram
                        centerText: root.api.memPercent >= 0 ? Math.round(root.api.memPercent) + "%" : "—"
                        subText: root.api.memTotal > 0
                            ? root.api.formatBytesShort(root.api.memUsed) + "/" + root.api.formatBytesShort(root.api.memTotal)
                            : ""
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 1
                    }
                    GaugeRing {
                        label: i18n("DISK")
                        percent: root.api.diskPercent
                        accentColor: root.api.diskHealthy ? Theme.disk : Theme.danger
                        centerText: root.api.diskPairText()
                        subText: root.api.diskHealthy
                            ? (root.api.diskTotal > 0
                                ? i18n("%1 free", root.api.formatBytesShort(root.api.diskAvail || (root.api.diskTotal - root.api.diskUsed)))
                                : "")
                            : i18n("Health warning")
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 1
                    }
                }
            }

            // ---- right stack: header, system+graphs, apps -----------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.rightMargin: root.edgeMargin
                Layout.topMargin: root.edgeMargin
                Layout.bottomMargin: root.edgeMargin
                spacing: Kirigami.Units.smallSpacing

            // ---- header ---------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.smallSpacing * 1.5
                color: Theme.alpha(Kirigami.Theme.textColor, 0.045)
                border.width: 1
                border.color: Theme.alpha(Kirigami.Theme.textColor, 0.08)

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing * 1.5

                    // server avatar with status ring
                    Item {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium + 8
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium + 8

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Theme.alpha(Kirigami.Theme.textColor, 0.07)
                            border.width: 2
                            border.color: root.api.isConnected ? Theme.success
                                : (root.api.status === "connecting" ? Theme.warning : Theme.danger)
                            Behavior on border.color { ColorAnimation { duration: Theme.durMed; easing.type: Theme.easeOut } }
                        }
                        MetricIcon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.medium
                            height: width
                            kind: "server"
                            color: Kirigami.Theme.textColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        // eyebrow wordmark — ties the pack together
                        Text {
                            text: i18n("CASAOS")
                            color: Theme.muted
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2.2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: Plasmoid.configuration.serverName || i18n("CasaOS Homelab")
                            color: Kirigami.Theme.textColor
                            font.weight: Font.Bold
                            font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.15)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            renderType: Text.NativeRendering
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: root.api.isConnected ? Theme.success
                                    : (root.api.status === "connecting" ? Theme.warning : Theme.danger)
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on color { ColorAnimation { duration: Theme.durMed; easing.type: Theme.easeOut } }
                            }
                            Text {
                                text: root.api.isConnected
                                    ? i18n("Connected · CasaOS %1", root.api.casaVersion || "?")
                                    : (root.api.status === "connecting"
                                        ? i18n("Connecting…")
                                        : (root.api.statusMessage || i18n("Disconnected")))
                                color: root.api.isConnected ? Theme.success
                                    : (root.api.status === "connecting" ? Theme.warning : Theme.danger)
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: root.api.lastUpdateMs > 0
                                text: "·  " + Qt.formatTime(new Date(root.api.lastUpdateMs), "HH:mm:ss")
                                color: Theme.muted
                                opacity: 0.7
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                renderType: Text.NativeRendering
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }

                    HeaderButton {
                        kind: "refresh"
                        tip: i18n("Refresh now")
                        accent: Theme.iconRefresh
                        onClicked: root.api.refresh()
                    }
                    HeaderButton {
                        kind: "dashboard"
                        tip: i18n("Open CasaOS dashboard")
                        accent: Theme.accent
                        onClicked: root.plasmoidItem.openDashboard()
                    }
                    HeaderButton {
                        kind: "reboot"
                        tip: i18n("Reboot server")
                        accent: Theme.danger
                        onClicked: root.triggerReboot()
                    }
                }
            }

            // ---- system + aligned telemetry --------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 1
                spacing: Kirigami.Units.smallSpacing

                SectionCard {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 2
                    Layout.fillHeight: true
                    title: i18n("System")
                    iconKind: "server"
                    glyphColor: Theme.iconHeader
                    trailingText: {
                        var bits = []
                        if (root.api.servicesTotalCount > 0) {
                            bits.push(i18n("%1/%2 svcs",
                                           root.api.servicesHealthyCount,
                                           root.api.servicesTotalCount))
                        }
                        if (root.api.processCount > 0) {
                            bits.push(i18n("%1 procs", root.api.processCount))
                        }
                        if (root.api.uptimeSeconds > 0) {
                            bits.push(root.api.formatUptime(root.api.uptimeSeconds))
                        }
                        return bits.join(" · ")
                    }
                    trailingColor: root.api.servicesTotalCount === 0
                        || root.api.servicesHealthyCount === root.api.servicesTotalCount
                        ? Theme.success : Theme.warning

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: Kirigami.Units.gridUnit * 7
                        contentHeight: sysCol.implicitHeight
                        contentWidth: width
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        flickableDirection: Flickable.VerticalFlick

                        ColumnLayout {
                            id: sysCol
                            width: parent.width
                            spacing: 1

                            KeyValueRow {
                                label: i18n("Server")
                                value: root.api.normalizedBaseUrl().replace(/^https?:\/\//, "")
                            }
                            KeyValueRow {
                                visible: root.api.hostname.length > 0
                                label: i18n("Hostname")
                                value: root.api.hostname
                            }
                            KeyValueRow {
                                visible: root.api.osName.length > 0 || root.api.osVersion.length > 0 || root.api.platform.length > 0
                                label: i18n("OS")
                                value: {
                                    var name = root.api.osName.length > 0 ? root.api.osName : root.api.platform
                                    var ver = root.api.osVersion.length > 0 ? root.api.osVersion : root.api.platformVersion
                                    return (name + " " + ver).trim()
                                }
                            }
                            KeyValueRow {
                                visible: root.api.hardwareArch.length > 0
                                label: i18n("Architecture")
                                value: root.api.hardwareArch
                            }
                            KeyValueRow {
                                visible: root.api.cpuVendorDisplay.length > 0 || root.api.cpuCores > 0
                                label: i18n("CPU")
                                value: {
                                    var parts = []
                                    if (root.api.cpuVendorDisplay.length > 0) parts.push(root.api.cpuVendorDisplay)
                                    if (root.api.cpuCores > 0) parts.push(i18n("%1 cores", root.api.cpuCores))
                                    if (root.api.cpuTemp > 0) parts.push(root.api.formatTemp(root.api.cpuTemp))
                                    return parts.join(" · ")
                                }
                            }
                            KeyValueRow {
                                visible: root.api.memTotal > 0
                                label: i18n("Memory")
                                value: root.api.formatBytes(root.api.memTotal)
                            }
                            KeyValueRow {
                                visible: root.api.diskTotal > 0
                                label: i18n("Storage")
                                value: root.api.formatBytes(root.api.diskTotal)
                                    + (root.api.diskHealthy ? "" : " · " + i18n("health warning"))
                                valueColor: root.api.diskHealthy ? "" : Theme.warning
                            }
                            KeyValueRow {
                                visible: root.api.kernelName.length > 0 || root.api.kernelVersion.length > 0
                                label: i18n("Kernel")
                                value: (root.api.kernelName + " " + root.api.kernelVersion).trim()
                            }
                            KeyValueRow {
                                visible: root.api.virtualization.length > 0
                                label: i18n("Virtualization")
                                value: root.api.virtualization
                            }
                            KeyValueRow {
                                visible: root.api.manufacturer.length > 0
                                label: i18n("Manufacturer")
                                value: root.api.manufacturer
                            }
                            KeyValueRow {
                                visible: root.api.hardwareModel.length > 0
                                label: i18n("Hardware")
                                value: root.api.hardwareModel
                            }
                            KeyValueRow {
                                visible: root.api.motherboard.length > 0
                                label: i18n("Motherboard")
                                value: root.api.motherboard
                            }
                            KeyValueRow {
                                visible: root.api.biosVendor.length > 0 || root.api.biosVersion.length > 0
                                label: i18n("BIOS")
                                value: {
                                    var parts = []
                                    if (root.api.biosVendor.length > 0) parts.push(root.api.biosVendor)
                                    if (root.api.biosVersion.length > 0) parts.push(root.api.biosVersion)
                                    if (root.api.biosDate.length > 0) parts.push("(" + root.api.biosDate + ")")
                                    return parts.join(" ")
                                }
                            }
                            KeyValueRow {
                                visible: root.api.processCount > 0
                                label: i18n("Processes")
                                value: String(root.api.processCount)
                            }
                            KeyValueRow {
                                visible: root.api.timezone.length > 0
                                label: i18n("Timezone")
                                value: root.api.timezone
                            }
                            KeyValueRow {
                                visible: root.api.uptimeSeconds > 0
                                label: i18n("Uptime")
                                value: root.api.formatUptime(root.api.uptimeSeconds)
                            }
                            KeyValueRow {
                                visible: root.api.servicesTotalCount > 0
                                label: i18n("Services")
                                value: i18n("%1 / %2 running",
                                            root.api.servicesHealthyCount,
                                            root.api.servicesTotalCount)
                                valueColor: root.api.servicesHealthyCount === root.api.servicesTotalCount
                                    ? "" : Theme.warning
                            }
                            KeyValueRow {
                                visible: root.api.servicesStopped.length > 0
                                label: i18n("Stopped")
                                value: root.api.servicesStopped.slice(0, 4).join(", ")
                                valueColor: Theme.warning
                            }
                            KeyValueRow {
                                label: i18n("CasaOS")
                                value: root.api.casaVersion.length ? "v" + root.api.casaVersion.replace(/^v/, "") : "—"
                            }
                        }
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 3
                    Layout.fillHeight: true
                    title: i18n("Activity")
                    iconKind: "chart"
                    glyphColor: Theme.iconRefresh

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        columnSpacing: Kirigami.Units.smallSpacing * 1.5
                        rowSpacing: Kirigami.Units.smallSpacing

                        LabeledGraph {
                            label: i18n("CPU")
                            accent: Theme.cpu
                            valueText: root.api.cpuPercent >= 0 ? Math.round(root.api.cpuPercent) + "%" : "—"
                            samples: root.api.cpuHistory
                        }
                        LabeledGraph {
                            label: "↓  " + i18n("Down")
                            accent: Theme.netRx
                            valueText: root.api.formatRate(root.api.netRxRate)
                            samples: root.api.netRxHistory
                            autoScale: true
                        }
                        LabeledGraph {
                            label: i18n("RAM")
                            accent: Theme.ram
                            valueText: root.api.memPercent >= 0 ? Math.round(root.api.memPercent) + "%" : "—"
                            samples: root.api.memHistory
                        }
                        LabeledGraph {
                            label: "↑  " + i18n("Up")
                            accent: Theme.netTx
                            valueText: root.api.formatRate(root.api.netTxRate)
                            samples: root.api.netTxHistory
                            autoScale: true
                        }
                    }
                }
            }

            // ---- installed apps --------------------------------------
            SectionCard {
                visible: root.api.appsTotalCount > 0
                title: i18n("Installed Apps")
                iconKind: "dashboard"
                glyphColor: Theme.iconGraphics
                trailingText: {
                    var head = i18n("%1 / %2 running",
                                    root.api.appsRunningCount,
                                    root.api.appsTotalCount)
                    var extras = []
                    if (root.api.appsCpuTotal > 0) {
                        extras.push(root.api.formatCpuPercent(root.api.appsCpuTotal))
                    }
                    if (root.api.appsMemTotal > 0) {
                        extras.push(root.api.formatBytesShort(root.api.appsMemTotal))
                    }
                    return extras.length ? head + " · " + extras.join(" · ") : head
                }
                trailingColor: root.api.appsRunningCount === root.api.appsTotalCount
                    ? Theme.success : Theme.warning

                Flickable {
                    id: appsFlick
                    Layout.fillWidth: true
                    implicitHeight: Math.min(appsGrid.implicitHeight, root.appsMaxHeight)
                    Layout.maximumHeight: root.appsMaxHeight
                    contentHeight: appsGrid.implicitHeight
                    contentWidth: width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height + 1
                    flickableDirection: Flickable.VerticalFlick

                    GridLayout {
                        id: appsGrid
                        width: appsFlick.width
                        columns: 3
                        columnSpacing: Kirigami.Units.smallSpacing
                        rowSpacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: root.api.apps

                        delegate: Rectangle {
                            id: appTile
                            required property var modelData

                            readonly property color statusColor: appTile.modelData.running
                                ? Theme.success : Theme.danger
                            readonly property var iconUrls: root.api.appIconUrls(
                                appTile.modelData.name,
                                appTile.modelData.title,
                                appTile.modelData.icon)
                            property int iconIdx: 0
                            readonly property string tipText: {
                                if (!appTile.modelData.running) {
                                    return i18n("%1 is stopped", appTile.modelData.title)
                                }
                                var parts = [
                                    i18n("CPU %1 of host",
                                         root.api.formatCpuPercent(appTile.modelData.cpuPercent)),
                                    i18n("RAM %1",
                                         root.api.formatBytes(appTile.modelData.memUsed || 0))
                                ]
                                if ((appTile.modelData.netRx || 0) > 0 || (appTile.modelData.netTx || 0) > 0) {
                                    parts.push(i18n("↓ %1  ↑ %2",
                                                    root.api.formatRate(appTile.modelData.netRx || 0),
                                                    root.api.formatRate(appTile.modelData.netTx || 0)))
                                }
                                if (appTile.modelData.containerCount > 1) {
                                    parts.push(i18n("%1 containers",
                                                    appTile.modelData.containerCount))
                                }
                                return parts.join(" · ")
                            }

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: appTileInner.implicitHeight + Kirigami.Units.smallSpacing * 2
                            radius: Kirigami.Units.smallSpacing * 1.25
                            color: Theme.alpha(Kirigami.Theme.textColor,
                                               appHover.containsMouse ? 0.07 : 0.035)
                            border.width: 1
                            border.color: Theme.alpha(appTile.statusColor, 0.28)

                            Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }

                            ColumnLayout {
                                id: appTileInner
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    Item {
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.small

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Kirigami.Units.smallSpacing
                                            color: Theme.alpha(appTile.statusColor, 0.16)
                                            visible: appIcon.status !== Image.Ready

                                            Text {
                                                anchors.centerIn: parent
                                                text: appTile.modelData.title.length > 0
                                                    ? appTile.modelData.title.charAt(0).toUpperCase()
                                                    : "?"
                                                color: appTile.statusColor
                                                font.weight: Font.Bold
                                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                renderType: Text.NativeRendering
                                            }
                                        }

                                        Image {
                                            id: appIcon
                                            anchors.fill: parent
                                            source: appTile.iconUrls.length > appTile.iconIdx
                                                ? appTile.iconUrls[appTile.iconIdx] : ""
                                            smooth: true
                                            mipmap: true
                                            asynchronous: true
                                            fillMode: Image.PreserveAspectFit
                                            cache: true
                                            visible: status === Image.Ready && !Theme.monochrome
                                            sourceSize.width: Kirigami.Units.iconSizes.small * 2
                                            sourceSize.height: Kirigami.Units.iconSizes.small * 2

                                            onStatusChanged: {
                                                if (status === Image.Error
                                                    && appTile.iconIdx < appTile.iconUrls.length - 1) {
                                                    appTile.iconIdx++
                                                }
                                            }
                                        }

                                        MultiEffect {
                                            anchors.fill: appIcon
                                            source: appIcon
                                            visible: Theme.monochrome && appIcon.status === Image.Ready
                                            opacity: 0.85
                                            colorization: 1.0
                                            colorizationColor: Theme.monoSel
                                        }
                                    }

                                    Text {
                                        text: appTile.modelData.title
                                        color: Kirigami.Theme.textColor
                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        renderType: Text.NativeRendering
                                    }

                                    Text {
                                        visible: appTile.modelData.containerCount > 1
                                        text: "×" + appTile.modelData.containerCount
                                        color: Theme.muted
                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                        renderType: Text.NativeRendering
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 8
                                        Layout.preferredHeight: 8
                                        radius: 4
                                        color: appTile.statusColor

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width + 4
                                            height: width
                                            radius: width / 2
                                            z: -1
                                            color: Theme.alpha(appTile.statusColor, 0.28)
                                        }
                                    }
                                }

                                Text {
                                    visible: !appTile.modelData.running
                                    text: i18n("Stopped")
                                    color: Theme.danger
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }

                                RowLayout {
                                    visible: appTile.modelData.running
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    Text {
                                        text: root.api.formatCpuPercent(appTile.modelData.cpuPercent)
                                        color: Theme.cpu
                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                        font.weight: Font.Bold
                                        renderType: Text.NativeRendering
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        implicitHeight: 3
                                        radius: 1.5
                                        color: Theme.alpha(Theme.cpu, 0.14)
                                        Rectangle {
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.cpu
                                            width: {
                                                var p = Math.max(0, appTile.modelData.cpuPercent || 0)
                                                if (p <= 0) return 0
                                                return Math.max(2, parent.width * Math.min(1, p / 100))
                                            }
                                        }
                                    }

                                    Text {
                                        text: appTile.modelData.memUsed > 0
                                            ? root.api.formatBytesShort(appTile.modelData.memUsed)
                                            : "—"
                                        color: Theme.ram
                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                        font.weight: Font.Bold
                                        renderType: Text.NativeRendering
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        implicitHeight: 3
                                        radius: 1.5
                                        color: Theme.alpha(Theme.ram, 0.14)
                                        Rectangle {
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.ram
                                            width: {
                                                var p = Math.max(0, appTile.modelData.memPercent || 0)
                                                if (p <= 0) return 0
                                                return Math.max(2, parent.width * Math.min(1, p / 100))
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: appHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            PC3.ToolTip.visible: appHover.containsMouse
                            PC3.ToolTip.delay: 400
                            PC3.ToolTip.text: appTile.tipText
                        }
                    }
                    }
                }
            }
            }
        }
    }
}
