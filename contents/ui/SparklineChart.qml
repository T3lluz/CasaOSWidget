import QtQuick
import org.kde.kirigami as Kirigami

Canvas {
    id: root

    property var samples: []
    property color lineColor: "#3daee9"
    property color fillColor: Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.15)
    property real minValue: 0
    property real maxValue: 100

    implicitHeight: Kirigami.Units.gridUnit * 2.2
    Layout.fillWidth: true

    onSamplesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        if (!samples || samples.length < 2) {
            return
        }

        var pad = 2
        var w = width - pad * 2
        var h = height - pad * 2
        var lo = minValue
        var hi = maxValue
        var range = hi - lo
        if (range <= 0) {
            range = 1
        }

        function yFor(v) {
            var t = (v - lo) / range
            return pad + h - t * h
        }

        ctx.beginPath()
        for (var i = 0; i < samples.length; i++) {
            var x = pad + (i / (samples.length - 1)) * w
            var y = yFor(samples[i])
            if (i === 0) {
                ctx.moveTo(x, y)
            } else {
                ctx.lineTo(x, y)
            }
        }

        ctx.lineTo(pad + w, pad + h)
        ctx.lineTo(pad, pad + h)
        ctx.closePath()
        ctx.fillStyle = fillColor
        ctx.fill()

        ctx.beginPath()
        for (var j = 0; j < samples.length; j++) {
            var x2 = pad + (j / (samples.length - 1)) * w
            var y2 = yFor(samples[j])
            if (j === 0) {
                ctx.moveTo(x2, y2)
            } else {
                ctx.lineTo(x2, y2)
            }
        }
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()
    }
}
