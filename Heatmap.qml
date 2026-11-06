import QtQuick
import "Api.mjs" as Api
import "Treemap.js" as Treemap

// The biggest coins as one picture: each coin a tile whose area follows its
// market cap and whose colour follows its 24h change. Press a tile to open
// the coin.
//
// Area is market cap to the power 0.6, not market cap itself: at full scale
// Bitcoin alone takes half the picture and everything past the first ten is a
// dot nobody can read or press. The footer under the map says so.
Item {
  id: root
  property var app
  property var rows: []          // markets rows, largest market cap first
  property bool loading: false
  property string error: ""
  readonly property int shownCount: 60
  // A 24h move of this size or more is the strongest colour.
  readonly property real fullAt: 8

  readonly property var coins: {
    var out = []
    for (var i = 0; i < rows.length && out.length < shownCount; i++)
      if (rows[i].mcap > 0) out.push(rows[i])
    return out
  }

  readonly property var tiles: {
    var weights = []
    for (var i = 0; i < coins.length; i++) weights.push(Math.pow(coins[i].mcap, 0.6))
    return Treemap.layout(weights, map.width, map.height)
  }

  function tint(ch) {
    if (isNaN(ch) || Math.abs(ch) < 0.05) return app.ui.surfaceHigh
    var k = Math.min(1, Math.abs(ch) / fullAt)
    return Qt.tint(app.ui.surface, app.alpha(ch > 0 ? app.ui.up : app.ui.down, 0.22 + 0.55 * k))
  }

  // Whichever of the theme's text and background reads better on the tile.
  function ink(fill) {
    return app.contrast(fill, app.ui.text) >= app.contrast(fill, app.ui.bg) ? app.ui.text : app.ui.bg
  }

  Item {
    id: map
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: note.top
    anchors.bottomMargin: 8
    visible: root.coins.length > 0

    Repeater {
      model: root.tiles
      delegate: Rectangle {
        id: tile
        required property var modelData
        required property int index
        readonly property var coin: root.coins[index]
        readonly property real ch: coin ? coin.ch24 : NaN
        readonly property color fill: root.tint(ch)

        x: modelData.x + 1
        y: modelData.y + 1
        width: Math.max(0, modelData.w - 2)
        height: Math.max(0, modelData.h - 2)
        radius: 4
        color: fill
        border.width: tileMouse.containsMouse ? 2 : 0
        border.color: root.app.ui.text
        clip: true
        Accessible.role: Accessible.Button
        Accessible.name: coin ? coin.name + " " + Api.percent(ch) : ""

        Column {
          anchors.centerIn: parent
          width: tile.width - 6
          visible: tile.width >= 40 && tile.height >= 26
          spacing: 0
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.coin ? tile.coin.symbol : ""
            color: root.ink(tile.fill)
            font.family: root.app.ui.font
            font.pixelSize: tile.width >= 110 && tile.height >= 70 ? root.app.ui.fs.lg : root.app.ui.fs.sm
            font.weight: Font.Bold
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            visible: tile.height >= 44
            horizontalAlignment: Text.AlignHCenter
            text: Api.percent(tile.ch)
            color: root.ink(tile.fill)
            opacity: 0.85
            font.family: root.app.ui.font
            font.pixelSize: root.app.ui.fs.xs
            font.features: ({ "tnum": 1 })
            elide: Text.ElideRight
          }
        }

        MouseArea {
          id: tileMouse
          anchors.fill: parent
          hoverEnabled: !root.app.compact
          cursorShape: Qt.PointingHandCursor
          onClicked: if (tile.coin) root.app.openCoin(tile.coin)
        }
      }
    }
  }

  Placeholder {
    anchors.top: parent.top
    width: parent.width
    visible: root.coins.length === 0
    app: root.app
    glyph: root.error ? "󰗖" : ""
    title: root.error ? root.error : root.loading ? "Loading the market…" : "No market data yet"
    action: root.error ? "Try again" : ""
    onTriggered: root.app.refresh(true)
  }

  Row {
    id: note
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    visible: root.coins.length > 0
    spacing: 8
    // The scale: the two ends of the colour ramp.
    Rectangle { width: 10; height: 10; radius: 2; color: root.tint(-root.fullAt); anchors.verticalCenter: parent.verticalCenter }
    Text {
      text: "−" + root.fullAt + "% to +" + root.fullAt + "% in 24h"
      color: root.app.ui.muted
      font.family: root.app.ui.font
      font.pixelSize: root.app.ui.fs.xs
    }
    Rectangle { width: 10; height: 10; radius: 2; color: root.tint(root.fullAt); anchors.verticalCenter: parent.verticalCenter }
  }
}
