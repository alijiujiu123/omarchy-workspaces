import QtQuick
import QtQuick.Layouts
import Quickshell
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

  // Which screen this bar belongs to. The bar surface is created *per screen*
  // (`Variants { model: Quickshell.screens }` in the shell's Bar.qml), so the widget asks its own
  // window which screen it is on — and that is the right answer for a per-screen bar: each bar
  // shows its own screen's numbers, the way a per-screen bar should. The focused monitor is only
  // the fallback for the case where the window or its screen cannot be read (which keeps a single
  // bar correct when the pointer is on the other screen).
  readonly property string barScreenName: {
    // `QsWindow.window` is Quickshell's own attached property for exactly this (the shell's PopupCard
    // and Bar use it the same way); QtQuick's `Window.window` is null here, because the panel is a
    // Quickshell window rather than a plain QQuickWindow — which is what the first attempt at this
    // used, and the fallback quietly hid it.
    var win = root.QsWindow ? root.QsWindow.window : null
    var screen = win && win.screen ? win.screen : null
    return screen && screen.name ? String(screen.name) : ""
  }

  function screenName() {
    if (root.barScreenName !== "") return root.barScreenName
    return Hyprland.focusedMonitor && Hyprland.focusedMonitor.name ? String(Hyprland.focusedMonitor.name) : ""
  }

  // This screen's workspaces that occupy an ordinal (I1-I4), in ordinal order.
  function occupiedWorkspaces() {
    var screen = root.screenName()
    var values = Hyprland.workspaces.values
    var out = []

    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (!ws || ws.id <= 0) continue
      // I4: compare by screen *name*, because the two types involved are different ones (the bar's
      // screen is a Quickshell ShellScreen, a workspace's monitor is a HyprlandMonitor); the name is
      // the one thing they agree on, and when the screen is unknown nothing is filtered.
      if (screen !== "" && ws.monitor && String(ws.monitor.name) !== screen) continue

      // A slot is a workspace with windows, or the one you are on. A blank one is not kept: Hyprland
      // closes it the moment its screen moves past it (the user's rule, 2026-09-22), so adding a
      // workspace is a button — the trailing "+" below — not a reserved slot.
      var hasWindows = ws.toplevels && ws.toplevels.values.length > 0
      var current = Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === ws.id
      if (!hasWindows && !current) continue

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
    // The trailing "+": a new blank workspace on this screen, and you go there. It is the only add
    // affordance in the bar, and the overview has the same one under its cards — both call the same
    // resolver function, so there is one definition of what "new" means.
    shown.push({ add: true })
    return shown
  }

  // `1..9`, then `0` for the tenth: the digits are laid out that way on a keyboard, and it keeps
  // this widget in step with the overview's labels and `SUPER + 0`.
  function labelFor(slot, index) {
    if (slot && slot.add !== undefined) return "+"
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

    // The "+": a new blank workspace on this screen, and you go there. The bar's dispatch channel only
    // accepts a *dispatcher value* (it wraps the argument in `hl.dispatch(...)`), so the id is computed
    // here, exactly the way `workspaces.next_id` does it in the resolver: the smallest free id above
    // this screen's highest, which keeps the new workspace last in the ordinal order. Then the same two
    // steps the resolver takes — focus the id (that is how Hyprland creates a workspace) and move it to
    // this bar's screen, because an id can already be pinned elsewhere by a hyprmoncfg rule.
    if (slot.add !== undefined) {
      var ids = root.occupiedWorkspaces().map(function(w) { return w.id })
      var next = 1
      for (var i = 0; i < ids.length; i++) if (ids[i] >= next) next = ids[i] + 1
      var target = String(next)
      root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + target + "\" })"))
      root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.workspace.move({ workspace = \"" + target + "\", monitor = \"" + root.screenName() + "\" })"))
      return
    }

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
        readonly property bool addSlot: modelData && modelData.add !== undefined
        readonly property bool occupied: root.isOccupied(modelData)
        readonly property bool focused: root.isFocused(modelData)

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : root.labelFor(modelData, index)
        opacity: (overflow || addSlot) ? 0.75 : (occupied || focused ? 1 : 0.5)
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.activate(modelData) }
      }
    }
  }
}
