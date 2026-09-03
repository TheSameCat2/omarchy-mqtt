import QtQuick
import qs.Commons

// Theme-colored broadcast glyph: a node with three arcs. Reads at bar
// canvas size (~16px) and at the panel hero size without swapping assets.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onPaint: {
      var ctx = getContext("2d")
      var w = width
      var h = height
      if (w < 1 || h < 1) return
      ctx.reset()
      ctx.fillStyle = root.color
      ctx.strokeStyle = root.color
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.lineWidth = Math.max(1.15, w * 0.1)

      var cx = w * 0.30
      var cy = h * 0.50
      var node = Math.max(1.4, w * 0.13)

      ctx.beginPath()
      ctx.arc(cx, cy, node, 0, Math.PI * 2)
      ctx.fill()

      var start = -Math.PI * 0.42
      var end = Math.PI * 0.42
      var radii = [w * 0.34, w * 0.54, w * 0.74]
      for (var i = 0; i < radii.length; i++) {
        ctx.beginPath()
        ctx.arc(cx, cy, radii[i], start, end, false)
        ctx.stroke()
      }
    }
  }

  onColorChanged: canvas.requestPaint()
  onIconSizeChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  Component.onCompleted: canvas.requestPaint()
}
