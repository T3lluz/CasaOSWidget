pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

MouseArea {
    id: root

    required property var api

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    implicitWidth: panelRow.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: Kirigami.Units.gridUnit * 2.25
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

    onClicked: Plasmoid.expanded = !Plasmoid.expanded

    RowLayout {
        id: panelRow
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        // connection status dot
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 8
            height: 8
            radius: 4
            color: api.isConnected ? Kirigami.Theme.positiveTextColor
                : (api.status === "connecting" ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.negativeTextColor)

            SequentialAnimation on opacity {
                running: api.status === "connecting"
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.35; duration: 600 }
                NumberAnimation { from: 0.35; to: 1; duration: 600 }
            }
        }

        ColumnLayout {
            visible: Plasmoid.configuration.compactDisplay < 2
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            PC3.Label {
                text: Plasmoid.configuration.serverName || i18n("Homelab")
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                font.weight: Font.DemiBold
                opacity: 0.85
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 5
            }

            PC3.Label {
                visible: api.cpuTemp >= 0
                text: i18n("%1°C", api.cpuTemp)
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 2
                opacity: 0.65
            }
        }

        Rectangle {
            width: 1
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.smallSpacing / 2
            Layout.bottomMargin: Kirigami.Units.smallSpacing / 2
            color: Kirigami.Theme.separatorColor
            opacity: 0.45
        }

        StatPill {
            iconName: "cpu"
            label: i18n("CPU")
            valueText: api.cpuPercent >= 0 ? Math.round(api.cpuPercent) + "%" : "—"
            percent: api.cpuPercent
            accentColor: api.percentColor(api.cpuPercent)
            showBar: Plasmoid.configuration.compactDisplay === 0
        }

        StatPill {
            iconName: "memory"
            label: i18n("RAM")
            valueText: api.memPercent >= 0 ? Math.round(api.memPercent) + "%" : "—"
            percent: api.memPercent
            accentColor: api.percentColor(api.memPercent)
            showBar: Plasmoid.configuration.compactDisplay === 0
        }

        StatPill {
            iconName: "drive-harddisk-root"
            label: i18n("Disk")
            valueText: api.diskPairText()
            percent: api.diskPercent
            accentColor: api.diskHealthy ? api.percentColor(api.diskPercent) : "#e74c3c"
            showBar: Plasmoid.configuration.compactDisplay === 0
        }
    }
}
