import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

// Bar widget for the Alienfx service. Left click cycles presets; right click
// opens a preset picker with a color wheel for mixing custom colors. State
// (head/left zone colors) comes from the paired service, reached through
// bar.shell.serviceFor(moduleName).
Panel {
  id: root
  moduleName: "tariq.alienfx"
  ipcTarget: moduleName

  readonly property var activity: bar && bar.shell
    ? bar.shell.serviceFor(moduleName) : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool unavailable: !activity || !activity.available
  readonly property string currentPreset: activity ? activity.activePreset : "Off"
  readonly property string tooltip: unavailable
    ? "Alienfx · not detected"
    : "Alienfx · " + currentPreset + " · Head #" + activity.headHex
      + " · Left #" + activity.leftHex

  property int menuIndex: 0
  property string mixedColorPreview: "#000000"

  function presetNames() {
    var names = activity ? activity.presetNames() : []
    names.push("Custom")
    return names
  }

  function persistPreset(name) {
    if (!activity) return
    var next = {}
    for (var key in settings) if (key !== "id") next[key] = settings[key]
    next.preset = String(name)
    settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, next)
  }

  function persistColor(hex) {
    var next = {}
    for (var key in settings) if (key !== "id") next[key] = settings[key]
    next.preset = "Custom"
    next.customColor = hex
    delete next.headColor
    delete next.leftColor
    settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, next)
  }

  function persistZoneColor(zone, hex) {
    if (!activity) return
    var next = {}
    for (var key in settings) if (key !== "id") next[key] = settings[key]
    next.preset = "Custom"
    next[zone] = hex
    settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, next)
  }

  function persistHeadColor(hex) {
    root.persistZoneColor("headColor", hex)
  }

  function persistLeftColor(hex) {
    root.persistZoneColor("leftColor", hex)
  }

  function applyPreset(name) {
    if (!activity) return
    if (name === "Custom") {
      activity.applyColor(root.mixedColorPreview)
      root.persistPreset("Custom")
      return
    }
    activity.applyPreset(name)
    root.persistPreset(activity.activePreset)
  }

  function cyclePreset(direction) {
    if (!activity) return
    activity.cycle(direction === undefined ? 1 : direction)
    root.persistPreset(activity.activePreset)
  }

  function onWheelColor(hex) {
    if (!activity) return
    activity.applyColor(hex)
    root.mixedColorPreview = hex
  }

  function syncFromSetting() {
    if (!activity) return
    var stored = String(setting("preset", "Off"))
    if (stored === "Custom") {
      var hc = String(setting("headColor", ""))
      var lc = String(setting("leftColor", ""))
      var cc = String(setting("customColor", "#000000"))
      root.mixedColorPreview = cc
      if (hc || lc) {
        if (hc) activity.setHeadHex(hc)
        else if (cc) activity.setHeadHex(cc)
        if (lc) activity.setLeftHex(lc)
        else if (cc) activity.setLeftHex(cc)
        return
      }
      if (activity.activePreset !== "Custom") activity.applyColor(cc)
      return
    }
    if (activity.activePreset !== stored) activity.applyPreset(stored)
  }

  readonly property int menuCount: presetNames().length

  function moveCursor(dy) {
    if (menuCount <= 1) return
    menuIndex = (menuIndex + dy + menuCount) % menuCount
  }

  function activateCursor() {
    var names = presetNames()
    if (names.length === 0) return
    applyPreset(names[menuIndex])
    close()
  }

  onActivityChanged: Qt.callLater(root.syncFromSetting)
  onSettingsChanged: Qt.callLater(root.syncFromSetting)
  Component.onCompleted: {
    root.mixedColorPreview = String(setting("customColor", "#000000"))
    Qt.callLater(root.syncFromSetting)
  }
  onOpenedChanged: if (opened) {
    var idx = presetNames().indexOf(currentPreset)
    menuIndex = idx < 0 ? 0 : idx
    if (colorWheel) colorWheel.color = root.activity ? root.activity.headHex : "#000000"
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.opened
    dimmed: root.unavailable
    tooltipText: root.tooltip
    iconComponent: Component {
      AlienHeadIcon {
        anchors.centerIn: parent
        iconSize: Style.space(11)
        color: "white"
        eyeLeftColor: root.activity ? root.activity.headHex : root.dim
        eyeRightColor: root.activity ? root.activity.leftHex : root.dim
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.cyclePreset(1)
      else if (buttonCode === Qt.RightButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(360))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: hexHead.editing || hexLeft.editing
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "Alienfx"
          meta: root.unavailable ? "Not detected"
            : "Head #" + root.activity.headHex + " · Left #" + root.activity.leftHex
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        PanelSeparator { foreground: root.foreground }

        RowLayout {
          width: parent.width
          spacing: Style.space(16)

          Column {
            Layout.fillWidth: true
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "Presets"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.presetNames()
              delegate: PresetRow {
                label: modelData
                color: modelData === "Custom"
                  ? root.mixedColorPreview
                  : (root.activity ? root.activity.presetHex(modelData) : "#000000")
                hasCursor: root.menuIndex === index
                current: root.currentPreset === modelData
                onHovered: function(on) { if (on) root.menuIndex = index }
                onClicked: root.applyPreset(modelData)
              }
            }
          }

          Column {
            width: Math.max(Style.space(150), colorWheel.implicitWidth)
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "Color"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ColorWheel {
              id: colorWheel
              anchors.horizontalCenter: parent.horizontalCenter
              bar: root.bar
              onColorPicked: function(hex) { root.onWheelColor(hex) }
              onInteractionEnded: {
                if (root.activity) root.persistColor(colorWheel.hexText)
              }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        RowLayout {
          width: parent.width
          spacing: Style.space(10)

          HexInput {
            id: hexHead
            Layout.fillWidth: true
            label: "Head"
            value: root.activity ? root.activity.headHex : "#000000"
            onCommitted: function(hex) {
              if (!root.activity) return
              root.activity.setHeadHex(hex)
              root.persistHeadColor(hex)
              root.mixedColorPreview = hex
            }
          }

          HexInput {
            id: hexLeft
            Layout.fillWidth: true
            label: "Left"
            value: root.activity ? root.activity.leftHex : "#000000"
            onCommitted: function(hex) {
              if (!root.activity) return
              root.activity.setLeftHex(hex)
              root.persistLeftColor(hex)
              root.mixedColorPreview = hex
            }
          }
        }
      }
    }
  }

  component PresetRow: CursorSurface {
    id: row

    property string label: ""
    property string color: "#000000"
    property bool current: false

    signal clicked()
    signal hovered(bool on)

    width: parent ? parent.width : implicitWidth
    implicitHeight: Style.space(36)
    foreground: root.foreground

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.rowPaddingX
      spacing: Style.space(10)

      Rectangle {
        width: Style.space(16)
        height: Style.space(16)
        radius: Style.space(8)
        color: row.color
        border.width: 1
        border.color: root.dim
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: row.label
        color: row.hasCursor ? root.foreground : Qt.darker(root.foreground, 1.15)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: row.hasCursor
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        visible: row.current
        text: "●"
        color: row.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: row.hovered(true)
      onExited: row.hovered(false)
      onClicked: row.clicked()
    }
  }

  component HexInput: Item {
    id: field

    property string label: ""
    property string value: "#000000"
    readonly property bool editing: input.activeFocus

    signal committed(string hex)

    width: parent ? parent.width : implicitWidth
    implicitHeight: Style.space(32)

    function normalize(t) {
      t = String(t || "").trim().replace(/^#/, "")
      if (t.length === 3) {
        t = t.charAt(0) + t.charAt(0) + t.charAt(1) + t.charAt(1) + t.charAt(2) + t.charAt(2)
      }
      return /^[0-9a-fA-F]{6}$/.test(t) ? "#" + t.toUpperCase() : ""
    }

    function commitCurrent() {
      var n = field.normalize(input.text)
      if (n) field.committed(n)
      else input.text = field.value
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.rowPaddingX
      spacing: Style.space(8)

      Text {
        text: field.label
        color: Qt.darker(root.foreground, 1.2)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
      }

      Rectangle {
        width: Style.space(16)
        height: Style.space(16)
        radius: Style.space(8)
        color: field.value
        border.width: 1
        border.color: root.dim
        Layout.alignment: Qt.AlignVCenter
      }

      TextField {
        id: input
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        foreground: root.foreground
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(4)
        font.pixelSize: Style.font.body
        onAccepted: field.commitCurrent()
        onEditingFinished: field.commitCurrent()
      }
    }

    onValueChanged: if (!field.editing) input.text = field.value
    Component.onCompleted: input.text = field.value
  }
}
