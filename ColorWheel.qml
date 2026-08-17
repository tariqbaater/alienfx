import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

// Hue/saturation wheel plus a brightness slider and live preview. Emits the
// 24-bit hex of the mixed color on every change and `interactionEnded()` when
// the user releases, so callers can apply live and persist on release.
Item {
  id: root

  property color color: "#ff0000"
  property QtObject bar: null

  signal colorPicked(string hex)
  signal interactionEnded()

  readonly property real wheelSize: Math.round(Style.space(150))

  property real hue: 0
  property real sat: 0
  property real value: 1
  property bool _dragging: false
  property bool _internal: false

  implicitWidth: wheelSize
  implicitHeight: wheelSize + Style.space(30)

  readonly property string hexText: {
    var rgb = root.hsvToRgb(root.hue, root.sat, root.value)
    return "#" + root.toHex(rgb[0]) + root.toHex(rgb[1]) + root.toHex(rgb[2])
  }

  onColorChanged: {
    if (!root._internal) root.setFromColor(root.color)
  }

  function toHex(v) {
    return ("0" + v.toString(16)).slice(-2)
  }

  function hsvToRgb(h, s, v) {
    h = ((h % 360) + 360) % 360
    s = Math.max(0, Math.min(1, s))
    v = Math.max(0, Math.min(1, v))
    var c = v * s
    var hp = h / 60
    var x = c * (1 - Math.abs((hp % 2) - 1))
    var m = v - c
    var r = 0, g = 0, b = 0
    if (hp < 1) { r = c; g = x }
    else if (hp < 2) { r = x; g = c }
    else if (hp < 3) { g = c; b = x }
    else if (hp < 4) { g = x; b = c }
    else if (hp < 5) { r = x; b = c }
    else { r = c; b = x }
    return [Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255)]
  }

  function rgbToHsv(r, g, b) {
    r /= 255; g /= 255; b /= 255
    var mx = Math.max(r, g, b)
    var mn = Math.min(r, g, b)
    var d = mx - mn
    var h = 0
    if (d !== 0) {
      if (mx === r) h = 60 * (((g - b) / d) % 6)
      else if (mx === g) h = 60 * ((b - r) / d + 2)
      else h = 60 * ((r - g) / d + 4)
    }
    if (h < 0) h += 360
    return [h, mx === 0 ? 0 : d / mx, mx]
  }

  function setFromColor(c) {
    var hsv = root.rgbToHsv(Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255))
    root._internal = true
    root.hue = hsv[0]
    root.sat = hsv[1]
    root.value = hsv[2]
    root._internal = false
  }

  function emitColor() {
    root._internal = true
    root.color = root.hexText
    root._internal = false
    root.colorPicked(root.hexText)
  }

  Column {
    anchors.fill: parent
    spacing: Style.space(6)

    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.wheelSize
      height: root.wheelSize

      Canvas {
        id: disc
        anchors.fill: parent
        antialiasing: true
        onPaint: {
          var ctx = disc.getContext("2d")
          var w = disc.width
          var h = disc.height
          var cx = w / 2
          var cy = h / 2
          var R = Math.min(cx, cy)
          var img = ctx.createImageData(w, h)
          var d = img.data
          var dx, dy, r, hue, sat, c
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              dx = x - cx
              dy = y - cy
              r = Math.sqrt(dx * dx + dy * dy)
              var i = (y * w + x) * 4
              if (r <= R) {
                hue = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
                sat = r / R
                c = root.hsvToRgb(hue, sat, 1)
                d[i] = c[0]
                d[i + 1] = c[1]
                d[i + 2] = c[2]
                d[i + 3] = 255
              } else {
                d[i + 3] = 0
              }
            }
          }
          ctx.putImageData(img, 0, 0)
        }
        Component.onCompleted: disc.requestPaint()
      }

      MouseArea {
        id: wheelMouse
        anchors.fill: parent
        cursorShape: Qt.CrossCursor

        function pick(mx, my) {
          var w = wheelMouse.width
          var h = wheelMouse.height
          var dx = mx - w / 2
          var dy = my - h / 2
          var R = Math.min(w, h) / 2
          var r = Math.sqrt(dx * dx + dy * dy)
          root.hue = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
          root.sat = Math.max(0, Math.min(1, r / R))
          root.emitColor()
        }

        onPressed: function(m) {
          if (m.button !== Qt.LeftButton) return
          root._dragging = true
          pick(m.x, m.y)
        }
        onPositionChanged: function(m) {
          if (root._dragging) pick(m.x, m.y)
        }
        onReleased: function(m) {
          if (m.button !== Qt.LeftButton) return
          root._dragging = false
          root.interactionEnded()
        }
      }

      Rectangle {
        id: picker
        readonly property real cx: disc.width / 2
        readonly property real cy: disc.height / 2
        readonly property real ringRadius: Math.max(2, Math.min(disc.width, disc.height) / 2 - Style.space(3))
        width: Style.space(14)
        height: Style.space(14)
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: "#ffffff"
        x: cx + Math.cos(root.hue * Math.PI / 180) * root.sat * ringRadius - width / 2
        y: cy + Math.sin(root.hue * Math.PI / 180) * root.sat * ringRadius - height / 2
      }
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(8)

      Rectangle {
        Layout.preferredWidth: Style.space(22)
        Layout.preferredHeight: Style.space(22)
        radius: Style.space(11)
        border.width: 1
        border.color: root.bar ? Qt.darker(root.bar.foreground, 1.6) : "#333"
        color: root.color
      }

      PanelSlider {
        id: valueSlider
        Layout.fillWidth: true
        bar: root.bar
        minimum: 0
        maximum: 1
        step: 0.01
        value: root.value
        onMoved: function(v) {
          root.value = v
          root.emitColor()
        }
        onReleased: function() { root.interactionEnded() }
      }

      Text {
        text: root.hexText.toUpperCase()
        color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }
}