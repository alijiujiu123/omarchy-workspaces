import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Workspace numbers for the screen you are on — the bar's half of the (screen, ordinal) address
// model that omarchy-setup-kit's `workspaces` module defines (docs/MANUAL-STEPS.md there,
// "Workspace addresses"). The built-in widget this was cloned from shipped two hardcoded
// assumptions: a fixed row of five numbers and `id <= 10`, which together meant the same ten
// numbers appeared on every screen, workspaces past ten were invisible, and clicking "3" went to
// whichever screen happened to own id 3. Everything here is derived from live state instead:
//
//   I1  a workspace's screen comes from live state (`workspace.monitor`), never from an id range;
//   I2  its ordinal is its rank among *that screen's* workspaces sorted by id, so the association
//       follows reality (close a workspace and the ones behind it move up);
//   I3  a workspace occupies an ordinal when it has windows, is persistent, or is the current one —
//       an empty workspace you are standing on must still have a number;
//   I4  nothing crosses screens: the filter is the focused monitor, which is what `SUPER + digit`,
//       the wheel, the overview and this widget all mean by "the n-th workspace";
//   I5  no count is hardcoded: the slots *are* the workspaces that exist. Past the tenth — the
//       digits only reach `1..9,0` — the trailing chip counts the rest and opens the overview,
//       which is the only affordance that can reach them all.
//
// The nth-workspace resolution happens here, in QML, because the bar already has the live workspace
// list; the click then focuses the id it resolved, through the same Lua dispatch path the built-in
// widget used.
BarWidget {
  id: root
  moduleName: "alijiujiu.workspaces"

  // This screen's workspaces that occupy an ordinal (I1-I4), in ordinal order.
  function occupiedWorkspaces() {
    var monitor = Hyprland.focusedMonitor
    var values = Hyprland.workspaces.values
    var out = []

    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (!ws || ws.id <= 0) continue
      // I4: monitors are singletons in Quickshell, so identity is the comparison — the same object
      // the focused monitor is, or nothing.
      if (monitor && ws.monitor && ws.monitor !== monitor) continue

      var hasWindows = ws.toplevels && ws.toplevels.values.length > 0
      // `ispersistent` comes straight off the compositor's own workspace object; if a future
      // Quickshell stops exposing it the widget degrades to "occupied or current", never breaks.
      var persistent = ws.lastIpcObject && ws.lastIpcObject.ispersistent === true
      var current = Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === ws.id
      if (!hasWindows && !persistent && !current) continue

      out.push(ws)
    }

    out.sort(function(left, right) { return left.id - right.id })
    return out
  }

  // What the bar draws: the first ten ordinals, then one chip for the rest (I5). The chip carries
  // the overflow count rather than an id, which is how it is told apart below.
  function slots() {
    var list = root.occupiedWorkspaces()
    var shown = list.slice(0, 10)
    if (list.length > 10) shown.push({ overflow: list.length - 10 })
    return shown
  }

  // `1..9`, then `0` for the tenth: the digits are laid out that way on a keyboard, and it keeps
  // this widget in step with the overview's labels and `SUPER + 0`.
  function labelFor(slot, index) {
    if (slot && slot.overflow !== undefined) return "+" + slot.overflow
    if (index === 9) return "0"
    return String(index + 1)
  }

  function isOccupied(slot) {
    return !!(slot && slot.toplevels && slot.toplevels.values.length > 0)
  }

  function isFocused(slot) {
    return !!(slot && Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === slot.id)
  }

  function activate(slot) {
    if (!root.bar || !slot) return

    // The overflow chip cannot focus a workspace it does not name: the overview is the surface that
    // shows them all (including the trailing add card), so that is where it goes.
    if (slot.overflow !== undefined) {
      root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.plugin.hyprexpo.expo(\"toggle\")"))
      return
    }

    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + slot.id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.slots().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.slots()

      WidgetButton {
        required property var modelData
        required property int index

        readonly property bool overflow: modelData && modelData.overflow !== undefined
        readonly property bool occupied: root.isOccupied(modelData)
        readonly property bool focused: root.isFocused(modelData)

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : root.labelFor(modelData, index)
        opacity: overflow ? 0.7 : (occupied || focused ? 1 : 0.5)
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.activate(modelData) }
      }
    }
  }
}
