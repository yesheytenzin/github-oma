import QtQuick
import qs.Commons
import qs.Ui

// 󰊤 in the bar: the GitHub mark, how many items the current scope holds, and
// the urgent color when something is assigned to you or waiting on your
// review. Click opens the panel, middle-click refreshes.
//
// This widget never fetches anything itself. Service.qml owns the poller (one
// per shell, not one per monitor) and this widget reaches it the only way a
// third-party plugin may: through the bar's scoped shell facade.
BarWidget {
  id: root
  moduleName: "tenzin.github-oma"

  readonly property var service: root.bar && root.bar.shell
    ? root.bar.shell.serviceFor(root.moduleName) : null

  readonly property int badge: root.service ? root.service.badgeCount : 0
  readonly property bool attention: root.service ? root.service.attentionCount > 0 : false

  // nf-md-github, verified in the configured Nerd Font. A bar widget with
  // empty text paints nothing at all, so the glyph is always present.
  readonly property string glyph: "󰊤"
  readonly property string count: root.badge <= 0
    ? ""
    : (root.badge > 99 ? "99+" : String(root.badge))

  readonly property bool vertical: root.bar ? root.bar.vertical === true : false

  // The mark goes through `text` and the count through `labelText`. Both in
  // `text` would hand one string to the optical fit, which squeezes it to
  // Style.bar.iconSize: "󰊤 12" scaled down to its width came out at half the
  // height of every icon beside it. The label is the shell's own path — it
  // paints at Style.bar.iconFont and keeps its size. A vertical bar has no
  // room beside the icon, so there the count stays in the glyph string.
  readonly property bool countBeside: !root.vertical && root.count !== ""
  // The string `text` paints: the mark alone when the count rides beside it,
  // the mark and count together when it cannot.
  readonly property string label: root.count === "" || root.countBeside
    ? root.glyph
    : root.glyph + " " + root.count

  // The shell lays its label out at Style.bar.iconFont with Style.space(4)
  // between it and the icon box, and sizes the slot from `slotSize`; the
  // widget measures its own label to size that slot.
  TextMetrics {
    id: countMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.bar.iconFont
    text: root.count
  }

  readonly property string tooltip: {
    if (!root.service) return "GitHub"
    if (root.service.errorKind !== "") return "GitHub · " + root.service.errorKind + " — open the panel for the fix"
    var scope = root.service.scope
    var counts = scope === "orgs" ? root.service.counts.orgs : root.service.counts.mine
    var label = scope === "orgs" ? "orgs" : "personal"
    return "GitHub · " + label + " · " + counts.issues + " open issues · " + counts.prs + " open pull requests"
  }

  // The shell routes `omarchy-shell shell summon|hide|toggle tenzin.github-oma`
  // through this root's open/close/opened shape (Bar.findPanelWidget), so the
  // three have to exist here and reach the loaded panel.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function refresh() {
    if (root.service) root.service.refresh()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    labelText: root.countBeside ? root.count : ""
    // One icon slot plus the label the shell draws beside it, so the count is
    // never clipped and the widget keeps the bar's own margins around its
    // paint. `fixedWidth: -1` let the shell size the slot from `text` alone,
    // which knew nothing about the label.
    slotSize: root.countBeside
      ? Style.bar.iconSlot + Style.space(4) + Math.ceil(countMetrics.advanceWidth)
      : Style.bar.iconSlot
    active: root.attention
    tooltipText: root.tooltip
    onPressed: function(pressedButton) {
      if (pressedButton === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
