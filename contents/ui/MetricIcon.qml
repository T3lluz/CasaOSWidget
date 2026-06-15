pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

// Canvas-drawn metric icon. We render shapes directly in QML so the
// color binding is instant and there's no dependency on Kirigami.Icon's
// SVG mask recoloring (which is unreliable for non-theme icons and was
// rendering our CPU icon as a solid white square).
//
// Supported kinds: "cpu" "ram" "disk" "down" "up"
//                  "server" "refresh" "dashboard" "reboot"
Item {
    id: root

    property string kind: "cpu"
    property color color: Kirigami.Theme.textColor
    property real strokeWidth: 1.6

    implicitWidth: Kirigami.Units.iconSizes.small
    implicitHeight: Kirigami.Units.iconSizes.small

    Canvas {
        id: cv
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            // draw inside a normalized 24×24 box
            var scale = Math.min(width, height) / 24
            ctx.translate((width  - 24 * scale) / 2,
                          (height - 24 * scale) / 2)
            ctx.scale(scale, scale)

            ctx.strokeStyle = root.color
            ctx.fillStyle   = root.color
            ctx.lineWidth   = root.strokeWidth
            ctx.lineCap     = "round"
            ctx.lineJoin    = "round"

            switch (root.kind) {
            case "cpu":      drawCpu(ctx);      break
            case "ram":      drawRam(ctx);      break
            case "disk":     drawDisk(ctx);     break
            case "down":     drawDown(ctx);     break
            case "up":       drawUp(ctx);       break
            case "server":   drawServer(ctx);   break
            case "refresh":  drawRefresh(ctx);  break
            case "dashboard":drawDashboard(ctx);break
            case "reboot":   drawReboot(ctx);   break
            }
        }

        // ---- shape primitives -----------------------------------------
        function roundRect(ctx, x, y, w, h, r) {
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w - r, y)
            ctx.quadraticCurveTo(x + w, y, x + w, y + r)
            ctx.lineTo(x + w, y + h - r)
            ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
            ctx.lineTo(x + r, y + h)
            ctx.quadraticCurveTo(x, y + h, x, y + h - r)
            ctx.lineTo(x, y + r)
            ctx.quadraticCurveTo(x, y, x + r, y)
            ctx.closePath()
        }

        // ---- icons -----------------------------------------------------
        function drawCpu(ctx) {
            // outer chip body (stroked square)
            roundRect(ctx, 5, 5, 14, 14, 1.8)
            ctx.stroke()
            // inner core (filled square)
            roundRect(ctx, 9, 9, 6, 6, 1)
            ctx.fill()
            // 2 pins on each of the 4 sides — readable at 16px
            ctx.lineWidth = 1.8
            var pins = [9, 15]
            for (var i = 0; i < pins.length; i++) {
                var p = pins[i]
                ctx.beginPath(); ctx.moveTo(p, 5);  ctx.lineTo(p, 2.5);  ctx.stroke()
                ctx.beginPath(); ctx.moveTo(p, 19); ctx.lineTo(p, 21.5); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(5, p);  ctx.lineTo(2.5, p);  ctx.stroke()
                ctx.beginPath(); ctx.moveTo(19, p); ctx.lineTo(21.5, p); ctx.stroke()
            }
        }

        function drawRam(ctx) {
            // outer rect (stroked)
            roundRect(ctx, 2, 7, 20, 10, 1.4)
            ctx.stroke()
            // memory chips on the top half
            for (var i = 0; i < 4; i++) {
                var x = 4.5 + i * 4
                ctx.fillRect(x, 9.2, 2.8, 3.6)
            }
            // pins on the bottom edge
            ctx.lineWidth = 1.2
            for (var j = 0; j < 4; j++) {
                var px = 5.5 + j * 4
                ctx.beginPath(); ctx.moveTo(px, 17); ctx.lineTo(px, 19); ctx.stroke()
            }
        }

        function drawDisk(ctx) {
            ctx.lineWidth = root.strokeWidth
            // top ellipse, drawn with two bezier curves
            ctx.beginPath()
            ctx.moveTo(4, 6)
            ctx.bezierCurveTo(4, 4, 20, 4, 20, 6)
            ctx.bezierCurveTo(20, 8, 4, 8, 4, 6)
            ctx.stroke()
            // body sides
            ctx.beginPath()
            ctx.moveTo(4, 6);  ctx.lineTo(4, 18)
            ctx.moveTo(20, 6); ctx.lineTo(20, 18)
            ctx.stroke()
            // bottom curve
            ctx.beginPath()
            ctx.moveTo(4, 18)
            ctx.bezierCurveTo(4, 20, 20, 20, 20, 18)
            ctx.stroke()
            // middle dividers
            ctx.beginPath()
            ctx.moveTo(4, 11)
            ctx.bezierCurveTo(4, 13, 20, 13, 20, 11)
            ctx.moveTo(4, 15)
            ctx.bezierCurveTo(4, 17, 20, 17, 20, 15)
            ctx.stroke()
        }

        function drawDown(ctx) {
            // shaft
            ctx.lineWidth = 2.4
            ctx.beginPath(); ctx.moveTo(12, 4); ctx.lineTo(12, 16); ctx.stroke()
            // arrow head (filled triangle)
            ctx.beginPath()
            ctx.moveTo(12, 19)
            ctx.lineTo(7, 13)
            ctx.lineTo(17, 13)
            ctx.closePath()
            ctx.fill()
            // baseline
            ctx.lineWidth = 1.8
            ctx.beginPath(); ctx.moveTo(5, 21.5); ctx.lineTo(19, 21.5); ctx.stroke()
        }

        function drawUp(ctx) {
            // baseline (top)
            ctx.lineWidth = 1.8
            ctx.beginPath(); ctx.moveTo(5, 2.5); ctx.lineTo(19, 2.5); ctx.stroke()
            // arrow head (filled triangle, points up)
            ctx.beginPath()
            ctx.moveTo(12, 5)
            ctx.lineTo(7, 11)
            ctx.lineTo(17, 11)
            ctx.closePath()
            ctx.fill()
            // shaft
            ctx.lineWidth = 2.4
            ctx.beginPath(); ctx.moveTo(12, 8); ctx.lineTo(12, 20); ctx.stroke()
        }

        function drawServer(ctx) {
            roundRect(ctx, 3, 3,  18, 7, 1.4); ctx.stroke()
            roundRect(ctx, 3, 14, 18, 7, 1.4); ctx.stroke()
            ctx.beginPath(); ctx.arc(6.5, 6.5, 0.9, 0, Math.PI * 2); ctx.fill()
            ctx.beginPath(); ctx.arc(6.5, 17.5, 0.9, 0, Math.PI * 2); ctx.fill()
            ctx.fillRect(9, 5.8,  8, 1.4)
            ctx.fillRect(9, 16.8, 8, 1.4)
        }

        function drawRefresh(ctx) {
            ctx.lineWidth = 2
            // arc from 0° (right) sweeping clockwise 270° to up (-π/2)
            ctx.beginPath()
            ctx.arc(12, 12, 7.5, 0, Math.PI * 1.5)
            ctx.stroke()
            // arrow head at the open end (top of circle)
            ctx.beginPath()
            ctx.moveTo(12, 4.5)
            ctx.lineTo(8.5, 7.5)
            ctx.lineTo(12, 9.5)
            ctx.closePath()
            ctx.fill()
        }

        function drawDashboard(ctx) {
            roundRect(ctx, 3,  3,  8,  8,  1.2); ctx.fill()
            roundRect(ctx, 13, 3,  8,  5,  1.2); ctx.fill()
            roundRect(ctx, 13, 10, 8,  11, 1.2); ctx.fill()
            roundRect(ctx, 3,  13, 8,  8,  1.2); ctx.fill()
        }

        function drawReboot(ctx) {
            ctx.lineWidth = 2
            ctx.beginPath(); ctx.moveTo(12, 3); ctx.lineTo(12, 12); ctx.stroke()
            ctx.beginPath()
            ctx.arc(12, 13, 8, -Math.PI * 0.85, Math.PI * 1.85)
            ctx.stroke()
        }
    }

    onColorChanged: cv.requestPaint()
    onKindChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()
}
