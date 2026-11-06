import QtQuick
import "Api.mjs" as Api
import "Compare.js" as Compare

// Several coins as lines on one scale: percent change since the start of the
// range. A dashed line marks 0%. The crosshair follows the pointer (or the
// finger) and the tooltip lists every coin at that moment.
Item {
  id: root
  property var app
  property var series: []      // [{ id, label, color, points: [[ms, percent]] }]
  property string days: "7"
  property bool loading: false
  property string error: ""

  readonly property var drawn: {
    var out = []
    for (var i = 0; i < series.length; i++)
      if (series[i].points && series[i].points.length > 1) out.push(series[i])
    return out
  }
  readonly property bool ready: drawn.length > 0

  // Time and value extent of everything drawn. 0% is always inside it.
  readonly property var ext: {
    var t0 = Infinity, t1 = -Infinity, lo = 0, hi = 0
    for (var i = 0; i < drawn.length; i++) {
      var p = drawn[i].points
      t0 = Math.min(t0, p[0][0])
      t1 = Math.max(t1, p[p.length - 1][0])
      for (var j = 0; j < p.length; j++) {
        lo = Math.min(lo, p[j][1])
        hi = Math.max(hi, p[j][1])
      }
    }
    return { t0: t0, t1: t1, lo: lo, hi: hi }
  }

  readonly property real plotTop: 14
  readonly property real plotBottom: height - 26
  readonly property real plotRight: width - labelWidth - 6
  readonly property real labelWidth: Math.max(hiLabel.implicitWidth, zeroLabel.implicitWidth, loLabel.implicitWidth)

  // Pixel position of the pointer inside the plot, -1 when it is not there.
  property real hoverX: -1
  readonly property bool hovering: ready && hoverX >= 0
  readonly property real hoverT: ext.t0 + Math.max(0, Math.min(1, hoverX / plotRight)) * (ext.t1 - ext.t0)

  function xAt(t) { return (t - ext.t0) / ((ext.t1 - ext.t0) || 1) * plotRight }
  function yAt(v) {
    var span = (ext.hi - ext.lo) || 1
    return plotTop + (1 - (v - ext.lo) / span) * (plotBottom - plotTop)
  }
  // The point of a series closest in time to the pointer.
  function indexIn(s) { return Compare.nearest(s.points, hoverT) }

  onSeriesChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onPlotRightChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      if (!root.ready) return

      // 0%.
      ctx.strokeStyle = String(root.app.ui.border)
      ctx.lineWidth = 1
      if (ctx.setLineDash) ctx.setLineDash([3, 4])
      ctx.beginPath()
      var zy = Math.round(root.yAt(0)) + 0.5
      ctx.moveTo(0, zy)
      ctx.lineTo(root.plotRight, zy)
      ctx.stroke()
      if (ctx.setLineDash) ctx.setLineDash([])

      ctx.lineWidth = 2
      ctx.lineJoin = "round"
      for (var s = 0; s < root.drawn.length; s++) {
        var p = root.drawn[s].points
        ctx.strokeStyle = String(root.drawn[s].color)
        ctx.beginPath()
        for (var i = 0; i < p.length; i++) {
          var x = root.xAt(p[i][0]), y = root.yAt(p[i][1])
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.stroke()
      }
    }
  }

  // Scale labels: the highest and lowest value reached, and 0%.
  Text {
    id: hiLabel
    x: root.width - width
    y: Math.max(0, root.yAt(root.ext.hi) - height / 2)
    visible: root.ready && root.ext.hi > 0
    text: Api.percent(root.ext.hi)
    color: root.app.ui.muted
    font.family: root.app.ui.font
    font.pixelSize: root.app.ui.fs.xs
  }
  Text {
    id: zeroLabel
    x: root.width - width
    y: Math.max(0, Math.min(root.plotBottom - height, root.yAt(0) - height / 2))
    visible: root.ready
    text: "0%"
    color: root.app.ui.muted
    font.family: root.app.ui.font
    font.pixelSize: root.app.ui.fs.xs
  }
  Text {
    id: loLabel
    x: root.width - width
    y: Math.min(root.plotBottom - height, root.yAt(root.ext.lo) - height / 2)
    visible: root.ready && root.ext.lo < 0
    text: Api.percent(root.ext.lo)
    color: root.app.ui.muted
    font.family: root.app.ui.font
    font.pixelSize: root.app.ui.fs.xs
  }
  Text {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    visible: root.ready
    text: root.ready ? Api.stamp(root.ext.t0, root.days) : ""
    color: root.app.ui.muted
    font.family: root.app.ui.font
    font.pixelSize: root.app.ui.fs.xs
  }
  Text {
    x: root.plotRight - width
    anchors.bottom: parent.bottom
    visible: root.ready
    text: root.ready ? Api.stamp(root.ext.t1, root.days) : ""
    color: root.app.ui.muted
    font.family: root.app.ui.font
    font.pixelSize: root.app.ui.fs.xs
  }

  // Crosshair, a dot on every line, and the tooltip.
  Rectangle {
    visible: root.hovering
    x: Math.round(root.hoverX)
    y: root.plotTop - 6
    width: 1
    height: root.plotBottom - root.plotTop + 6
    color: root.app.ui.muted
  }
  Repeater {
    model: root.hovering ? root.drawn : []
    delegate: Rectangle {
      required property var modelData
      readonly property int at: root.indexIn(modelData)
      width: 10
      height: 10
      radius: 5
      x: root.xAt(modelData.points[at][0]) - 5
      y: root.yAt(modelData.points[at][1]) - 5
      color: modelData.color
      border.width: 2
      border.color: root.app.ui.bg
    }
  }
  Rectangle {
    visible: root.hovering
    radius: 8
    color: root.app.ui.surfaceHigh
    border.width: 1
    border.color: root.app.ui.border
    width: bubbleCol.implicitWidth + 16
    height: bubbleCol.implicitHeight + 10
    y: 0
    // On the side of the chart the pointer is not on, so it never hides it.
    x: root.hoverX > root.plotRight / 2 ? 0 : Math.max(0, root.plotRight - width)
    z: 2
    Column {
      id: bubbleCol
      anchors.centerIn: parent
      spacing: 2
      Text {
        text: root.hovering ? Api.stamp(root.hoverT, root.days) : ""
        color: root.app.ui.muted
        font.family: root.app.ui.font
        font.pixelSize: root.app.ui.fs.xs
      }
      Repeater {
        model: root.hovering ? root.drawn : []
        delegate: Row {
          required property var modelData
          readonly property int at: root.indexIn(modelData)
          spacing: 6
          Rectangle { width: 8; height: 8; radius: 4; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
          Text {
            text: modelData.label
            color: root.app.ui.text
            font.family: root.app.ui.font
            font.pixelSize: root.app.ui.fs.sm
            font.weight: Font.DemiBold
          }
          Change {
            app: root.app
            anchors.verticalCenter: parent.verticalCenter
            value: parent.at >= 0 ? modelData.points[parent.at][1] : NaN
            font.pixelSize: root.app.ui.fs.sm
          }
        }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: !root.ready
    width: parent.width - 24
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    text: root.error ? root.error : root.loading ? "Loading charts…" : "No price history"
    color: root.app.ui.muted
    font.family: root.app.ui.font
    font.pixelSize: root.app.ui.fs.sm
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: false
    onPositionChanged: function (mouse) { if (root.ready && (pressed || containsMouse)) root.hoverX = Math.max(0, Math.min(root.plotRight, mouse.x)) }
    onPressed: function (mouse) { if (root.ready) root.hoverX = Math.max(0, Math.min(root.plotRight, mouse.x)) }
    onReleased: if (!containsMouse) root.hoverX = -1
    onExited: root.hoverX = -1
    onCanceled: root.hoverX = -1
  }
}
