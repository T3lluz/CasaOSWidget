pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string iconName: ""
    property string label: ""
    property string valueText: ""
    property real percent: -1
    property color accentColor: "#3daee9"
    property bool showBar: true

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        spacing: Kirigami.Units.smallSpacing / 3

        RowLayout {
            spacing: Kirigami.Units.smallSpacing / 2

            Kirigami.Icon {
                visible: iconName.length > 0
                source: iconName
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                color: accentColor
            }

            PC3.Label {
                text: label
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
                font.weight: Font.DemiBold
                opacity: 0.8
            }
        }

        PC3.Label {
            text: valueText
            font.weight: Font.Bold
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize + 1
            color: accentColor
        }

        Rectangle {
            visible: showBar && percent >= 0
            Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 4.5, valueText.length * 7)
            Layout.preferredHeight: 5
            radius: 2.5
            color: Kirigami.Theme.alternateBackgroundColor

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, percent / 100))
                height: parent.height
                radius: parent.radius
                color: accentColor

                Behavior on width {
                    NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
