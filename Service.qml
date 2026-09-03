import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property bool installed: false
  property bool listening: false
  property bool connecting: false
  property string lastError: ""
  property var messages: []

  readonly property string hostMode: Model.normalizeHostMode(setting("hostMode", "localhost"))
  readonly property string customHost: Model.normalizeHost(setting("host", ""))
  readonly property int customPort: Model.normalizePort(setting("port", 1883), 1883)
  readonly property string host: hostMode === "custom" ? customHost : "127.0.0.1"
  readonly property int port: hostMode === "custom" ? customPort : 1883
  readonly property var topicList: Model.normalizeTopics(setting("topics", []))
  readonly property var subscribeTopics: Model.subscribeTopics(topicList)
  readonly property bool hostReady: host.length > 0
  readonly property string brokerLabel: Model.hostLabel(hostMode, customHost, customPort)
  readonly property string subscribeKey: host + ":" + port + "\n" + subscribeTopics.join("\n")
  readonly property int messageLimit: Model.MAX_MESSAGES

  property string _activeKey: ""
  property bool _reconnectQueued: false

  function setting(name, fallback) {
    return Model.settingValue(settings, name, fallback)
  }

  function buildCommand() {
    var cmd = ["mosquitto_sub", "-h", host, "-p", String(port), "-q", "0", "-F", "%j"]
    for (var i = 0; i < subscribeTopics.length; i++) {
      cmd.push("-t")
      cmd.push(subscribeTopics[i])
    }
    return cmd
  }

  function stopSub() {
    reconnectTimer.stop()
    if (subProcess.running) subProcess.running = false
    listening = false
    connecting = false
  }

  function startSub() {
    if (!installed || !hostReady) return
    if (subProcess.running) return
    lastError = ""
    connecting = true
    listening = false
    _activeKey = subscribeKey
    subProcess.command = buildCommand()
    subProcess.running = true
  }

  function reconnect() {
    _reconnectQueued = false
    if (!installed) {
      stopSub()
      lastError = "mosquitto_sub is not installed or not on PATH."
      return
    }
    if (!hostReady) {
      stopSub()
      lastError = "Enter a broker address."
      return
    }
    if (subProcess.running && _activeKey === subscribeKey) return
    stopSub()
    Qt.callLater(startSub)
  }

  function queueReconnect() {
    if (_reconnectQueued) return
    _reconnectQueued = true
    Qt.callLater(reconnect)
  }

  function handleMessageLine(line) {
    var parsed = Model.parseMessageLine(line)
    if (!parsed) return
    connecting = false
    listening = true
    lastError = ""
    messages = Model.pushMessage(messages, parsed, messageLimit)
  }

  function handleStderr(line) {
    var text = String(line || "").replace(/^\s+|\s+$/g, "")
    if (text.length === 0) return
    if (Model.stderrLooksFatal(text)) lastError = text
  }

  function copyPayload(message) {
    if (!message) return
    var text = String(message.payload || "")
    if (text.length === 0) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
  }

  onInstalledChanged: queueReconnect()
  onHostReadyChanged: queueReconnect()
  onSubscribeKeyChanged: queueReconnect()

  Component.onCompleted: whichProc.running = true

  Process {
    id: whichProc
    command: ["bash", "-lc", "command -v mosquitto_sub"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.installed = String(text || "").replace(/^\s+|\s+$/g, "").length > 0
    }
    onExited: function(code) {
      if (code !== 0) root.installed = false
    }
  }

  Process {
    id: subProcess
    stdout: SplitParser {
      onRead: function(line) { root.handleMessageLine(line) }
    }
    stderr: SplitParser {
      onRead: function(line) { root.handleStderr(line) }
    }
    onRunningChanged: {
      if (running) {
        root.connecting = true
        root.listening = true
      }
    }
    onExited: function(code) {
      root.listening = false
      root.connecting = false
      if (!root.installed || !root.hostReady) return
      if (code !== 0 && root.lastError === "")
        root.lastError = "Broker unavailable (" + code + ")"
      reconnectTimer.restart()
    }
  }

  Timer {
    id: reconnectTimer
    interval: 2000
    repeat: false
    onTriggered: root.startSub()
  }
}
