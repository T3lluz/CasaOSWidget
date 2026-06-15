pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Canvas {
    id: root

    property var samples: []
    property color lineColor: "#22d3ee"
    property color baselineColor: "#232733"
    property real minValue: 0
    property real maxValue: 100
    // when autoScale is true, maxValue is derived from samples (with padding)
    property bool autoScale: false
    property real autoScaleMin: 0
    property bool drawGrid: true
    property color gridColor: "#1d2129"

    implicitHeight: Kirigami.Units.gridUnit * 2.5
    Layout.fillWidth: true

    antialiasing: true

    onSamplesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onMinValueChanged: requestPaint()
    onMaxValueChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        var pad = 2
        var w = width - pad * 2
        var h = height - pad * 2

        if (drawGrid) {
            ctx.strokeStyle = gridColor
            ctx.lineWidth = 1
            ctx.beginPath()
            for (var g = 1; g < 4; g++) {
                var y = pad + (h / 4) * g
                ctx.moveTo(pad, y)
                ctx.lineTo(pad + w, y)
            }
            ctx.stroke()
        }

        if (!samples || samples.length < 2) {
            ctx.strokeStyle = baselineColor
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(pad, pad + h - 1)
            ctx.lineTo(pad + w, pad + h - 1)
            ctx.stroke()
            return
        }

        var lo = minValue
        var hi = maxValue
        if (autoScale) {
            var localMax = autoScaleMin
            for (var k = 0; k < samples.length; k++) {
                if (samples[k] > localMax) localMax = samples[k]
            }
            hi = localMax * 1.15
            if (hi <= lo) hi = lo + 1
        }
        var range = hi - lo
        if (range <= 0) range = 1

        function xFor(i) { return pad + (i / (samples.length - 1)) * w }
        function yFor(v) {
            var t = (v - lo) / range
            if (t < 0) t = 0
            if (t > 1) t = 1
            return pad + h - t * h
        }

        ctx.beginPath()
        ctx.moveTo(xFor(0), yFor(samples[0]))
        for (var i = 1; i < samples.length; i++) {
            var x = xFor(i)
            var y = yFor(samples[i])
            var px = xFor(i - 1)
            var py = yFor(samples[i - 1])
            var cx1 = (px + x) / 2
            ctx.bezierCurveTo(cx1, py, cx1, y, x, y)
        }
        ctx.lineTo(pad + w, pad + h)
        ctx.lineTo(pad, pad + h)
        ctx.closePath()
        var grad = ctx.createLinearGradient(0, pad, 0, pad + h)
        grad.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.35))
        grad.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.0))
        ctx.fillStyle = grad
        ctx.fill()

        ctx.beginPath()
        ctx.moveTo(xFor(0), yFor(samples[0]))
        for (var j = 1; j < samples.length; j++) {
            var x2 = xFor(j)
            var y2 = yFor(samples[j])
            var px2 = xFor(j - 1)
            var py2 = yFor(samples[j - 1])
            var cx2 = (px2 + x2) / 2
            ctx.bezierCurveTo(cx2, py2, cx2, y2, x2, y2)
        }
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 1.8
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()

        var lastX = xFor(samples.length - 1)
        var lastY = yFor(samples[samples.length - 1])
        ctx.beginPath()
        ctx.arc(lastX, lastY, 2.5, 0, Math.PI * 2)
        ctx.fillStyle = lineColor
        ctx.fill()
    }
}
