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
            Layout.maximumWidth: root.popupWidth * 0.6
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
                color: Kirigami.Theme.textColor
                font.weight: Font.Bold
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: lg.chartHeight
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

        ColumnLayout {
            id: body
            width: parent.width
            spacing: Kirigami.Units.smallSpacing * 1.5

            // ---- header ---------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: root.edgeMargin
                Layout.rightMargin: root.edgeMargin
                Layout.topMargin: root.edgeMargin
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
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large

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
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
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
                            font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.25)
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
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: root.api.lastUpdateMs > 0
                            text: i18n("Updated %1", Qt.formatTime(new Date(root.api.lastUpdateMs), "HH:mm:ss"))
                            color: Theme.muted
                            opacity: 0.7
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                            renderType: Text.NativeRendering
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

            // ---- gauges row -------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.edgeMargin
                Layout.rightMargin: root.edgeMargin
                spacing: Kirigami.Units.smallSpacing

                GaugeRing {
                    label: i18n("CPU")
                    percent: root.api.cpuPercent
                    accentColor: Theme.cpu
                    subText: root.api.cpuTemp > 0
                        ? i18n("%1 · %2 cores", root.api.formatTemp(root.api.cpuTemp), root.api.cpuCores)
                        : (root.api.cpuCores > 0 ? i18n("%1 cores", root.api.cpuCores) : "")
                    Layout.fillWidth: true
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
                }
            }

            // ---- history graphs --------------------------------------
            SectionCard {
                Layout.leftMargin: root.edgeMargin
                Layout.rightMargin: root.edgeMargin
                title: i18n("History")
                iconKind: "chart"
                glyphColor: Theme.iconRefresh

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 2

                    LabeledGraph {
                        label: i18n("CPU")
                        accent: Theme.cpu
                        valueText: root.api.cpuPercent >= 0 ? Math.round(root.api.cpuPercent) + "%" : "—"
                        samples: root.api.cpuHistory
                    }

                    LabeledGraph {
                        label: i18n("RAM")
                        accent: Theme.ram
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
                iconKind: "network"
                glyphColor: Theme.iconKbd

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 2

                    LabeledGraph {
                        label: "↓  " + i18n("Down")
                        accent: Theme.netRx
                        valueText: root.api.formatRate(root.api.netRxRate)
                        samples: root.api.netRxHistory
                        autoScale: true
                    }

                    LabeledGraph {
                        label: "↑  " + i18n("Up")
                        accent: Theme.netTx
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
                            color: modelData.state === "up" ? Theme.success : Theme.muted
                        }
                        Text {
                            text: modelData.name
                            color: Kirigami.Theme.textColor
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
                            color: Kirigami.Theme.disabledTextColor
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
                title: i18n("Installed Apps")
                iconKind: "dashboard"
                glyphColor: Theme.iconGraphics
                trailingText: i18n("%1 / %2 running",
                                   root.api.appsRunningCount,
                                   root.api.appsTotalCount)
                trailingColor: root.api.appsRunningCount === root.api.appsTotalCount
                    ? Theme.success : Theme.warning

                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: root.api.apps

                        delegate: Rectangle {
                            id: appTile
                            required property var modelData

                            readonly property color statusColor: appTile.modelData.running
                                ? Theme.success : Theme.danger
                            // Ordered icon candidates (CasaOS → dashboard-icons
                            // by title → by name); iconIdx advances on load error.
                            readonly property var iconUrls: root.api.appIconUrls(
                                appTile.modelData.name,
                                appTile.modelData.title,
                                appTile.modelData.icon)
                            property int iconIdx: 0

                            implicitWidth: Kirigami.Units.gridUnit * 4.5
                            implicitHeight: Kirigami.Units.gridUnit * 4.5

                            radius: Kirigami.Units.smallSpacing * 1.25
                            color: appTileArea.containsMouse
                                ? Theme.alpha(Kirigami.Theme.textColor, 0.07)
                                : Theme.alpha(Kirigami.Theme.textColor, 0.035)
                            border.width: 1
                            border.color: Theme.alpha(appTile.statusColor,
                                appTileArea.containsMouse ? 0.55 : 0.28)
                            scale: appTileArea.pressed ? 0.97 : 1.0

                            Behavior on border.color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }
                            Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }
                            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }

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
                                        color: Theme.alpha(appTile.statusColor, 0.18)
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
                                        source: appTile.iconUrls.length > appTile.iconIdx
                                            ? appTile.iconUrls[appTile.iconIdx] : ""
                                        smooth: true
                                        mipmap: true
                                        asynchronous: true
                                        fillMode: Image.PreserveAspectFit
                                        cache: true
                                        // hide the colored original in monochrome —
                                        // the themed MultiEffect below stands in for it
                                        visible: status === Image.Ready && !Theme.monochrome
                                        sourceSize.width: Kirigami.Units.iconSizes.medium * 2
                                        sourceSize.height: Kirigami.Units.iconSizes.medium * 2

                                        // Walk to the next candidate URL on failure.
                                        onStatusChanged: {
                                            if (status === Image.Error
                                                && appTile.iconIdx < appTile.iconUrls.length - 1) {
                                                appTile.iconIdx++
                                            }
                                        }
                                    }

                                    // Monochrome theming: keep the whole logo with
                                    // its detail, but desaturate and tint it into the
                                    // selected accent (luminance preserved, so it
                                    // still reads as the real icon) and make it a
                                    // little translucent so it sits softly in the
                                    // grayscale theme. Color mode hides this and shows
                                    // the full-color logo.
                                    MultiEffect {
                                        anchors.fill: appIcon
                                        source: appIcon
                                        visible: Theme.monochrome && appIcon.status === Image.Ready
                                        opacity: 0.85
                                        // colorization alone maps the logo onto the
                                        // accent hue (luminance preserved, so detail
                                        // stays). NOTE: do not add saturation:-1 here —
                                        // it desaturates the tint back to gray.
                                        colorization: 1.0
                                        colorizationColor: Theme.monoSel
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    text: appTile.modelData.title
                                    color: Kirigami.Theme.textColor
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
                                border.color: Kirigami.Theme.backgroundColor
                                border.width: 2

                                // soft halo so the status reads at a glance
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 4
                                    height: width
                                    radius: width / 2
                                    z: -1
                                    color: Theme.alpha(appTile.statusColor, 0.25)
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
                iconKind: "server"
                glyphColor: Theme.iconHeader

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
                    valueColor: root.api.diskHealthy ? "" : Theme.warning
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
