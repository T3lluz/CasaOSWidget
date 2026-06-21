pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string label: ""
    property real percent: -1
    property string centerText: ""
    property string subText: ""
    property color accentColor: Theme.cpu
    property real strokeWidth: 7

    // Track color derives from the active scheme so the ring reads on any
    // background, matching the Power-Deck app pack (THEME_GUIDE §2).
    readonly property color trackColor: Theme.alpha(Kirigami.Theme.textColor, 0.12)

    implicitWidth: Kirigami.Units.gridUnit * 6
    implicitHeight: implicitWidth

    // animated percent so the arc tweens between API updates
    property real _animPercent: percent < 0 ? 0 : percent
    Behavior on _animPercent {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }
    onPercentChanged: _animPercent = Math.max(0, percent)
    on_AnimPercentChanged: ring.requestPaint()
    onAccentColorChanged: ring.requestPaint()
    onTrackColorChanged: ring.requestPaint()

    Canvas {
        id: ring
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var cx = width / 2
            var cy = height / 2
            var r = Math.min(width, height) / 2 - root.strokeWidth
            var start = -Math.PI * 0.75
            var sweep = Math.PI * 1.5
            var p = root.percent >= 0 ? Math.max(0, Math.min(1, root._animPercent / 100)) : 0

            ctx.lineWidth = root.strokeWidth
            ctx.lineCap = "round"

            ctx.strokeStyle = root.trackColor
            ctx.beginPath()
            ctx.arc(cx, cy, r, start, start + sweep)
            ctx.stroke()

            if (p > 0) {
                var grad = ctx.createLinearGradient(0, 0, width, height)
                grad.addColorStop(0, root.accentColor)
                grad.addColorStop(1, Qt.lighter(root.accentColor, 1.25))
                ctx.strokeStyle = grad
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + sweep * p)
                ctx.stroke()
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.centerText.length ? root.centerText : (root.percent >= 0 ? Math.round(root.percent) + "%" : "—")
            font.weight: Font.Bold
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
            color: root.accentColor
            renderType: Text.NativeRendering
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
        }

        Text {
            visible: root.subText.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            text: root.subText
            color: Theme.muted
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 2
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
        }
    }
}
