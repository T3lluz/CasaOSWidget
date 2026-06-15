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

    readonly property int popupWidth: Kirigami.Units.gridUnit * 26
    Layout.preferredWidth: popupWidth
    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.maximumWidth: Kirigami.Units.gridUnit * 32
    Layout.preferredHeight: body.implicitHeight + Kirigami.Units.largeSpacing * 2
    Layout.minimumHeight: body.implicitHeight + Kirigami.Units.largeSpacing * 2

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
        implicitHeight: cardLayout.implicitHeight + Kirigami.Units.largeSpacing * 1.5
        radius: root.theme.radiusMd
        color: root.theme.bgElevated
        border.width: 1
        border.color: root.theme.cardBorder

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
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

    component MetricBar: ColumnLayout {
        id: mb
        required property string label
        required property real percent
        required property string detail
        property color barColor: root.theme.severityColor(mb.percent)

        spacing: 4
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: mb.label
                color: root.theme.text
                font.weight: Font.DemiBold
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                Layout.fillWidth: true
                renderType: Text.NativeRendering
            }
            Text {
                text: mb.detail
                color: root.theme.textDim
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: root.theme.trackBg

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, mb.percent / 100))
                height: parent.height
                radius: parent.radius
                color: mb.barColor
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
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
            spacing: Kirigami.Units.largeSpacing

            // ---- header ---------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.largeSpacing
                implicitHeight: headerRow.implicitHeight + Kirigami.Units.largeSpacing * 1.5
                radius: root.theme.radiusMd
                color: root.theme.bgElevated
                border.width: 1
                border.color: root.theme.cardBorder

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
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
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
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
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                title: i18n("History")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: i18n("CPU")
                                color: root.theme.cpu
                                font.weight: Font.DemiBold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                renderType: Text.NativeRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.api.cpuPercent >= 0 ? Math.round(root.api.cpuPercent) + "%" : "—"
                                color: root.theme.text
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                renderType: Text.NativeRendering
                            }
                        }
                        SparklineChart {
                            samples: root.api.cpuHistory
                            lineColor: root.theme.cpu
                            gridColor: root.theme.divider
                            baselineColor: root.theme.trackBg
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: i18n("RAM")
                                color: root.theme.ram
                                font.weight: Font.DemiBold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                renderType: Text.NativeRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.api.memPercent >= 0 ? Math.round(root.api.memPercent) + "%" : "—"
                                color: root.theme.text
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                renderType: Text.NativeRendering
                            }
                        }
                        SparklineChart {
                            samples: root.api.memHistory
                            lineColor: root.theme.ram
                            gridColor: root.theme.divider
                            baselineColor: root.theme.trackBg
                        }
                    }
                }
            }

            // ---- resources detail ------------------------------------
            SectionCard {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                title: i18n("Resources")

                MetricBar {
                    label: i18n("CPU load")
                    percent: root.api.cpuPercent
                    detail: (root.api.cpuCores > 0 ? i18n("%1 cores", root.api.cpuCores) : "")
                        + (root.api.cpuTemp > 0 ? " · " + root.api.formatTemp(root.api.cpuTemp) : "")
                    barColor: root.theme.cpu
                }
                MetricBar {
                    label: i18n("Memory")
                    percent: root.api.memPercent
                    detail: root.api.memTotal > 0
                        ? root.api.formatBytes(root.api.memUsed) + " / " + root.api.formatBytes(root.api.memTotal)
                        : "—"
                    barColor: root.theme.ram
                }
                MetricBar {
                    label: i18n("Storage")
                    percent: root.api.diskPercent
                    detail: root.api.diskPairLongText()
                    barColor: root.api.diskHealthy ? root.theme.disk : root.theme.danger
                }
            }

            // ---- network ---------------------------------------------
            SectionCard {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: root.api.networkInterfaces.length > 0
                title: i18n("Network")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "↓  " + i18n("Down")
                                color: root.theme.netRx
                                font.weight: Font.DemiBold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                renderType: Text.NativeRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.api.formatRate(root.api.netRxRate)
                                color: root.theme.text
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                renderType: Text.NativeRendering
                            }
                        }
                        SparklineChart {
                            samples: root.api.netRxHistory
                            lineColor: root.theme.netRx
                            gridColor: root.theme.divider
                            baselineColor: root.theme.trackBg
                            autoScale: true
                            implicitHeight: Kirigami.Units.gridUnit * 2
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "↑  " + i18n("Up")
                                color: root.theme.netTx
                                font.weight: Font.DemiBold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                renderType: Text.NativeRendering
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.api.formatRate(root.api.netTxRate)
                                color: root.theme.text
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                renderType: Text.NativeRendering
                            }
                        }
                        SparklineChart {
                            samples: root.api.netTxHistory
                            lineColor: root.theme.netTx
                            gridColor: root.theme.divider
                            baselineColor: root.theme.trackBg
                            autoScale: true
                            implicitHeight: Kirigami.Units.gridUnit * 2
                        }
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

            // ---- services --------------------------------------------
            SectionCard {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: root.api.servicesTotalCount > 0

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: i18n("CASAOS SERVICES")
                        color: root.theme.textDim
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                        renderType: Text.NativeRendering
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: i18n("%1 / %2 running", root.api.servicesHealthyCount, root.api.servicesTotalCount)
                        color: root.api.servicesStopped.length === 0 ? root.theme.success : root.theme.warning
                        font.weight: Font.Bold
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        renderType: Text.NativeRendering
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: root.api.servicesRunning
                        delegate: Rectangle {
                            required property string modelData
                            radius: root.theme.radiusSm
                            color: root.theme.alpha(root.theme.success, 0.14)
                            border.color: root.theme.alpha(root.theme.success, 0.3)
                            border.width: 1
                            implicitWidth: svcLbl.implicitWidth + Kirigami.Units.smallSpacing * 2
                            implicitHeight: svcLbl.implicitHeight + Kirigami.Units.smallSpacing

                            Text {
                                id: svcLbl
                                anchors.centerIn: parent
                                text: modelData.replace(/\.service$/, "")
                                color: root.theme.success
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    Repeater {
                        model: root.api.servicesStopped
                        delegate: Rectangle {
                            required property string modelData
                            radius: root.theme.radiusSm
                            color: root.theme.alpha(root.theme.danger, 0.14)
                            border.color: root.theme.alpha(root.theme.danger, 0.3)
                            border.width: 1
                            implicitWidth: svcOffLbl.implicitWidth + Kirigami.Units.smallSpacing * 2
                            implicitHeight: svcOffLbl.implicitHeight + Kirigami.Units.smallSpacing

                            Text {
                                id: svcOffLbl
                                anchors.centerIn: parent
                                text: modelData.replace(/\.service$/, "")
                                color: root.theme.danger
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }

            // ---- system info -----------------------------------------
            SectionCard {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
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
                    visible: root.api.osName.length > 0 || root.api.osVersion.length > 0
                    label: i18n("OS")
                    value: (root.api.osName + " " + root.api.osVersion).trim()
                }
                KeyValueRow {
                    visible: root.api.kernelVersion.length > 0
                    label: i18n("Kernel")
                    value: root.api.kernelVersion
                }
                KeyValueRow {
                    visible: root.api.hardwareModel.length > 0
                    label: i18n("Hardware")
                    value: root.api.hardwareModel
                }
                KeyValueRow {
                    visible: root.api.hardwareArch.length > 0
                    label: i18n("Architecture")
                    value: root.api.hardwareArch
                }
                KeyValueRow {
                    visible: root.api.cpuModel.length > 0
                    label: i18n("CPU")
                    value: root.api.cpuModel
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
