import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "thesamecat.mqtt"
  ipcTarget: "thesamecat.mqtt"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  property bool cursorActive: false
  property string focusSection: "host"
  property int filterIndex: 0
  property int messageIndex: 0
  property bool filtersOpen: false
  property bool editingHost: false
  property bool editingTopic: false

  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool listening: mqtt.listening
  readonly property bool installed: mqtt.installed
  readonly property string hostMode: mqtt.hostMode
  readonly property bool customBroker: hostMode === "custom"
  readonly property var topicList: mqtt.topicList
  readonly property var messages: mqtt.messages
  readonly property bool editorOpen: editingHost || editingTopic
    || (hostField && hostField.activeFocus)
    || (topicField && topicField.activeFocus)
    || (portField && portField.field && portField.field.activeFocus)
  readonly property string heroMeta: {
    if (!mqtt.installed) return "mosquitto_sub is missing"
    if (mqtt.lastError !== "" && !mqtt.listening) return mqtt.lastError
    if (!mqtt.hostReady) return "Enter a broker address"
    if (mqtt.listening) {
      if (mqtt.topicList.length > 0)
        return "Listening · " + mqtt.topicList.length + (mqtt.topicList.length === 1 ? " filter" : " filters")
      return "Listening · " + mqtt.brokerLabel
    }
    if (mqtt.connecting) return "Connecting · " + mqtt.brokerLabel
    return "Disconnected · " + mqtt.brokerLabel
  }

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    cancelEditors()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function reconnect() {
    mqtt.reconnect()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setHostMode(mode) {
    var next = Model.normalizeHostMode(mode)
    persistSettings({ hostMode: next })
    if (next === "custom") {
      Qt.callLater(function() {
        if (hostField) {
          root.editingHost = true
          hostField.forceActiveFocus()
          hostField.selectAll()
        }
      })
    } else {
      cancelEditors()
    }
  }

  function commitHost() {
    persistSettings({ host: Model.normalizeHost(hostField.text) })
    root.editingHost = false
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function commitPort(value) {
    persistSettings({ port: Model.normalizePort(value, mqtt.customPort) })
  }

  function addTopic(value) {
    var topic = Model.normalizeTopic(value)
    if (topic === "") return
    var next = mqtt.topicList.slice()
    if (next.indexOf(topic) !== -1) {
      topicField.text = ""
      return
    }
    if (next.length >= Model.MAX_TOPICS) return
    next.push(topic)
    persistSettings({ topics: next })
    topicField.text = ""
    root.filtersOpen = true
    root.editingTopic = false
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function removeTopic(index) {
    var next = mqtt.topicList.slice()
    if (index < 0 || index >= next.length) return
    next.splice(index, 1)
    persistSettings({ topics: next })
    if (filterIndex >= next.length) filterIndex = Math.max(0, next.length - 1)
  }

  function cancelEditors() {
    root.editingHost = false
    root.editingTopic = false
    if (hostField) hostField.text = mqtt.customHost
    if (topicField) topicField.text = ""
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function formatMessageTime(message) {
    var date = Model.parseTimestamp(message && message.tst)
    if (!date) return "--:--:--"
    return Qt.formatTime(date, "HH:mm:ss")
  }

  function ensureCursor() {
    if (focusSection === "customHost" && !customBroker) focusSection = "host"
    if (focusSection === "customPort" && !customBroker) focusSection = "host"
    if (focusSection === "filterItem" && (!filtersOpen || topicList.length === 0))
      focusSection = "filters"
    if (focusSection === "filterAdd" && !filtersOpen) focusSection = "filters"
    if (focusSection === "messages" && messages.length === 0) focusSection = filtersOpen ? "filters" : "host"
    if (filterIndex >= topicList.length) filterIndex = Math.max(0, topicList.length - 1)
    if (messageIndex >= messages.length) messageIndex = Math.max(0, messages.length - 1)
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    ensureCursor()
    if (dx !== 0 && focusSection === "host") {
      setHostMode(dx > 0 ? "custom" : "localhost")
      return
    }
    if (dy === 0) return
    if (focusSection === "host") {
      if (dy > 0) focusSection = customBroker ? "customHost" : "filters"
    } else if (focusSection === "customHost") {
      focusSection = dy > 0 ? "customPort" : "host"
    } else if (focusSection === "customPort") {
      focusSection = dy > 0 ? "filters" : "customHost"
    } else if (focusSection === "filters") {
      if (dy < 0) focusSection = customBroker ? "customPort" : "host"
      else if (filtersOpen && topicList.length > 0) { focusSection = "filterItem"; filterIndex = 0 }
      else if (filtersOpen) focusSection = "filterAdd"
      else if (messages.length > 0) { focusSection = "messages"; messageIndex = 0 }
    } else if (focusSection === "filterItem") {
      if (dy < 0) {
        if (filterIndex <= 0) focusSection = "filters"
        else filterIndex--
      } else if (filterIndex < topicList.length - 1) {
        filterIndex++
      } else {
        focusSection = "filterAdd"
      }
    } else if (focusSection === "filterAdd") {
      if (dy < 0) {
        if (topicList.length > 0) { focusSection = "filterItem"; filterIndex = topicList.length - 1 }
        else focusSection = "filters"
      } else if (messages.length > 0) {
        focusSection = "messages"
        messageIndex = 0
      }
    } else if (focusSection === "messages") {
      if (dy < 0) {
        if (messageIndex <= 0) focusSection = filtersOpen ? "filterAdd" : "filters"
        else messageIndex--
      } else if (messageIndex < messages.length - 1) {
        messageIndex++
      }
    }
    ensureCursor()
    scrollCursorIntoView()
  }

  function activateCursor() {
    ensureCursor()
    if (focusSection === "host") {
      setHostMode(hostMode === "custom" ? "localhost" : "custom")
    } else if (focusSection === "customHost") {
      root.editingHost = true
      if (hostField) { hostField.forceActiveFocus(); hostField.selectAll() }
    } else if (focusSection === "customPort") {
      if (portField && portField.field) portField.field.forceActiveFocus()
    } else if (focusSection === "filters") {
      filtersOpen = !filtersOpen
    } else if (focusSection === "filterItem") {
      removeTopic(filterIndex)
    } else if (focusSection === "filterAdd") {
      root.editingTopic = true
      if (topicField) topicField.forceActiveFocus()
    } else if (focusSection === "messages") {
      if (messages.length > 0) mqtt.copyPayload(messages[messageIndex])
    }
  }

  function scrollItemIntoView(item) {
    if (!panelFlick || !item) return
    Qt.callLater(function() {
      if (!item) return
      var margin = Style.space(6)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin) panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  function scrollCursorIntoView() {
    if (focusSection === "messages" && messageColumn && messageIndex >= 0 && messageIndex < messageColumn.children.length)
      scrollItemIntoView(messageColumn.children[messageIndex])
    else if (focusSection === "filterItem" && filterColumn && filterIndex >= 0 && filterIndex < filterColumn.children.length)
      scrollItemIntoView(filterColumn.children[filterIndex])
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    if (panelFlick) panelFlick.contentY = 0
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  Service {
    id: mqtt
    settings: root.settings
  }

  Binding {
    target: hostField
    property: "text"
    value: mqtt.customHost
    when: hostField && !hostField.activeFocus
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editorOpen
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onDeleteRequested: {
        if (root.focusSection === "filterItem") root.removeTopic(root.filterIndex)
      }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.reconnect()
        else if (t === "c" || t === "C") {
          if (root.messages.length > 0) mqtt.copyPayload(root.messages[Math.max(0, root.messageIndex)])
        }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "MQTT"
            meta: root.heroMeta
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: mqtt.listening ? 1.0 : 0.5
            iconComponent: Component {
              MqttIcon {
                iconSize: Style.font.display
                color: mqtt.listening ? root.foreground : root.dim
              }
            }
          }

          Text {
            visible: mqtt.lastError !== "" && mqtt.listening
            width: parent.width
            text: mqtt.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          CursorSurface {
            visible: !mqtt.installed
            width: parent.width
            implicitHeight: missingText.implicitHeight + Style.spacing.rowPaddingX
            foreground: root.foreground

            Text {
              id: missingText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(12)
              text: "mosquitto_sub is not installed or not on PATH."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "BROKER"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ButtonGroup {
              id: hostGroup
              width: parent.width
              options: [
                { value: "localhost", label: "Localhost" },
                { value: "custom", label: "Custom" }
              ]
              value: root.hostMode
              foreground: root.foreground
              fontFamily: root.fontFamily
              cursorIndex: root.cursorActive && root.focusSection === "host" ? (root.hostMode === "custom" ? 1 : 0) : -1
              onChanged: function(v) { root.setHostMode(v) }
              onHovered: function(index, on) {
                if (on) {
                  root.cursorActive = true
                  root.focusSection = "host"
                }
              }
            }

            Column {
              visible: root.customBroker
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "Address"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                textFormat: Text.PlainText
              }

              TextField {
                id: hostField
                width: parent.width
                placeholderText: "127.0.0.1"
                foreground: root.foreground
                hasCursor: root.cursorActive && root.focusSection === "customHost" && !activeFocus
                onEditingFinished: root.commitHost()
                onActiveFocusChanged: if (activeFocus) {
                  root.cursorActive = true
                  root.focusSection = "customHost"
                  root.editingHost = true
                }
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Escape) {
                    root.cancelEditors()
                    event.accepted = true
                  }
                }
              }

              NumberField {
                id: portField
                width: parent.width
                label: "Port"
                value: mqtt.customPort
                from: 1
                to: 65535
                stepSize: 1
                foreground: root.foreground
                fontFamily: root.fontFamily
                hasCursor: root.cursorActive && root.focusSection === "customPort"
                onModified: function(v) { root.commitPort(v) }
                onHovered: function(on) {
                  if (on) {
                    root.cursorActive = true
                    root.focusSection = "customPort"
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(10)

            CursorSurface {
              id: filterHeader
              width: parent.width
              implicitHeight: filterHeaderRow.implicitHeight + Style.space(8)
              foreground: root.foreground
              hasCursor: root.cursorActive && root.focusSection === "filters"
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: { root.cursorActive = true; root.focusSection = "filters" }
                onClicked: root.filtersOpen = !root.filtersOpen
              }
              Row {
                id: filterHeaderRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)

                PanelSectionHeader {
                  text: "FILTER TOPICS"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  width: Math.min(implicitWidth, parent.width - countPill.width - chevron.implicitWidth - Style.space(16))
                }

                Item { width: Math.max(0, parent.width - filterHeaderRow.children[0].width - countPill.width - chevron.implicitWidth - Style.space(16)); height: 1 }

                BorderSurface {
                  id: countPill
                  visible: root.topicList.length > 0
                  implicitWidth: countText.implicitWidth + Style.space(10)
                  implicitHeight: countText.implicitHeight + Style.space(4)
                  color: "transparent"
                  borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                  radius: Style.cornerRadius
                  Text {
                    id: countText
                    anchors.centerIn: parent
                    text: String(root.topicList.length)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    textFormat: Text.PlainText
                  }
                }

                Text {
                  id: chevron
                  text: root.filtersOpen ? "▾" : "▸"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                }
              }
            }

            Column {
              visible: root.filtersOpen
              width: parent.width
              spacing: Style.space(6)

              Text {
                visible: root.topicList.length === 0
                width: parent.width
                text: "No filters — subscribed to all traffic (#)."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
              }

              Column {
                id: filterColumn
                width: parent.width
                spacing: Style.space(4)

                Repeater {
                  model: root.topicList
                  TopicRow {
                    required property string modelData
                    required property int index
                    width: parent.width
                    topic: modelData
                    rowIndex: index
                  }
                }
              }

              TextField {
                id: topicField
                width: parent.width
                placeholderText: "sensor/#"
                foreground: root.foreground
                hasCursor: root.cursorActive && root.focusSection === "filterAdd" && !activeFocus
                onAccepted: root.addTopic(text)
                onActiveFocusChanged: if (activeFocus) {
                  root.cursorActive = true
                  root.focusSection = "filterAdd"
                  root.editingTopic = true
                }
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Escape) {
                    root.cancelEditors()
                    event.accepted = true
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "MESSAGES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.messages.length === 0
              width: parent.width
              text: mqtt.listening ? "Waiting for messages." : "Connect to a broker to start catching traffic."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
            }

            Column {
              id: messageColumn
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.messages
                MessageRow {
                  required property var modelData
                  required property int index
                  width: parent.width
                  message: modelData
                  rowIndex: index
                }
              }
            }
          }
        }
      }
    }
  }

  component TopicRow: CursorSurface {
    id: topicRow
    property string topic: ""
    property int rowIndex: 0
    foreground: root.foreground
    hasCursor: root.cursorActive && root.focusSection === "filterItem" && root.filterIndex === rowIndex
    implicitHeight: Math.max(Style.spacing.controlHeight, topicLabel.implicitHeight + Style.space(10))

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: {
        root.cursorActive = true
        root.focusSection = "filterItem"
        root.filterIndex = topicRow.rowIndex
      }
    }

    Text {
      id: topicLabel
      anchors.left: parent.left
      anchors.right: removeBtn.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      text: topicRow.topic
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }

    Button {
      id: removeBtn
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      text: "×"
      tooltipText: "Remove filter"
      foreground: root.foreground
      fontFamily: root.fontFamily
      horizontalPadding: Style.space(8)
      verticalPadding: Style.space(2)
      onClicked: root.removeTopic(topicRow.rowIndex)
    }
  }

  component MessageRow: CursorSurface {
    id: messageRow
    property var message: ({})
    property int rowIndex: 0
    foreground: root.foreground
    hasCursor: root.cursorActive && root.focusSection === "messages" && root.messageIndex === rowIndex
    implicitHeight: messageColumnInner.implicitHeight + Style.space(12)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.focusSection = "messages"
        root.messageIndex = messageRow.rowIndex
      }
      onClicked: mqtt.copyPayload(messageRow.message)
    }

    Column {
      id: messageColumnInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(2)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: root.formatMessageTime(messageRow.message)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }

        Text {
          width: Math.max(20, parent.width - parent.children[0].implicitWidth - Style.space(8))
          text: messageRow.message && messageRow.message.topic ? messageRow.message.topic : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideMiddle
          textFormat: Text.PlainText
        }
      }

      Text {
        width: parent.width
        text: Model.truncate(messageRow.message && messageRow.message.payload ? messageRow.message.payload : "", Model.PAYLOAD_PREVIEW)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 2
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }
    }
  }
}
