pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string label: ""
    property real percent: -1
    property string centerText: ""
    property string subText: ""
    property color accentColor: "#3daee9"

    implicitWidth: Kirigami.Units.gridUnit * 5.5
    implicitHeight: implicitWidth

    Canvas {
        id: ring
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var cy = height / 2
            var r = Math.min(width, height) / 2 - 4
            var start = -Math.PI * 0.75
            var sweep = Math.PI * 1.5
            var p = percent >= 0 ? Math.max(0, Math.min(1, percent / 100)) : 0

            ctx.lineWidth = 6
            ctx.lineCap = "round"
            ctx.strokeStyle = Kirigami.Theme.alternateBackgroundColor
            ctx.beginPath()
            ctx.arc(cx, cy, r, start, start + sweep)
            ctx.stroke()

            if (p > 0) {
                ctx.strokeStyle = accentColor
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + sweep * p)
                ctx.stroke()
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        PC3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: centerText.length ? centerText : (percent >= 0 ? Math.round(percent) + "%" : "—")
            font.weight: Font.Bold
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            color: accentColor
        }

        PC3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: label
            opacity: 0.75
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
            font.weight: Font.DemiBold
        }

        PC3.Label {
            visible: subText.length > 0
            Layout.alignment: Qt.AlignHCenter
            text: subText
            opacity: 0.65
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 2
            horizontalAlignment: Text.AlignHCenter
        }
    }

    onPercentChanged: ring.requestPaint()
    onAccentColorChanged: ring.requestPaint()
}
