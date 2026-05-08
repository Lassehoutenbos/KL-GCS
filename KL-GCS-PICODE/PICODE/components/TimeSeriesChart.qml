import QtQuick
import PICODE

// Generic time-series chart.
// `series` is an array of:
//   { color, label, unit, data: [{t (ms), v (number)}], min?, max? }
// Auto y-axis from data unless min/max set on the series.
Item {
    id: root

    property var series: []
    property color gridColor: Theme.border
    property color labelColor: Theme.textDisabled
    property color cursorColor: Theme.accentYellow

    property real paddingLeft:   42
    property real paddingRight:  10
    property real paddingTop:    10
    property real paddingBottom: 22

    property bool sparkline: false           // strips axes/labels
    property int  yTickCount: 4
    property int  xTickCount: 5
    property bool showLegend: !sparkline

    // Time window: pass explicit windowMs to clip; 0 = use full data range.
    property real windowMs: 0

    onSeriesChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onWindowMsChanged: canvas.requestPaint()

    Timer { interval: 1000; running: true; repeat: true; onTriggered: canvas.requestPaint() }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Cooperative

        function bounds() {
            var tMin = Infinity, tMax = -Infinity, vMin = Infinity, vMax = -Infinity
            for (var i = 0; i < root.series.length; i++) {
                var s = root.series[i]
                var arr = s.data || []
                for (var j = 0; j < arr.length; j++) {
                    var p = arr[j]
                    if (p.t < tMin) tMin = p.t
                    if (p.t > tMax) tMax = p.t
                    if (p.v < vMin) vMin = p.v
                    if (p.v > vMax) vMax = p.v
                }
                if (s.min !== undefined) vMin = Math.min(vMin, s.min)
                if (s.max !== undefined) vMax = Math.max(vMax, s.max)
            }
            if (root.windowMs > 0 && isFinite(tMax)) {
                tMin = tMax - root.windowMs
            }
            if (!isFinite(tMin) || !isFinite(tMax)) { tMin = 0; tMax = 1 }
            if (!isFinite(vMin) || !isFinite(vMax)) { vMin = 0; vMax = 1 }
            if (tMax - tMin < 1) tMax = tMin + 1
            if (vMax - vMin < 0.0001) { vMax += 0.5; vMin -= 0.5 }
            // pad y-range 6%
            var pad = (vMax - vMin) * 0.08
            vMin -= pad; vMax += pad
            return { tMin: tMin, tMax: tMax, vMin: vMin, vMax: vMax }
        }

        function fmtTime(ms) {
            var d = new Date(ms)
            function pad(n){ return n < 10 ? "0"+n : ""+n }
            return pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds())
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            ctx.clearRect(0, 0, w, h)

            var pl = root.sparkline ? 2 : root.paddingLeft
            var pr = root.sparkline ? 2 : root.paddingRight
            var pt = root.sparkline ? 2 : root.paddingTop
            var pb = root.sparkline ? 2 : root.paddingBottom
            var plotW = Math.max(1, w - pl - pr)
            var plotH = Math.max(1, h - pt - pb)

            var b = bounds()
            function xOf(t) { return pl + (t - b.tMin) / (b.tMax - b.tMin) * plotW }
            function yOf(v) { return pt + (1 - (v - b.vMin) / (b.vMax - b.vMin)) * plotH }

            // Background gridlines
            if (!root.sparkline) {
                ctx.strokeStyle = Qt.rgba(1,1,1,0.04)
                ctx.lineWidth = 1
                ctx.beginPath()
                for (var i = 0; i <= root.yTickCount; i++) {
                    var y = pt + (i / root.yTickCount) * plotH
                    ctx.moveTo(pl, y); ctx.lineTo(pl + plotW, y)
                }
                ctx.stroke()

                // Y labels
                ctx.fillStyle = root.labelColor
                ctx.font = "10px " + Theme.fontMono
                ctx.textAlign = "right"
                ctx.textBaseline = "middle"
                for (var k = 0; k <= root.yTickCount; k++) {
                    var v = b.vMax - (k / root.yTickCount) * (b.vMax - b.vMin)
                    ctx.fillText(v.toFixed(Math.abs(v) >= 100 ? 0 : 1), pl - 4, pt + (k / root.yTickCount) * plotH)
                }

                // X labels
                ctx.textAlign = "center"
                ctx.textBaseline = "top"
                for (var m = 0; m <= root.xTickCount; m++) {
                    var t = b.tMin + (m / root.xTickCount) * (b.tMax - b.tMin)
                    ctx.fillText(fmtTime(t), pl + (m / root.xTickCount) * plotW, h - pb + 3)
                }

                // Border
                ctx.strokeStyle = root.gridColor
                ctx.lineWidth = 1
                ctx.strokeRect(pl + 0.5, pt + 0.5, plotW, plotH)
            }

            // Series lines
            for (var si = 0; si < root.series.length; si++) {
                var s = root.series[si]
                var arr = s.data || []
                if (arr.length === 0) continue
                ctx.strokeStyle = s.color || Theme.accentBlue
                ctx.lineWidth = root.sparkline ? 1.5 : 1.8
                ctx.beginPath()
                var started = false
                for (var n = 0; n < arr.length; n++) {
                    var p = arr[n]
                    if (root.windowMs > 0 && p.t < b.tMin) continue
                    var x = xOf(p.t), y = yOf(p.v)
                    if (!started) { ctx.moveTo(x, y); started = true }
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()

                // Last value dot
                if (!root.sparkline && arr.length > 0) {
                    var lp = arr[arr.length - 1]
                    ctx.fillStyle = s.color || Theme.accentBlue
                    ctx.beginPath()
                    ctx.arc(xOf(lp.t), yOf(lp.v), 2.2, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }
}
