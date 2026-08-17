import QtQuick
import Quickshell
import Quickshell.Io

// Headless bridge to alienware-cli. Exposes current zone colors, presets, and
// write functions. The CLI needs no sudo because /etc/udev/rules.d/
// 90-alienware-rgb.rules makes the sysfs control files world-writable.
QtObject {
  id: root

  readonly property string cliPath: "/usr/local/bin/alienware-cli"

  readonly property var presetColors: ({
    "Off":     [0, 0, 0],
    "Red":     [15, 0, 0],
    "Green":   [0, 15, 0],
    "Blue":    [0, 0, 15],
    "Cyan":    [0, 15, 15],
    "Magenta": [15, 0, 15],
    "Yellow":  [15, 15, 0],
    "White":   [15, 15, 15]
  })

  property bool available: false
  property bool present: false
  property bool busy: false
  property string error: ""
  property string activePreset: "Off"
  property int headRed: 0
  property int headGreen: 0
  property int headBlue: 0
  property int leftRed: 0
  property int leftGreen: 0
  property int leftBlue: 0

  property var _pendingParts: []
  property string _readError: ""
  property string _writeOut: ""
  property string _writeErr: ""

  readonly property string headHex: root.hex(root.headRed, root.headGreen, root.headBlue)
  readonly property string leftHex: root.hex(root.leftRed, root.leftGreen, root.leftBlue)

  function clamp(value) {
    return Math.max(0, Math.min(15, Math.round(Number(value) || 0)))
  }

  function toHex8(value) {
    return ("0" + Math.round(root.clamp(value) * 255 / 15).toString(16)).slice(-2)
  }

  function hex(r, g, b) {
    return "#" + root.toHex8(r) + root.toHex8(g) + root.toHex8(b)
  }

  function hexToRgb(hex) {
    var s = String(hex || "#000000").replace(/^#/, "")
    if (s.length === 3) {
      s = s.charAt(0) + s.charAt(0) + s.charAt(1) + s.charAt(1) + s.charAt(2) + s.charAt(2)
    }
    if (s.length !== 6) return [0, 0, 0]
    var r = parseInt(s.substr(0, 2), 16)
    var g = parseInt(s.substr(2, 2), 16)
    var b = parseInt(s.substr(4, 2), 16)
    if (isNaN(r)) r = 0
    if (isNaN(g)) g = 0
    if (isNaN(b)) b = 0
    return [root.clamp(r * 15 / 255), root.clamp(g * 15 / 255), root.clamp(b * 15 / 255)]
  }

  function presetNames() {
    var names = []
    for (var key in root.presetColors) names.push(key)
    return names
  }

  function presetHex(name) {
    var color = root.presetColors[String(name)] || root.presetColors.Off
    return root.hex(color[0], color[1], color[2])
  }

  function refresh() {
    if (readProcess.running) return
    root._readError = ""
    readProcess.running = true
  }

  function applyPreset(name) {
    var key = String(name || "Off")
    var color = root.presetColors[key] || root.presetColors.Off
    root.activePreset = key
    root.setZones(color[0], color[1], color[2])
  }

  function applyColor(hex) {
    var rgb = root.hexToRgb(hex)
    root.activePreset = "Custom"
    root.setZones(rgb[0], rgb[1], rgb[2])
  }

  function cycle(direction) {
    var names = root.presetNames()
    var index = names.indexOf(root.activePreset)
    if (index < 0) index = 0
    var step = direction === 0 ? 0 : (direction || 1)
    index = (index + step + names.length) % names.length
    root.applyPreset(names[index])
  }

  function setHead(r, g, b) {
    root.headRed = root.clamp(r)
    root.headGreen = root.clamp(g)
    root.headBlue = root.clamp(b)
    root.queueWrite("-H", root.headRed + " " + root.headGreen + " " + root.headBlue)
  }

  function setLeft(r, g, b) {
    root.leftRed = root.clamp(r)
    root.leftGreen = root.clamp(g)
    root.leftBlue = root.clamp(b)
    root.queueWrite("-L", root.leftRed + " " + root.leftGreen + " " + root.leftBlue)
  }

  function setZones(r, g, b) {
    root.setHead(r, g, b)
    root.setLeft(r, g, b)
  }

  function queueWrite(flag, value) {
    root._pendingParts = root._pendingParts.concat([flag, value])
    Qt.callLater(root.flushWrites)
  }

  function flushWrites() {
    if (writeProcess.running) return
    if (root._pendingParts.length === 0) return
    writeProcess.command = [root.cliPath].concat(root._pendingParts)
    root._pendingParts = []
    root.busy = true
    writeProcess.running = true
  }

  function applyRead(raw) {
    var text = String(raw || "").trim()
    if (text === "") return
    var data = null
    try {
      data = JSON.parse(text)
    } catch (error) {
      root.error = String(error)
      return
    }
    if (!data || !data.leds) return
    root.available = data.leds.exists === true
    root.present = root.available
    root.error = root.available ? "" : (root._readError || "Alienware LED unit not detected")
    if (!root.available) return
    var head = data.leds.head
    var left = data.leds.left
    if (head) {
      root.headRed = head.red
      root.headGreen = head.green
      root.headBlue = head.blue
    }
    if (left) {
      root.leftRed = left.red
      root.leftGreen = left.green
      root.leftBlue = left.blue
    }
  }

  property Process readProcess: Process {
    command: [root.cliPath, "-j", "-l"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyRead(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._readError = String(text).trim()
    }
    onExited: function(code) {
      if (code !== 0) {
        root.available = false
        root.present = false
        root.error = root._readError || ("alienware-cli exited " + code)
      }
    }
  }

  property Process writeProcess: Process {
    running: false
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._writeOut = String(text).trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._writeErr = String(text).trim()
    }
    onExited: function(code) {
      root.busy = false
      var out = root._writeOut
      var err = root._writeErr
      root._writeOut = ""
      root._writeErr = ""
      if (out.indexOf("permission") >= 0 || err.indexOf("permission") >= 0
          || out.indexOf("do you need sudo") >= 0 || err.indexOf("do you need sudo") >= 0)
        root.error = "Write permission denied (check the udev rule)"
      else if (out.indexOf("no alienware LED unit") >= 0
          || err.indexOf("no alienware LED unit") >= 0)
        root.error = "Alienware LED unit not detected"
      else if (code !== 0)
        root.error = "alienware-cli exited " + code
      else
        root.error = root.available ? "" : root.error

      if (root._pendingParts.length > 0) root.flushWrites()
      else root.refresh()
    }
  }

  property Timer refreshTimer: Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    root.busy = false
    root.refresh()
  }
}