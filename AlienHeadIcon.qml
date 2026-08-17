import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Original Alienware Alpha alien head silhouette, traced from the official
// (Simple Icons, CC0) 24x24 viewBox path. Drawn in the bar's foreground color
// with the two LED zone colors shown as the slanted eyes. Painted in a single
// Canvas so holes and eyes stay aligned and repaint together on color changes.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color eyeLeftColor: Color.foreground
  property color eyeRightColor: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  onColorChanged: canvas.requestPaint()
  onEyeLeftColorChanged: canvas.requestPaint()
  onEyeRightColorChanged: canvas.requestPaint()

  readonly property var headStart: [20.38, 9.41]
  readonly property var headSegs: [
    ["c", 20.32, 8.76, 20.25, 8.04, 20.12, 7.39],
    ["c", 19.99, 6.75, 19.86, 6.1, 19.6, 5.45],
    ["c", 19.47, 5.12, 19.34, 4.8, 19.21, 4.54],
    ["c", 19.08, 4.22, 18.89, 3.96, 18.76, 3.63],
    ["c", 18.57, 3.37, 18.37, 3.05, 18.18, 2.79],
    ["c", 17.98, 2.53, 17.72, 2.27, 17.46, 2.08],
    ["c", 17.01, 1.69, 16.49, 1.3, 15.91, 0.97],
    ["c", 15.32, 0.65, 14.67, 0.39, 14.03, 0.26],
    ["c", 13.38, 0.06, 12.73, 0.0, 12.01, 0.0],
    ["c", 11.3, 0.0, 10.65, 0.06, 10.0, 0.26],
    ["c", 9.36, 0.39, 8.77, 0.65, 8.19, 0.97],
    ["c", 7.54, 1.3, 7.02, 1.69, 6.5, 2.14],
    ["c", 6.24, 2.34, 6.05, 2.59, 5.79, 2.85],
    ["l", 5.2, 3.63],
    ["c", 5.07, 3.96, 4.88, 4.22, 4.75, 4.54],
    ["l", 4.36, 5.51],
    ["c", 4.17, 6.16, 3.97, 6.81, 3.84, 7.46],
    ["c", 3.71, 8.11, 3.65, 8.76, 3.58, 9.47],
    ["c", 3.52, 10.18, 3.58, 10.77, 3.58, 11.42],
    ["c", 3.58, 12.06, 3.65, 12.71, 3.78, 13.43],
    ["l", 3.97, 14.4],
    ["c", 4.04, 14.72, 4.17, 15.05, 4.3, 15.37],
    ["c", 4.75, 16.61, 5.46, 17.77, 6.18, 18.88],
    ["c", 6.57, 19.46, 6.96, 19.98, 7.34, 20.5],
    ["c", 7.73, 21.02, 8.12, 21.6, 8.58, 22.05],
    ["c", 8.77, 22.31, 9.03, 22.51, 9.29, 22.77],
    ["c", 9.55, 22.96, 9.81, 23.16, 10.13, 23.35],
    ["c", 10.39, 23.55, 10.72, 23.68, 11.04, 23.81],
    ["c", 11.17, 23.87, 11.37, 23.94, 11.5, 23.94],
    ["c", 11.69, 23.94, 11.82, 24.0, 12.01, 24.0],
    ["c", 12.21, 24.0, 12.34, 24.0, 12.53, 23.94],
    ["c", 12.73, 23.94, 12.86, 23.87, 12.99, 23.81],
    ["c", 13.31, 23.68, 13.64, 23.55, 13.9, 23.35],
    ["c", 14.15, 23.16, 14.48, 22.96, 14.74, 22.77],
    ["c", 15.0, 22.57, 15.26, 22.31, 15.45, 22.05],
    ["c", 15.91, 21.54, 16.3, 21.02, 16.68, 20.5],
    ["c", 17.07, 19.98, 17.46, 19.39, 17.85, 18.88],
    ["c", 18.57, 17.77, 19.28, 16.61, 19.73, 15.37],
    ["c", 19.86, 15.05, 19.99, 14.72, 20.06, 14.4],
    ["c", 20.12, 14.08, 20.25, 13.75, 20.25, 13.43],
    ["c", 20.38, 12.78, 20.45, 12.13, 20.45, 11.42],
    ["c", 20.45, 10.77, 20.45, 10.05, 20.38, 9.41]
  ]
  readonly property var leftEyeStart: [4.81, 12.06]
  readonly property var leftEyeSegs: [
    ["c", 4.81, 12.06, 8.51, 12.91, 10.91, 17.9],
    ["c", 10.85, 17.9, 4.49, 17.77, 4.81, 12.06]
  ]
  readonly property var rightEyeStart: [13.18, 17.9]
  readonly property var rightEyeSegs: [
    ["c", 15.52, 12.91, 19.28, 12.06, 19.28, 12.06],
    ["c", 19.6, 17.77, 13.18, 17.9, 13.18, 17.9]
  ]

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = canvas.getContext("2d")
      var w = canvas.width
      var h = canvas.height
      ctx.clearRect(0, 0, w, h)

      var s = w / 24
      ctx.save()
      ctx.scale(s, s)

      // Head silhouette in the bar's foreground color.
      ctx.beginPath()
      root.traceSubpath(ctx, root.headStart, root.headSegs)
      ctx.closePath()
      ctx.fillStyle = root.color
      ctx.fill()

      // Punch the eye holes out of the head.
      ctx.globalCompositeOperation = "destination-out"
      ctx.fillStyle = "rgba(0,0,0,1)"
      ctx.beginPath()
      root.traceSubpath(ctx, root.leftEyeStart, root.leftEyeSegs)
      ctx.closePath()
      ctx.fill()
      ctx.beginPath()
      root.traceSubpath(ctx, root.rightEyeStart, root.rightEyeSegs)
      ctx.closePath()
      ctx.fill()
      ctx.globalCompositeOperation = "source-over"

      // Zone-colored eyes.
      ctx.beginPath()
      ctx.fillStyle = root.eyeLeftColor
      root.traceSubpath(ctx, root.leftEyeStart, root.leftEyeSegs)
      ctx.closePath()
      ctx.fill()
      ctx.beginPath()
      ctx.fillStyle = root.eyeRightColor
      root.traceSubpath(ctx, root.rightEyeStart, root.rightEyeSegs)
      ctx.closePath()
      ctx.fill()

      ctx.restore()
    }
  }

  // Traces one SVG subpath: "l" segments are linetos, "c" are cubic beziers
  // [c1x, c1y, c2x, c2y, ex, ey] in the 24x24 viewBox.
  function traceSubpath(ctx, start, segs) {
    ctx.moveTo(start[0], start[1])
    for (var i = 0; i < segs.length; ++i) {
      var s = segs[i]
      if (s[0] === "l") ctx.lineTo(s[1], s[2])
      else ctx.bezierCurveTo(s[1], s[2], s[3], s[4], s[5], s[6])
    }
  }
}