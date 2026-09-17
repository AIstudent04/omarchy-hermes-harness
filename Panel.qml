import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.archer-clawbot.hermes-harness"
  ipcTarget: "io.github.archer-clawbot.hermes-harness"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var status: ({ installed: false, version: "", gatewayState: "unknown", activeModel: "", currentSessionId: "", currentSessionTitle: "", nodesOnline: 0, nodesTotal: 0, nodes: {}, cost: null })
  property string lastError: ""
  readonly property var barIdentity: hostWidget || root
  readonly property bool gatewayActive: status.gatewayState === "active"
  readonly property int refreshSeconds: Math.max(10, parseInt(setting("refreshIntervalSec", 15), 10) || 15)
  readonly property string barLabel: status.installed ? (gatewayActive ? "⚕" : "⚕·") : "⚕×"
  readonly property var cost: (status.cost && typeof status.cost === "object") ? status.cost : null
  readonly property string barTooltip: {
    if (!cost || cost.balanceRemaining === null || cost.balanceRemaining === undefined) return "Hermes Harness"
    return "Hermes — " + fmtMoney(cost.balanceRemaining, cost.currency) + " left"
  }

  function fmtMoney(value, currency) {
    var n = Number(value)
    if (!isFinite(n)) return "—"
    var cur = String(currency || "USD")
    var sym = cur === "USD" ? "$" : cur + " "
    return sym + n.toFixed(2)
  }

  function fmtTokens(value) {
    var n = Number(value)
    if (!isFinite(n) || n <= 0) return "0"
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
    if (n >= 1000) return (n / 1000).toFixed(1) + "K"
    return String(Math.round(n))
  }

  function display(value, fallback) {
    var text = String(value === undefined || value === null ? "" : value)
    return text === "" ? fallback : text
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function open() {
    root.controller.show()
    refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) close()
    else open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function acceptStatus(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (!parsed || typeof parsed !== "object") throw new Error("status is not an object")
      status = parsed
      lastError = ""
    } catch (error) {
      lastError = "Status refresh failed"
    }
  }

  Process {
    id: statusProc
    command: ["bash", Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.archer-clawbot.hermes-harness/scripts/hermes-status", setting("hermesVpsUrl", "")]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.acceptStatus(text) }
    onExited: function(exitCode) { if (exitCode !== 0) root.lastError = "Status command exited " + exitCode }
  }

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Row {
          width: parent.width
          spacing: Style.space(14)

          Text {
            text: root.barLabel
            textFormat: Text.PlainText
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }

          Column {
            width: parent.width - parent.children[0].implicitWidth - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.labelGap
            Text {
              text: "Hermes Harness"
              textFormat: Text.PlainText
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              width: parent.width
              text: root.status.installed ? root.display(root.status.version, "Installed") : "NOT INSTALLED"
              textFormat: Text.PlainText
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(8)
          InfoPair { label: "Gateway"; value: root.display(root.status.gatewayState, "unknown") }
          InfoPair { label: "Active model"; value: root.display(root.status.activeModel, "unknown") }
          InfoPair { label: "Session"; value: root.display(root.status.currentSessionTitle, root.display(root.status.currentSessionId, "none")) }
          InfoPair { label: "Federated nodes"; value: root.status.hermesNodeAvailable ? (Number(root.status.nodesOnline || 0) + "/" + Number(root.status.nodesTotal || 0) + " online") : "hermes-node unavailable" }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.cost !== null
          PanelSectionHeader { text: "COST"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
          InfoPair {
            label: "Balance"
            value: root.cost && root.cost.balanceRemaining !== null && root.cost.balanceRemaining !== undefined
              ? root.fmtMoney(root.cost.balanceRemaining, root.cost.currency) + " of " + root.fmtMoney(root.cost.balanceFunded, root.cost.currency) + (root.cost.balanceEstimated ? " (est.)" : "")
              : "unknown"
          }
          InfoPair { label: "Spent"; value: root.cost ? root.fmtMoney(root.cost.balanceSpent, root.cost.currency) : "—" }
          InfoPair { label: "Today"; value: root.cost ? (root.fmtTokens(root.cost.todayTotalTokens) + " tokens · " + Number(root.cost.todaySessions || 0) + " sessions") : "—" }
          Repeater {
            model: root.cost ? (root.cost.models || []) : []
            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(8)
              Text { text: "·"; textFormat: Text.PlainText; color: root.bar.foreground; font.pixelSize: Style.font.body }
              Text { text: String(modelData.model); textFormat: Text.PlainText; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideMiddle; width: Math.min(implicitWidth, parent.width * 0.6) }
              Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - parent.children[3].implicitWidth - parent.spacing * 3); height: 1 }
              Text { text: root.fmtTokens((modelData.inputTokens || 0) + (modelData.outputTokens || 0)) + " tok"; textFormat: Text.PlainText; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          PanelSectionHeader { text: "NODES"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
          Repeater {
            model: Object.keys(root.status.nodes || {}).sort()
            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(8)
              Text { text: root.status.nodes[modelData].online ? "●" : "○"; textFormat: Text.PlainText; color: root.bar.foreground; font.pixelSize: Style.font.body }
              Text { text: String(modelData); textFormat: Text.PlainText; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
              Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - parent.children[3].implicitWidth - parent.spacing * 3); height: 1 }
              Text { text: root.status.nodes[modelData].online ? "online" : "offline"; textFormat: Text.PlainText; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
            }
          }
        }

        Text {
          visible: root.lastError !== ""
          text: root.lastError
          textFormat: Text.PlainText
          color: root.bar.urgent
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Button {
          width: parent.width
          text: "Open Hermes"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          onClicked: {
            if (root.bar) root.bar.run("hermes")
            root.close()
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""
    width: parent.width
    spacing: Style.space(8)
    Text { text: label; textFormat: Text.PlainText; color: Qt.darker(root.bar.foreground, 1.35); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    Text { text: value; textFormat: Text.PlainText; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideLeft; width: Math.min(implicitWidth, parent.width * 0.65) }
  }
}
