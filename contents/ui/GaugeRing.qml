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
    property real strokeWidth: 8.5

    // Track color derives from the active scheme so the ring reads on any
    // background, matching the Power-Deck app pack (THEME_GUIDE §2).
    readonly property color trackColor: Theme.alpha(Kirigami.Theme.textColor, 0.12)

    // Bigger, slightly taller than wide so the ring is limited by the column
    // width it is given (FullRepresentation stretches these with fillWidth):
    // the gauge then grows to fill its share of the row instead of being
    // capped at a fixed height.
    implicitWidth: Kirigami.Units.gridUnit * 5.5
    implicitHeight: Kirigami.Units.gridUnit * 7.5

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
            // leave room outside the track for the tick ring
            var r = Math.min(width, height) / 2 - root.strokeWidth - 4
            var start = -Math.PI * 0.75
            var sweep = Math.PI * 1.5
            var p = root.percent >= 0 ? Math.max(0, Math.min(1, root._animPercent / 100)) : 0

            // --- tick ring (detailed dial markings) ----------------------
            // Minor ticks all around; major ticks every sixth. Ticks under
            // the current value light up in the accent, the rest stay a
            // faint scheme-tinted neutral so the gauge reads on any theme.
            var ticks = 36
            for (var t = 0; t <= ticks; t++) {
                var frac = t / ticks
                var ta = start + sweep * frac
                var major = (t % 6 === 0)
                var tOuter = r + root.strokeWidth * 0.5 + 4
                var tInner = tOuter - (major ? 5 : 2.5)
                var lit = frac <= p + 0.0001 && p > 0
                ctx.beginPath()
                ctx.lineWidth = major ? 1.6 : 1
                ctx.strokeStyle = lit
                    ? Theme.alpha(root.accentColor, major ? 0.95 : 0.6)
                    : Theme.alpha(Kirigami.Theme.textColor, major ? 0.22 : 0.11)
                ctx.moveTo(cx + Math.cos(ta) * tInner, cy + Math.sin(ta) * tInner)
                ctx.lineTo(cx + Math.cos(ta) * tOuter, cy + Math.sin(ta) * tOuter)
                ctx.stroke()
            }

            // --- background track ----------------------------------------
            ctx.lineWidth = root.strokeWidth
            ctx.lineCap = "round"
            ctx.strokeStyle = root.trackColor
            ctx.beginPath()
            ctx.arc(cx, cy, r, start, start + sweep)
            ctx.stroke()

            // --- progress arc with gradient + soft glow ------------------
            if (p > 0) {
                var grad = ctx.createLinearGradient(0, 0, width, height)
                grad.addColorStop(0, root.accentColor)
                grad.addColorStop(1, Qt.lighter(root.accentColor, 1.35))

                ctx.save()
                ctx.shadowColor = Theme.alpha(root.accentColor, 0.55)
                ctx.shadowBlur = 9
                ctx.strokeStyle = grad
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + sweep * p)
                ctx.stroke()
                ctx.restore()

                // bright leading head so the value point is easy to spot
                var headA = start + sweep * p
                var hx = cx + Math.cos(headA) * r
                var hy = cy + Math.sin(headA) * r
                ctx.beginPath()
                ctx.fillStyle = Qt.lighter(root.accentColor, 1.4)
                ctx.arc(hx, hy, root.strokeWidth * 0.5, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    // Center stack constrained to the ring's inner diameter so every value,
    // label and sub-line is guaranteed to sit inside the arc and stay
    // horizontally centered. The big value auto-shrinks (HorizontalFit) for
    // wider readings like "82G/467G" instead of spilling over the ring.
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width, root.height) - root.strokeWidth * 2 - Kirigami.Units.largeSpacing * 2
        spacing: 1

        Text {
            Layout.fillWidth: true
            text: root.centerText.length ? root.centerText : (root.percent >= 0 ? Math.round(root.percent) + "%" : "—")
            font.weight: Font.Bold
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 4
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Kirigami.Theme.smallFont.pixelSize
            horizontalAlignment: Text.AlignHCenter
            color: root.accentColor
            renderType: Text.NativeRendering
        }

        Text {
            Layout.fillWidth: true
            text: root.label
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
        }

        Text {
            visible: root.subText.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: root.subText
            color: Theme.muted
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Kirigami.Theme.smallFont.pixelSize - 2
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }
}
