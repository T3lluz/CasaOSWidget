import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property alias cfg_serverUrl: serverUrlField.text
    property alias cfg_serverName: serverNameField.text
    property alias cfg_username: usernameField.text
    property alias cfg_password: passwordField.text
    property alias cfg_refreshInterval: refreshSpin.value
    property alias cfg_requestTimeoutMs: timeoutSpin.value
    property alias cfg_historyLength: historySpin.value
    property alias cfg_browserCommand: browserField.text

    property int cfg_displayMode
    property bool cfg_showCpu
    property bool cfg_showCpuTemp
    property bool cfg_showRam
    property bool cfg_showDisk
    property bool cfg_showNetwork
    property bool cfg_showStatusDot
    property bool cfg_showName
    property bool cfg_showMiniBars
    property bool cfg_showSeparators
    property string cfg_metricOrder
    property string cfg_tempUnit
    property string cfg_netUnit
    property bool cfg_monochrome
    property int cfg_monoAccent
    property string cfg_middleClickAction
    property bool cfg_skipRebootConfirm

    readonly property var defaultOrder: [
        "status", "name", "cpu", "cpuTemp", "ram", "disk", "netDown", "netUp"
    ]

    readonly property var metricCatalog: [
        { id: "status",   label: i18n("Status"),     shortLabel: i18n("Status"), kind: "status",  tint: "#34d399" },
        { id: "name",     label: i18n("Name"),       shortLabel: i18n("Name"),   kind: "text",    tint: "#56b6f0" },
        { id: "cpu",      label: i18n("CPU usage"),  shortLabel: i18n("CPU"),    kind: "cpu",     tint: "#22d3ee" },
        { id: "cpuTemp",  label: i18n("CPU temp"),   shortLabel: i18n("CPU °"),  kind: "temp",    tint: "#fb923c" },
        { id: "ram",      label: i18n("RAM usage"),  shortLabel: i18n("RAM"),    kind: "ram",     tint: "#a78bfa" },
        { id: "disk",     label: i18n("Disk usage"), shortLabel: i18n("Disk"),   kind: "disk",    tint: "#34d399" },
        { id: "netDown",  label: i18n("Download"),   shortLabel: i18n("↓"),      kind: "down",    tint: "#60a5fa" },
        { id: "netUp",    label: i18n("Upload"),     shortLabel: i18n("↑"),      kind: "up",      tint: "#f472b6" }
    ]

    readonly property var dataCatalog: [
        { id: "cpu",     label: i18n("CPU usage"),  kind: "cpu",     tint: "#22d3ee" },
        { id: "cpuTemp", label: i18n("CPU temp"),   kind: "temp",    tint: "#fb923c" },
        { id: "ram",     label: i18n("RAM usage"),  kind: "ram",     tint: "#a78bfa" },
        { id: "disk",    label: i18n("Disk usage"), kind: "disk",    tint: "#34d399" },
        { id: "network", label: i18n("Network"),    kind: "network", tint: "#60a5fa" }
    ]

    readonly property var extraCatalog: [
        { id: "separators", label: i18n("Separators"),          kind: "dots",   tint: "#9aa7bd" },
        { id: "bars",       label: i18n("Mini bars"),           kind: "bars",   tint: "#7d93f0" },
        { id: "skipReboot", label: i18n("Skip reboot confirm"), kind: "reboot", tint: "#f2596a" }
    ]

    readonly property color muted: "#9aa7bd"
    readonly property color accent: "#7d93f0"
    readonly property color teal: "#2dd4bf"
    readonly property color amber: "#f4b73d"
    readonly property color iconGraphics: "#a78bfa"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    readonly property var accentOptions: [
        { name: i18n("White"),  color: "#e6e9ef" },
        { name: i18n("Green"),  color: "#34d399" },
        { name: i18n("Teal"),   color: "#2dd4bf" },
        { name: i18n("Orange"), color: "#fb923c" },
        { name: i18n("Red"),    color: "#f2596a" },
        { name: i18n("Blue"),   color: "#56b6f0" },
        { name: i18n("Purple"), color: "#a78bfa" }
    ]

    property bool writingOrder: false

    readonly property string showStamp: [
        cfg_showStatusDot, cfg_showName, cfg_showCpu, cfg_showCpuTemp,
        cfg_showRam, cfg_showDisk, cfg_showNetwork,
        cfg_showSeparators, cfg_showMiniBars, cfg_skipRebootConfirm, cfg_monochrome
    ].join(",")

    ListModel { id: orderModel }

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
            if (root.defaultOrder.indexOf(id) !== -1 && !known[id]) {
                known[id] = true
                out.push(id)
            }
        }
        for (var j = 0; j < root.defaultOrder.length; j++) {
            if (!known[root.defaultOrder[j]])
                out.push(root.defaultOrder[j])
        }
        return out
    }

    function reloadModel() {
        if (root.writingOrder)
            return
        orderModel.clear()
        var ids = parseOrder(root.cfg_metricOrder)
        for (var i = 0; i < ids.length; i++)
            orderModel.append({ mid: ids[i] })
    }

    function writeOrder() {
        var ids = []
        for (var i = 0; i < orderModel.count; i++)
            ids.push(orderModel.get(i).mid)
        root.writingOrder = true
        root.cfg_metricOrder = ids.join(",")
        root.writingOrder = false
    }

    function moveItem(index, dir) {
        var dest = index + dir
        if (dest < 0 || dest >= orderModel.count)
            return
        orderModel.move(index, dest, 1)
        writeOrder()
    }

    function catalogEntry(id) {
        for (var i = 0; i < root.metricCatalog.length; i++) {
            if (root.metricCatalog[i].id === id)
                return root.metricCatalog[i]
        }
        return { id: id, label: id, shortLabel: id, kind: "cpu", tint: "#9aa7bd" }
    }

    function showFor(id) {
        switch (id) {
        case "status": return root.cfg_showStatusDot
        case "name": return root.cfg_showName
        case "cpu": return root.cfg_showCpu
        case "cpuTemp": return root.cfg_showCpuTemp
        case "ram": return root.cfg_showRam
        case "disk": return root.cfg_showDisk
        case "network":
        case "netDown":
        case "netUp": return root.cfg_showNetwork
        case "separators": return root.cfg_showSeparators
        case "bars": return root.cfg_showMiniBars
        case "skipReboot": return root.cfg_skipRebootConfirm
        }
        return false
    }

    function setShow(id, on) {
        switch (id) {
        case "status": root.cfg_showStatusDot = on; break
        case "name": root.cfg_showName = on; break
        case "cpu": root.cfg_showCpu = on; break
        case "cpuTemp": root.cfg_showCpuTemp = on; break
        case "ram": root.cfg_showRam = on; break
        case "disk": root.cfg_showDisk = on; break
        case "network":
        case "netDown":
        case "netUp": root.cfg_showNetwork = on; break
        case "separators": root.cfg_showSeparators = on; break
        case "bars": root.cfg_showMiniBars = on; break
        case "skipReboot": root.cfg_skipRebootConfirm = on; break
        }
    }

    onCfg_metricOrderChanged: reloadModel()
    Component.onCompleted: reloadModel()

    component SectionCard: Rectangle {
        id: card
        default property alias content: inner.data
        property string title

        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + inner.implicitHeight + Kirigami.Units.largeSpacing * 2.5
        radius: Kirigami.Units.smallSpacing * 1.5
        color: root.alpha(Kirigami.Theme.textColor, 0.04)
        border.width: 1
        border.color: root.alpha(Kirigami.Theme.textColor, 0.08)

        QQC2.Label {
            id: head
            x: Kirigami.Units.largeSpacing
            y: Kirigami.Units.largeSpacing
            width: parent.width - Kirigami.Units.largeSpacing * 2
            text: card.title
            color: root.muted
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        ColumnLayout {
            id: inner
            x: Kirigami.Units.largeSpacing
            y: head.y + head.implicitHeight + Kirigami.Units.smallSpacing * 1.5
            width: parent.width - Kirigami.Units.largeSpacing * 2
            spacing: Kirigami.Units.smallSpacing * 1.5
        }
    }

    component FieldLabel: QQC2.Label {
        Layout.fillWidth: true
        color: root.muted
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        font.weight: Font.DemiBold
    }

    component ToggleTile: Rectangle {
        id: tile

        property string mid
        property string label
        property string kind
        property color accent
        readonly property bool on: {
            var _ = root.showStamp
            return root.showFor(tile.mid)
        }

        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 4.4
        radius: Kirigami.Units.smallSpacing * 1.4
        color: on ? root.alpha(accent, 0.16) : root.alpha(Kirigami.Theme.textColor, 0.035)
        border.width: on ? 2 : 1
        border.color: on ? root.alpha(accent, 0.55)
                         : root.alpha(Kirigami.Theme.textColor, 0.10)

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing * 0.6

            MetricIcon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                kind: tile.kind
                color: tile.on ? tile.accent : root.muted
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: tile.label
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.weight: tile.on ? Font.DemiBold : Font.Normal
                color: tile.on ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            }
        }

        HoverHandler { id: tileHover }
        TapHandler { onTapped: root.setShow(tile.mid, !tile.on) }

        QQC2.ToolTip.visible: tileHover.hovered
        QQC2.ToolTip.text: tile.on ? i18n("On") : i18n("Off")
    }

    component ChoiceTile: Rectangle {
        id: choice

        property bool selected: false
        property string label
        property string kind
        property color accent: root.accent
        signal picked

        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 3.6
        radius: Kirigami.Units.smallSpacing * 1.4
        color: selected ? root.alpha(accent, 0.16) : root.alpha(Kirigami.Theme.textColor, 0.035)
        border.width: selected ? 2 : 1
        border.color: selected ? root.alpha(accent, 0.55)
                               : root.alpha(Kirigami.Theme.textColor, 0.10)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing * 0.5

            MetricIcon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                kind: choice.kind
                color: choice.selected ? choice.accent : root.muted
            }

            QQC2.Label {
                text: choice.label
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.weight: choice.selected ? Font.DemiBold : Font.Normal
                color: choice.selected ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            }
        }

        TapHandler { onTapped: choice.picked() }
    }

    ColumnLayout {
        width: parent.width
        spacing: Kirigami.Units.largeSpacing

        SectionCard {
            title: i18n("CONNECTION")

            FieldLabel { text: i18n("Server URL") }
            QQC2.TextField {
                id: serverUrlField
                Layout.fillWidth: true
                placeholderText: "http://192.168.1.10  or  http://100.x.y.z"
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("HTTP or HTTPS. Tailscale and LAN both work — protocol is optional, http:// is added automatically.")
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
            }

            FieldLabel { text: i18n("Display name") }
            QQC2.TextField {
                id: serverNameField
                Layout.fillWidth: true
                placeholderText: i18n("Homelab")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 0.5
                    FieldLabel { text: i18n("Username") }
                    QQC2.TextField {
                        id: usernameField
                        Layout.fillWidth: true
                        placeholderText: "casaos"
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 0.5
                    FieldLabel { text: i18n("Password") }
                    QQC2.TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: i18n("CasaOS account password")
                    }
                }
            }
        }

        SectionCard {
            title: i18n("APPEARANCE")

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                MetricIcon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    kind: "bars"
                    color: root.cfg_monochrome ? root.accentOptions[root.cfg_monoAccent].color : root.accent
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("Monochrome palette")
                    font.weight: Font.DemiBold
                }

                QQC2.Switch {
                    checked: root.cfg_monochrome
                    onToggled: root.cfg_monochrome = checked
                }
            }

            FieldLabel { text: i18n("Accent") }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 1.2
                opacity: root.cfg_monochrome ? 1.0 : 0.55

                Repeater {
                    model: root.accentOptions

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        readonly property bool selected: root.cfg_monoAccent === index

                        implicitWidth: Kirigami.Units.gridUnit * 1.7
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: modelData.color
                        border.width: selected ? 3 : 1
                        border.color: selected
                            ? Kirigami.Theme.textColor
                            : Qt.rgba(Kirigami.Theme.textColor.r,
                                      Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.28)

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: parent.width * 0.5
                            height: width
                            source: "checkmark"
                            visible: parent.selected
                            color: index === 0 ? "#222428" : "#ffffff"
                            isMask: true
                        }

                        QQC2.ToolTip.visible: swatchHover.hovered
                        QQC2.ToolTip.text: modelData.name
                        HoverHandler { id: swatchHover }
                        TapHandler { onTapped: root.cfg_monoAccent = index }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: root.cfg_monochrome
                text: i18n("White stays fully neutral. A hue tints the active controls and panel glyphs.")
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
            }

            FieldLabel {
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: i18n("Display style")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                ChoiceTile {
                    label: i18n("Icons + values")
                    kind: "both"
                    selected: root.cfg_displayMode === 0
                    onPicked: root.cfg_displayMode = 0
                }
                ChoiceTile {
                    label: i18n("Values only")
                    kind: "text"
                    selected: root.cfg_displayMode === 1
                    onPicked: root.cfg_displayMode = 1
                }
                ChoiceTile {
                    label: i18n("Icons only")
                    kind: "server"
                    selected: root.cfg_displayMode === 2
                    onPicked: root.cfg_displayMode = 2
                }
            }

            FieldLabel { text: i18n("Temperature") }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                ChoiceTile {
                    label: i18n("Celsius (°C)")
                    kind: "temp"
                    accent: root.teal
                    selected: root.cfg_tempUnit !== "F"
                    onPicked: root.cfg_tempUnit = "C"
                }
                ChoiceTile {
                    label: i18n("Fahrenheit (°F)")
                    kind: "temp"
                    accent: root.amber
                    selected: root.cfg_tempUnit === "F"
                    onPicked: root.cfg_tempUnit = "F"
                }
            }

            FieldLabel { text: i18n("Network rate") }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                ChoiceTile {
                    label: i18n("Mbps")
                    kind: "network"
                    selected: root.cfg_netUnit === "mbps"
                    onPicked: root.cfg_netUnit = "mbps"
                }
                ChoiceTile {
                    label: i18n("MB/s")
                    kind: "network"
                    selected: root.cfg_netUnit === "mbytes"
                    onPicked: root.cfg_netUnit = "mbytes"
                }
                ChoiceTile {
                    label: i18n("KB/s")
                    kind: "network"
                    selected: root.cfg_netUnit === "kbytes"
                    onPicked: root.cfg_netUnit = "kbytes"
                }
                ChoiceTile {
                    label: i18n("Auto (B/KB/MB/GB)")
                    kind: "network"
                    selected: root.cfg_netUnit === "auto"
                    onPicked: root.cfg_netUnit = "auto"
                }
            }
        }

        SectionCard {
            title: i18n("PANEL ITEMS")

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: identityInner.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.smallSpacing * 1.4
                color: {
                    var _ = root.showStamp
                    return (root.cfg_showStatusDot || root.cfg_showName)
                        ? root.alpha("#7d93f0", 0.12)
                        : root.alpha(Kirigami.Theme.textColor, 0.03)
                }
                border.width: 1
                border.color: {
                    var _ = root.showStamp
                    return (root.cfg_showStatusDot || root.cfg_showName)
                        ? root.alpha("#7d93f0", 0.4)
                        : root.alpha(Kirigami.Theme.textColor, 0.10)
                }

                ColumnLayout {
                    id: identityInner
                    x: Kirigami.Units.smallSpacing * 1.5
                    y: Kirigami.Units.smallSpacing * 1.5
                    width: parent.width - Kirigami.Units.smallSpacing * 3
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        MetricIcon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            kind: "server"
                            color: "#7d93f0"
                        }
                        QQC2.Label {
                            text: i18n("Identity")
                            font.weight: Font.DemiBold
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: i18n("Connection dot and display name")
                            color: Kirigami.Theme.disabledTextColor
                            font: Kirigami.Theme.smallFont
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        ToggleTile {
                            mid: "status"
                            label: i18n("Status")
                            kind: "status"
                            accent: "#34d399"
                        }
                        ToggleTile {
                            mid: "name"
                            label: i18n("Name")
                            kind: "text"
                            accent: "#56b6f0"
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.dataCatalog

                    ToggleTile {
                        required property var modelData
                        mid: modelData.id
                        label: modelData.label
                        kind: modelData.kind
                        accent: modelData.tint
                    }
                }
            }

            FieldLabel {
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: i18n("Order")
            }

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: orderModel

                    delegate: Rectangle {
                        readonly property int rowIndex: index
                        readonly property string mid: model.mid
                        readonly property var entry: root.catalogEntry(mid)
                        readonly property bool on: {
                            var _ = root.showStamp
                            return root.showFor(mid)
                        }

                        implicitHeight: Kirigami.Units.gridUnit * 1.85
                        implicitWidth: chipRow.implicitWidth + Kirigami.Units.smallSpacing * 1.6
                        radius: height / 2
                        opacity: on ? 1.0 : 0.45
                        color: on ? root.alpha(entry.tint, 0.16)
                                  : root.alpha(Kirigami.Theme.textColor, 0.04)
                        border.width: 1
                        border.color: on ? root.alpha(entry.tint, 0.4)
                                         : root.alpha(Kirigami.Theme.textColor, 0.10)

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 0

                            QQC2.ToolButton {
                                icon.name: "go-previous"
                                enabled: rowIndex > 0
                                implicitWidth: Kirigami.Units.gridUnit * 1.3
                                implicitHeight: implicitWidth
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: i18n("Move left")
                                QQC2.ToolTip.visible: hovered
                                onClicked: root.moveItem(rowIndex, -1)
                            }

                            MetricIcon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                kind: entry.kind
                                color: on ? entry.tint : root.muted
                            }

                            QQC2.Label {
                                text: entry.shortLabel
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                font.weight: Font.DemiBold
                                leftPadding: Kirigami.Units.smallSpacing * 0.6
                            }

                            QQC2.ToolButton {
                                icon.name: "go-next"
                                enabled: rowIndex < orderModel.count - 1
                                implicitWidth: Kirigami.Units.gridUnit * 1.3
                                implicitHeight: implicitWidth
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: i18n("Move right")
                                QQC2.ToolTip.visible: hovered
                                onClicked: root.moveItem(rowIndex, 1)
                            }
                        }
                    }
                }
            }

            QQC2.Button {
                text: i18n("Reset order")
                onClicked: {
                    root.cfg_metricOrder = root.defaultOrder.join(",")
                    root.reloadModel()
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Tap a tile to show or hide it. Download and upload stay linked, but you can reorder them independently. Missing readings hide themselves on the panel.")
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
            }
        }

        SectionCard {
            title: i18n("OPTIONS")

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.extraCatalog

                    ToggleTile {
                        required property var modelData
                        mid: modelData.id
                        label: modelData.label
                        kind: modelData.kind
                        accent: modelData.tint
                    }
                }
            }
        }

        SectionCard {
            title: i18n("POLLING")

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 0.5

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        MetricIcon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            kind: "refresh"
                            color: root.teal
                        }
                        QQC2.Label {
                            text: i18n("Refresh interval")
                            font.weight: Font.DemiBold
                        }
                    }

                    QQC2.SpinBox {
                        id: refreshSpin
                        Layout.fillWidth: true
                        from: 2
                        to: 120
                        stepSize: 1
                        textFromValue: function(value, locale) { return i18n("%1 s", value) }
                        valueFromText: function(text, locale) {
                            var n = parseInt(text.replace(/[^0-9]/g, ""), 10)
                            return isNaN(n) ? root.cfg_refreshInterval : n
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing * 0.5

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        MetricIcon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            kind: "clock"
                            color: root.amber
                        }
                        QQC2.Label {
                            text: i18n("Request timeout")
                            font.weight: Font.DemiBold
                        }
                    }

                    QQC2.SpinBox {
                        id: timeoutSpin
                        Layout.fillWidth: true
                        from: 1000
                        to: 30000
                        stepSize: 500
                        textFromValue: function(value, locale) { return i18n("%1 s", (value / 1000).toFixed(1)) }
                        valueFromText: function(text, locale) {
                            var n = parseFloat(text.replace(/[^0-9.]/g, ""))
                            return isNaN(n) ? root.cfg_requestTimeoutMs : Math.round(n * 1000)
                        }
                    }
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                MetricIcon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    kind: "chart"
                    color: root.iconGraphics
                }
                QQC2.Label {
                    text: i18n("History samples")
                    font.weight: Font.DemiBold
                }
            }

            QQC2.SpinBox {
                id: historySpin
                Layout.fillWidth: true
                from: 15
                to: 600
                stepSize: 15
                textFromValue: function(value, locale) { return i18n("%1 samples", value) }
                valueFromText: function(text, locale) {
                    var n = parseInt(text.replace(/[^0-9]/g, ""), 10)
                    return isNaN(n) ? root.cfg_historyLength : n
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("How often the widget polls CasaOS, how long each request may take, and how many sparkline points the popup keeps.")
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
            }
        }

        SectionCard {
            title: i18n("BEHAVIOR")

            FieldLabel { text: i18n("Middle-click action") }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                ChoiceTile {
                    label: i18n("Refresh data")
                    kind: "refresh"
                    selected: root.cfg_middleClickAction === "refresh"
                    onPicked: root.cfg_middleClickAction = "refresh"
                }
                ChoiceTile {
                    label: i18n("Open dashboard")
                    kind: "dashboard"
                    selected: root.cfg_middleClickAction === "dashboard"
                    onPicked: root.cfg_middleClickAction = "dashboard"
                }
                ChoiceTile {
                    label: i18n("Reboot server")
                    kind: "reboot"
                    accent: "#f2596a"
                    selected: root.cfg_middleClickAction === "reboot"
                    onPicked: root.cfg_middleClickAction = "reboot"
                }
                ChoiceTile {
                    label: i18n("Nothing")
                    kind: "dots"
                    selected: root.cfg_middleClickAction === "none"
                    onPicked: root.cfg_middleClickAction = "none"
                }
            }

            FieldLabel { text: i18n("Browser command") }
            QQC2.TextField {
                id: browserField
                Layout.fillWidth: true
                placeholderText: "xdg-open"
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Command used to open the CasaOS dashboard URL. Defaults to xdg-open.")
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
            }
        }
    }
}
