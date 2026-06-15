pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmaExtras.Representation {
    id: root

    required property var api

    collapseMarginsHint: true
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.maximumWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: body.implicitHeight + Kirigami.Units.largeSpacing * 2
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        function run(cmd) {
            disconnectSource(cmd)
            connectSource(cmd)
        }
    }

    function openDashboard() {
        exec.run("xdg-open " + api.normalizedBaseUrl())
    }

    component SectionCard: Rectangle {
        default property alias content: inner.data

        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.smallSpacing * 1.5
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.045)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing
        }
    }

    component StatBar: ColumnLayout {
        required property string label
        required property real percent
        required property string detail
        property color barColor: api.percentColor(percent)

        spacing: Kirigami.Units.smallSpacing / 2
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: label
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            PC3.Label {
                text: detail
                opacity: 0.8
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            radius: 4
            color: Kirigami.Theme.alternateBackgroundColor

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, percent / 100))
                height: parent.height
                radius: parent.radius
                color: barColor
                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            }
        }
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.gridUnit

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "computer"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PC3.Label {
                    text: Plasmoid.configuration.serverName || i18n("Homelab")
                    font.weight: Font.Bold
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
                }

                PC3.Label {
                    text: api.isConnected
                        ? i18n("Online · CasaOS %1", api.casaVersion || "?")
                        : (api.statusMessage || i18n("Offline"))
                    opacity: 0.75
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: api.isConnected ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                }
            }

            PC3.Button {
                icon.name: "view-refresh"
                display: PC3.AbstractButton.IconOnly
                onClicked: api.refresh()
            }

            PC3.Button {
                icon.name: "internet-services"
                display: PC3.AbstractButton.IconOnly
                onClicked: openDashboard()
            }
        }

        // gauge rings
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignHCenter

            GaugeRing {
                label: i18n("CPU")
                percent: api.cpuPercent
                accentColor: api.percentColor(api.cpuPercent)
                subText: api.cpuTemp >= 0 ? i18n("%1°C · %2 cores", api.cpuTemp, api.cpuCores) : ""
                Layout.fillWidth: true
            }

            GaugeRing {
                label: i18n("RAM")
                percent: api.memPercent
                accentColor: api.percentColor(api.memPercent)
                centerText: api.memPercent >= 0 ? Math.round(api.memPercent) + "%" : "—"
                subText: api.formatBytesShort(api.memUsed) + "/" + api.formatBytesShort(api.memTotal)
                Layout.fillWidth: true
            }

            GaugeRing {
                label: i18n("Disk")
                percent: api.diskPercent
                accentColor: api.diskHealthy ? api.percentColor(api.diskPercent) : "#e74c3c"
                centerText: api.diskPairText()
                subText: api.diskHealthy ? i18n("%1 free", api.formatBytes(api.diskAvail || (api.diskTotal - api.diskUsed))) : i18n("Health warning")
                Layout.fillWidth: true
            }
        }

        // history charts
        SectionCard {
            Kirigami.Heading {
                level: 3
                text: i18n("History")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.gridUnit

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing / 2

                    PC3.Label {
                        text: i18n("CPU")
                        font.weight: Font.DemiBold
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    SparklineChart {
                        samples: api.cpuHistory
                        lineColor: api.percentColor(api.cpuPercent)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing / 2

                    PC3.Label {
                        text: i18n("RAM")
                        font.weight: Font.DemiBold
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                    SparklineChart {
                        samples: api.memHistory
                        lineColor: api.percentColor(api.memPercent)
                    }
                }
            }
        }

        // detailed bars
        SectionCard {
            Kirigami.Heading {
                level: 3
                text: i18n("Resources")
            }

            StatBar {
                label: i18n("CPU load")
                percent: api.cpuPercent
                detail: api.cpuModel + (api.cpuCores > 0 ? " · " + i18n("%1 cores", api.cpuCores) : "")
            }

            StatBar {
                label: i18n("Memory")
                percent: api.memPercent
                detail: api.formatBytes(api.memUsed) + " / " + api.formatBytes(api.memTotal)
            }

            StatBar {
                label: i18n("Storage")
                percent: api.diskPercent
                detail: api.diskPairLongText()
                barColor: api.diskHealthy ? api.percentColor(api.diskPercent) : "#e74c3c"
            }
        }

        // network
        SectionCard {
            visible: api.networkInterfaces.length > 0
            Layout.fillWidth: true

            Kirigami.Heading {
                level: 3
                text: i18n("Network")
            }

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "download" }
                PC3.Label { text: i18n("Download") }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    text: api.formatRate(api.netRxRate)
                    font.weight: Font.Bold
                    color: "#3daee9"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "upload" }
                PC3.Label { text: i18n("Upload") }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    text: api.formatRate(api.netTxRate)
                    font.weight: Font.Bold
                    color: "#1cdc9a"
                }
            }

            Repeater {
                model: api.networkInterfaces.slice(0, 4)

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        source: modelData.state === "up" ? "network-wired-activated" : "network-wired"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }

                    PC3.Label {
                        text: modelData.name
                        font.weight: Font.DemiBold
                        Layout.preferredWidth: 80
                    }

                    PC3.Label {
                        text: i18n("↓ %1 · ↑ %2",
                                   api.formatBytes(modelData.bytesRecv),
                                   api.formatBytes(modelData.bytesSent))
                        opacity: 0.8
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // services health
        SectionCard {
            visible: api.servicesTotalCount > 0
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Heading {
                    level: 3
                    text: i18n("CasaOS services")
                    Layout.fillWidth: true
                }
                PC3.Label {
                    text: i18n("%1 / %2 running", api.servicesHealthyCount, api.servicesTotalCount)
                    font.weight: Font.Bold
                    color: api.servicesStopped.length === 0
                        ? Kirigami.Theme.positiveTextColor
                        : Kirigami.Theme.neutralTextColor
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: api.servicesRunning
                    delegate: Rectangle {
                        required property string modelData
                        radius: Kirigami.Units.smallSpacing
                        color: Qt.rgba(Kirigami.Theme.positiveTextColor.r, Kirigami.Theme.positiveTextColor.g, Kirigami.Theme.positiveTextColor.b, 0.12)
                        implicitWidth: svcLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                        implicitHeight: svcLabel.implicitHeight + Kirigami.Units.smallSpacing

                        PC3.Label {
                            id: svcLabel
                            anchors.centerIn: parent
                            text: modelData.replace(/\.service$/, "")
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                        }
                    }
                }

                Repeater {
                    model: api.servicesStopped
                    delegate: Rectangle {
                        required property string modelData
                        radius: Kirigami.Units.smallSpacing
                        color: Qt.rgba(Kirigami.Theme.negativeTextColor.r, Kirigami.Theme.negativeTextColor.g, Kirigami.Theme.negativeTextColor.b, 0.12)
                        implicitWidth: svcOffLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                        implicitHeight: svcOffLabel.implicitHeight + Kirigami.Units.smallSpacing

                        PC3.Label {
                            id: svcOffLabel
                            anchors.centerIn: parent
                            text: modelData.replace(/\.service$/, "")
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                            color: Kirigami.Theme.negativeTextColor
                        }
                    }
                }
            }
        }

        // system info
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.gridUnit
            rowSpacing: Kirigami.Units.smallSpacing

            PC3.Label { text: i18n("Hardware"); opacity: 0.75 }
            PC3.Label {
                text: api.hardwareModel || "—"
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            PC3.Label { text: i18n("Architecture"); opacity: 0.75 }
            PC3.Label {
                text: api.hardwareArch || "—"
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }

            PC3.Label { text: i18n("Server"); opacity: 0.75 }
            PC3.Label {
                text: api.normalizedBaseUrl().replace(/^https?:\/\//, "")
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }
        }
    }
}
