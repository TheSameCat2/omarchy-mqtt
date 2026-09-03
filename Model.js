.pragma library

var MAX_MESSAGES = 10
var MAX_TOPICS = 16
var PAYLOAD_PREVIEW = 160

function settingValue(settings, name, fallback) {
  if (!settings) return fallback
  var value = settings[name]
  return value === undefined || value === null ? fallback : value
}

function normalizeHostMode(value) {
  return String(value || "") === "custom" ? "custom" : "localhost"
}

function normalizeHost(value) {
  return String(value || "").replace(/^\s+|\s+$/g, "")
}

function normalizePort(value, fallback) {
  var n = parseInt(String(value === undefined || value === null ? fallback : value), 10)
  if (!isFinite(n)) n = fallback
  if (n < 1) n = 1
  if (n > 65535) n = 65535
  return n
}

function normalizeTopic(value) {
  var topic = String(value || "").replace(/^\s+|\s+$/g, "")
  if (topic.length === 0) return ""
  if (topic.indexOf("\0") !== -1) return ""
  return topic
}

function normalizeTopics(raw) {
  var out = []
  var seen = {}
  if (!Array.isArray(raw)) return out
  for (var i = 0; i < raw.length && out.length < MAX_TOPICS; i++) {
    var topic = normalizeTopic(raw[i])
    if (topic === "" || seen[topic]) continue
    seen[topic] = true
    out.push(topic)
  }
  return out
}

function subscribeTopics(topics) {
  return topics && topics.length > 0 ? topics : ["#"]
}

function hostLabel(hostMode, host, port) {
  if (normalizeHostMode(hostMode) !== "custom") return "localhost:1883"
  var address = normalizeHost(host)
  if (address === "") return "custom broker"
  return address + ":" + normalizePort(port, 1883)
}

function payloadToString(payload) {
  if (payload === null || payload === undefined) return ""
  if (typeof payload === "string") return payload
  if (typeof payload === "number" || typeof payload === "boolean") return String(payload)
  try {
    return JSON.stringify(payload)
  } catch (e) {
    return String(payload)
  }
}

function parseMessageLine(line) {
  var raw = String(line || "").replace(/^\s+|\s+$/g, "")
  if (raw.length === 0) return null
  try {
    var obj = JSON.parse(raw)
    if (!obj || typeof obj !== "object") return null
    return {
      tst: String(obj.tst || ""),
      topic: String(obj.topic || ""),
      qos: Number(obj.qos) || 0,
      retain: Number(obj.retain) === 1 || obj.retain === true,
      payload: payloadToString(obj.payload)
    }
  } catch (e) {
    return null
  }
}

function pushMessage(list, message, limit) {
  var cap = limit > 0 ? limit : MAX_MESSAGES
  var next = [message]
  if (!Array.isArray(list)) return next
  for (var i = 0; i < list.length && next.length < cap; i++) next.push(list[i])
  return next
}

function parseTimestamp(tst) {
  var s = String(tst || "")
  if (s.length === 0) return null
  var match = s.match(/^(.+?)([+-]\d{2})(\d{2})$/)
  if (match) s = match[1] + match[2] + ":" + match[3]
  var date = new Date(s)
  if (isNaN(date.getTime())) return null
  return date
}

function truncate(value, limit) {
  var text = String(value || "")
  var cap = limit > 0 ? limit : PAYLOAD_PREVIEW
  if (text.length <= cap) return text
  return text.substring(0, cap - 1) + "…"
}

function stderrLooksFatal(line) {
  var text = String(line || "").toLowerCase()
  if (text.length === 0) return false
  return text.indexOf("error") !== -1 || text.indexOf("connection refused") !== -1
    || text.indexOf("timed out") !== -1 || text.indexOf("failed") !== -1
}
