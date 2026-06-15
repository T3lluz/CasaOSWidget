pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Minimal, modern, data-rich popup. Dark surface, soft cards, vivid
// accents per metric. All API actions (refresh / open / reboot) live in
// the header so the user can act without scrolling.
PlasmaExtras.Representation {
    id: root

    required property var api
    required property var theme
    required property var plasmoidItem

    collapseMarginsHint: true

    // Shared edge inset for every card so the popup uses its width well.
    readonly property int edgeMargin: Kirigami.Units.smallSpacing * 1.5
    // One height for every sparkline so all graphs match.
    readonly property int graphHeight: Kirigami.Units.gridUnit * 4
    readonly property int popupWidth: Kirigami.Units.gridUnit * 24
    readonly property int popupContentHeight: body.implicitHeight
    Layout.preferredWidth: popupWidth
    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.maximumWidth: Kirigami.Units.gridUnit * 32
    Layout.preferredHeight: popupContentHeight
    Layout.minimumHeight: popupContentHeight
    Layout.maximumHeight: popupContentHeight
    implicitHeight: popupContentHeight
    implicitWidth: popupWidth

    // --- background ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: root.theme.bg
        radius: root.theme.radiusMd
    }

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
        radius: root.theme.radiusMd
        color: root.theme.bgElevated
        border.color: root.theme.cardBorder
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
            color: toast.success ? root.theme.success : root.theme.danger
            font.weight: Font.DemiBold
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            renderType: Text.NativeRendering
        }

        Behavior on opacity { NumberAnimation { duration: 250 } }
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
    component SectionCard: Rectangle {
        id: cardRoot
        default property alias content: inner.data
        property string title: ""

        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: root.theme.radiusMd
        color: root.theme.bgElevated
        border.width: 1
        border.color: root.theme.cardBorder

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing * 1.5
            spacing: Kirigami.Units.smallSpacing

            Text {
                visible: cardRoot.title.length > 0
                text: cardRoot.title.toUpperCase()
                color: root.theme.textDim
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                renderType: Text.NativeRendering
                Layout.bottomMargin: 2
            }

            ColumnLayout {
                id: inner
                Layout.fillWidth: true
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
            color: root.theme.textDim
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            renderType: Text.NativeRendering
        }
        Item { Layout.fillWidth: true }
        Text {
            text: kv.value.length ? kv.value : "—"
            color: kv.valueColor.length ? kv.valueColor : root.theme.text
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            Layout.maximumWidth: root.popupWidth * 0.6
            renderType: Text.NativeRendering
        }
    }

    // A labelled sparkline sitting on its own inset background, so adjacent
    // graphs read as clearly separate panels.
    component LabeledGraph: ColumnLayout {
        id: lg
        property string label: ""
        property color accent: root.theme.text
        property string valueText: ""
        property alias samples: lgSpark.samples
        property bool autoScale: false
        property real chartHeight: root.graphHeight

        Layout.fillWidth: true
        // Equal preferred width so paired graphs always split the row evenly,
        // regardless of how wide their label/value text is.
        Layout.preferredWidth: 1
        spacing: Kirigami.Units.smallSpacing

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
                color: root.theme.text
                font.weight: Font.Bold
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: lg.chartHeight
            radius: root.theme.radiusSm
            color: root.theme.bg
            border.width: 1
            border.color: root.theme.divider
            clip: true

            SparklineChart {
                id: lgSpark
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                lineColor: lg.accent
                gridColor: root.theme.divider
                baselineColor: root.theme.trackBg
                autoScale: lg.autoScale
            }
        }
    }

    component HeaderButton: Rectangle {
        id: hb
        required property string kind
        property string tip: ""
        property color accent: root.theme.text
        signal clicked()

        Layout.preferredWidth: Kirigami.Units.iconSizes.medium + 6
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium + 6
        radius: root.theme.radiusSm
        color: hbArea.containsMouse ? root.theme.bgHover : "transparent"
        border.width: 1
        border.color: hbArea.containsMouse ? root.theme.cardBorder : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        MetricIcon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            kind: hb.kind
            color: hbArea.containsMouse ? hb.accent : root.theme.textDim
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

        ColumnLayout {
            id: body
            width: parent.width
            spacing: Kirigami.Units.smallSpacing

            // ---- header ---------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: root.edgeMargin
                Layout.rightMargin: root.edgeMargin
                Layout.topMargin: root.edgeMargin
                implicitHeight: headerRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                radius: root.theme.radiusMd
                color: root.theme.bgElevated
                border.width: 1
                border.color: root.theme.cardBorder

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing * 1.5
                    spacing: Kirigami.Units.smallSpacing * 1.5

                    // server avatar with status ring
                    Item {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: root.theme.bgHover
                            border.width: 2
                            border.color: root.api.isConnected ? root.theme.success
                                : (root.api.status === "connecting" ? root.theme.warning : root.theme.danger)
                        }
                        MetricIcon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.medium
                            height: width
                            kind: "server"
                            color: root.theme.text
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: Plasmoid.configuration.serverName || i18n("CasaOS Homelab")
                            color: root.theme.text
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 3
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            renderType: Text.NativeRendering
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: root.api.isConnected ? root.theme.success
                                    : (root.api.status === "connecting" ? root.theme.warning : root.theme.danger)
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: root.api.isConnected
                                    ? i18n("Connected · CasaOS %1", root.api.casaVersion || "?")
                                    : (root.api.status === "connecting"
                                        ? i18n("Connecting…")
                                        : (root.api.statusMessage || i18n("Disconnected")))
                                color: root.api.isConnected ? root.theme.success
                                    : (root.api.status === "connecting" ? root.theme.warning : root.theme.danger)
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: root.api.lastUpdateMs > 0
                            text: i18n("Updated %1", Qt.formatTime(new Date(root.api.lastUpdateMs), "HH:mm:ss"))
                            color: root.theme.textMuted
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                            renderType: Text.NativeRendering
                        }
                    }

                    HeaderButton {
                        kind: "refresh"
                        tip: i18n("Refresh now")
                        onClicked: root.api.refresh()
                    }
                    HeaderButton {
                        kind: "dashboard"
                        tip: i18n("Open CasaOS dashboard")
                        onClicked: root.plasmoidItem.openDashboard()
                    }
                    HeaderButton {
                        kind: "reboot"
                        tip: i18n("Reboot server")
                        accent: root.theme.danger
                        onClicked: root.triggerReboot()
                    }
                }
            }

            // ---- gauges row -------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.edgeMargin
                Layout.rightMargin: root.edgeMargin
                spacing: Kirigami.Units.smallSpacing

                GaugeRing {
                    theme: root.theme
                    label: i18n("CPU")
                    percent: root.api.cpuPercent
                    accentColor: root.theme.cpu
                    subText: root.api.cpuTemp > 0
                        ? i18n("%1 · %2 cores", root.api.formatTemp(root.api.cpuTemp), root.api.cpuCores)
                        : (root.api.cpuCores > 0 ? i18n("%1 cores", root.api.cpuCores) : "")
                    Layout.fillWidth: true
                }

                GaugeRing {
                    theme: root.theme
                    label: i18n("RAM")
                    percent: root.api.memPercent
                    accentColor: root.theme.ram
                    centerText: root.api.memPercent >= 0 ? Math.round(root.api.memPercent) + "%" : "—"
                    subText: root.api.memTotal > 0
                        ? root.api.formatBytesShort(root.api.memUsed) + "/" + root.api.formatBytesShort(root.api.memTotal)
                        : ""
                    Layout.fillWidth: true
                }

                GaugeRing {
                    theme: root.theme
                    label: i18n("DISK")
                    percent: root.api.diskPercent
                    accentColor: root.api.diskHealthy ? root.theme.disk : root.theme.danger
                    centerText: root.api.diskPairText()
                    subText: root.api.diskHealthy
                        ? (root.api.diskTotal > 0
                            ? i18n("%1 free", root.api.formatBytesShort(root.api.diskAvail || (root.api.diskTotal - root.api.diskUsed)))
                            : "")
                        : i18n("Health warning")
                    Layout.fillWidth: true
                }
            }

            // ---- history graphs --------------------------------------
            SectionCard {
                Layout.leftMargin: root.edgeMargin
                Layout.rightMargin: root.edgeMargin
                title: i18n("History")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 2

                    LabeledGraph {
                        label: i18n("CPU")
                        accent: root.theme.cpu
                        valueText: root.api.cpuPercent >= 0 ? Math.round(root.api.cpuPercent) + "%" : "—"
                        samples: root.api.cpuHistory
                    }

                    LabeledGraph {
                        label: i18n("RAM")
                        accent: root.theme.ram
                        valueText: root.api.memPercent >= 0 ? Math.round(root.api.memPercent) + "%" : "—"
                        samples: root.api.memHistory
                    }
                }
            }

            // ---- network ---------------------------------------------
            SectionCard {
                Layout.leftMargin: root.edgeMargin
                Layout.rightMargin: root.edgeMargin
                visible: root.api.networkInterfaces.length > 0
                title: i18n("Network")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 2

                    LabeledGraph {
                        label: "↓  " + i18n("Down")
                        accent: root.theme.netRx
                        valueText: root.api.formatRate(root.api.netRxRate)
                        samples: root.api.netRxHistory
                        autoScale: true
                    }

                    LabeledGraph {
                        label: "↑  " + i18n("Up")
                        accent: root.theme.netTx
                        valueText: root.api.formatRate(root.api.netTxRate)
                        samples: root.api.netTxHistory
                        autoScale: true
                    }
                }

                Repeater {
                    model: root.api.networkInterfaces.slice(0, 4)

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: modelData.state === "up" ? root.theme.success : root.theme.textMuted
                        }
                        Text {
                            text: modelData.name
                            color: root.theme.text
                            font.weight: Font.DemiBold
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            renderType: Text.NativeRendering
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: i18n("↓ %1  ↑ %2",
                                       root.api.formatBytes(modelData.bytesRecv || modelData.bytes_recv || 0),
                                       root.api.formatBytes(modelData.bytesSent || modelData.bytes_sent || 0))
                            color: root.theme.textDim
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            // ---- installed apps --------------------------------------
            SectionCard {
                Layout.leftMargin: root.edgeMargin
                Layout.rightMargin: root.edgeMargin
                visible: root.api.appsTotalCount > 0

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: i18n("INSTALLED APPS")
                        color: root.theme.textDim
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                        renderType: Text.NativeRendering
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: i18n("%1 / %2 running",
                                   root.api.appsRunningCount,
                                   root.api.appsTotalCount)
                        color: root.api.appsRunningCount === root.api.appsTotalCount
                            ? root.theme.success : root.theme.warning
                        font.weight: Font.Bold
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        renderType: Text.NativeRendering
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: root.api.apps

                        delegate: Rectangle {
                            id: appTile
                            required property var modelData

                            readonly property color statusColor: appTile.modelData.running
                                ? root.theme.success : root.theme.danger
                            readonly property string iconUrl: root.api.resolveAppIcon(appTile.modelData.icon)

                            implicitWidth: Kirigami.Units.gridUnit * 4.5
                            implicitHeight: Kirigami.Units.gridUnit * 4.5

                            radius: root.theme.radiusSm
                            color: appTileArea.containsMouse
                                ? root.theme.bgHover : root.theme.alpha(root.theme.bgHover, 0.5)
                            border.width: 1
                            border.color: root.theme.alpha(appTile.statusColor,
                                appTileArea.containsMouse ? 0.55 : 0.28)

                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 3

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium

                                    // letter avatar shown until icon resolves
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: root.theme.alpha(appTile.statusColor, 0.18)
                                        visible: appIcon.status !== Image.Ready

                                        Text {
                                            anchors.centerIn: parent
                                            text: appTile.modelData.title.length > 0
                                                ? appTile.modelData.title.charAt(0).toUpperCase()
                                                : "?"
                                            color: appTile.statusColor
                                            font.weight: Font.Bold
                                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    Image {
                                        id: appIcon
                                        anchors.fill: parent
                                        source: appTile.iconUrl
                                        smooth: true
                                        mipmap: true
                                        asynchronous: true
                                        fillMode: Image.PreserveAspectFit
                                        cache: true
                                        visible: status === Image.Ready
                                        sourceSize.width: Kirigami.Units.iconSizes.medium * 2
                                        sourceSize.height: Kirigami.Units.iconSizes.medium * 2
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    text: appTile.modelData.title
                                    color: root.theme.text
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    renderType: Text.NativeRendering
                                }
                            }

                            // status badge — a clear ringed dot in the tile
                            // corner; green = running, red = stopped.
                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 5
                                anchors.rightMargin: 5
                                color: appTile.statusColor
                                border.color: root.theme.bgElevated
                                border.width: 2

                                // soft halo so the status reads at a glance
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 4
                                    height: width
                                    radius: width / 2
                                    z: -1
                                    color: root.theme.alpha(appTile.statusColor, 0.25)
                                }
                            }

                            PC3.ToolTip.visible: appTileArea.containsMouse
                            PC3.ToolTip.delay: 400
                            PC3.ToolTip.text: appTile.modelData.title
                                + (appTile.modelData.status.length ? " — " + appTile.modelData.status : "")
                                + (appTile.modelData.running ? "" : "\n" + i18n("Not running"))
                                + "\n" + i18n("Click to open in CasaOS")

                            MouseArea {
                                id: appTileArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.plasmoidItem.openDashboard()
                            }
                        }
                    }
                }
            }

            // ---- system info -----------------------------------------
            SectionCard {
                Layout.leftMargin: root.edgeMargin
                Layout.rightMargin: root.edgeMargin
                Layout.bottomMargin: root.edgeMargin
                title: i18n("System")

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
                    visible: root.api.platformFamily.length > 0
                        && root.api.platformFamily.toLowerCase() !== root.api.osName.toLowerCase()
                    label: i18n("Family")
                    value: root.api.platformFamily
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
                    valueColor: root.api.diskHealthy ? "" : root.theme.warning
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
                    label: i18n("CasaOS")
                    value: root.api.casaVersion.length ? "v" + root.api.casaVersion.replace(/^v/, "") : "—"
                }
            }
        }
    }
}
