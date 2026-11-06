import QtQuick
import "Api.mjs" as Api
import "Compare.js" as Compare

// Up to four coins on one chart, each rebased to 0% at the start of the range:
// "did ETH do better than BTC this year", without the price gap between them
// squashing one line flat. Opened from a coin page, which stays underneath;
// back returns to it.
//
// The coins on offer are Bitcoin, Ethereum and Solana, the watchlist, and the
// top of the market list -- the names the app already knows, so choosing one
// costs no search.
Item {
  id: root
  property var app
  property string coinId: ""       // the coin it was opened from; always on the chart
  property var seed: null
  property string startDays: "7"
  property bool pane: false        // the right half of a split, not a page

  property string days: startDays
  readonly property var ranges: [
    { days: "1", label: "24h" }, { days: "7", label: "7d" }, { days: "30", label: "1M" },
    { days: "90", label: "3M" }, { days: "365", label: "1Y" }, { days: "max", label: "Max" }
  ]
  readonly property int maxCoins: 4

  readonly property string cur: app.currency
  readonly property int pad: app.compact ? 14 : 20
  readonly property var palette: [app.ui.accent, "#f59e0b", "#a78bfa", "#2dd4bf"]

  // The other coins on the chart, in the order they were picked.
  property var picked: []
  readonly property var ids: [coinId].concat(picked)

  // ---------------------------------------------------------------- names

  readonly property var listed: {
    app.gecko.revision
    return app.gecko.peek(Api.marketsUrl(cur, 1, 100, "")) || app.gecko.peek(Api.marketsUrl(cur, 1, 250, "")) || []
  }

  // id -> { symbol, name }, from everything the app has already loaded.
  readonly property var known: {
    var m = {
      bitcoin: { symbol: "BTC", name: "Bitcoin" },
      ethereum: { symbol: "ETH", name: "Ethereum" },
      solana: { symbol: "SOL", name: "Solana" }
    }
    var h = app.store.holdings
    for (var id in h) m[id] = { symbol: h[id].symbol || id, name: h[id].name || id }
    for (var i = 0; i < listed.length; i++) m[listed[i].id] = listed[i]
    if (seed && seed.id) m[seed.id] = seed
    return m
  }
  function symbolOf(id) { return known[id] && known[id].symbol ? known[id].symbol : id }
  function nameOf(id) { return known[id] && known[id].name ? known[id].name : id }

  readonly property var candidates: {
    var out = [], seen = {}
    seen[coinId] = true
    var add = function (id) {
      if (id && !seen[id]) { seen[id] = true; out.push(id) }
    }
    add("bitcoin")
    add("ethereum")
    add("solana")
    var w = app.store.watchlist
    for (var i = 0; i < w.length; i++) add(w[i])
    for (var j = 0; j < listed.length && j < 14; j++) add(listed[j].id)
    return out.slice(0, 20)
  }

  // ---------------------------------------------------------------- data

  function chartUrl(id) { return Api.chartUrl(id, cur, days) }

  readonly property var series: {
    app.gecko.revision
    var out = []
    for (var i = 0; i < ids.length; i++) {
      var pts = app.gecko.peek(chartUrl(ids[i]))
      out.push({ id: ids[i], label: symbolOf(ids[i]), color: palette[i], points: pts ? Compare.normalize(pts) : [] })
    }
    return out
  }
  readonly property bool loading: {
    app.gecko.revision
    for (var i = 0; i < ids.length; i++) if (app.gecko.busy(chartUrl(ids[i]))) return true
    return false
  }
  readonly property string error: {
    app.gecko.revision
    for (var i = 0; i < ids.length; i++) {
      var e = app.gecko.error(chartUrl(ids[i]))
      if (e) return e
    }
    return ""
  }

  function refresh(force) {
    var ttl = force ? 0 : (days === "1" ? 300000 : 1800000)
    for (var i = 0; i < ids.length; i++) app.gecko.want(chartUrl(ids[i]), "chart", ttl, true)
  }
  onIdsChanged: refresh(false)
  onDaysChanged: refresh(false)
  Component.onCompleted: {
    picked = [coinId === "bitcoin" ? "ethereum" : "bitcoin"]
    refresh(false)
  }
  Component.onDestruction: {
    if (!app || !app.gecko) return
    var urls = []
    for (var i = 0; i < ids.length; i++) urls.push(chartUrl(ids[i]))
    app.gecko.forget(urls)
  }

  function toggle(id) {
    var p = picked.slice()
    var at = p.indexOf(id)
    if (at >= 0) p.splice(at, 1)
    else if (ids.length < maxCoins) p.push(id)
    else return
    picked = p
  }

  function stepRange(delta) {
    var i = 0
    for (var k = 0; k < ranges.length; k++) if (ranges[k].days === days) i = k
    days = ranges[Math.max(0, Math.min(ranges.length - 1, i + delta))].days
  }

  // Always opaque: even beside the list it sits over the coin page.
  Rectangle {
    anchors.fill: parent
    color: root.app.ui.bg
  }

  // ---------------------------------------------------------------- top bar
  Item {
    id: topBar
    width: parent.width
    height: 56
    z: 2

    IconButton {
      id: backBtn
      x: 4
      anchors.verticalCenter: parent.verticalCenter
      app: root.app
      glyph: "󰁍"
      label: "Back"
      onClicked: if (!root.app.back()) root.app.dismiss()
    }
    Column {
      anchors.left: backBtn.right
      anchors.leftMargin: 8
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      Text {
        width: parent.width
        text: "Compare coins"
        color: root.app.ui.text
        font.family: root.app.ui.font
        font.pixelSize: root.app.ui.fs.lg
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: "Change since the start of the range"
        color: root.app.ui.muted
        font.family: root.app.ui.font
        font.pixelSize: root.app.ui.fs.xs
        elide: Text.ElideRight
      }
    }
    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width
      height: 1
      color: root.app.ui.divider
      opacity: flick.contentY > 4 ? 1 : 0
    }
  }

  // ---------------------------------------------------------------- body
  Flickable {
    id: flick
    anchors.top: topBar.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    contentWidth: width
    contentHeight: body.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: body
      x: root.pad
      width: flick.width - root.pad * 2
      spacing: 14
      topPadding: 6

      Row {
        id: rangeRow
        width: parent.width
        spacing: 6
        Repeater {
          model: root.ranges
          delegate: Chip {
            required property var modelData
            app: root.app
            width: (rangeRow.width - rangeRow.spacing * (root.ranges.length - 1)) / root.ranges.length
            text: modelData.label
            selected: root.days === modelData.days
            onClicked: root.days = modelData.days
          }
        }
      }

      CompareChart {
        width: parent.width
        height: root.app.compact ? 230 : 290
        app: root.app
        series: root.series
        days: root.days
        loading: root.loading
        error: root.error
      }

      // The coins on the chart, and how each did.
      Column {
        width: parent.width
        Repeater {
          model: root.series
          delegate: Item {
            id: legendRow
            required property var modelData
            readonly property var points: modelData.points
            readonly property real last: points.length ? points[points.length - 1][1] : NaN
            width: parent.width
            height: 40

            Rectangle {
              id: dot
              anchors.verticalCenter: parent.verticalCenter
              width: 10
              height: 10
              radius: 5
              color: legendRow.modelData.color
            }
            Text {
              id: sym
              anchors.left: dot.right
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: legendRow.modelData.label
              color: root.app.ui.text
              font.family: root.app.ui.font
              font.pixelSize: root.app.ui.fs.md
              font.weight: Font.DemiBold
            }
            Text {
              anchors.left: sym.right
              anchors.leftMargin: 8
              anchors.right: figure.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: root.nameOf(legendRow.modelData.id)
              color: root.app.ui.muted
              font.family: root.app.ui.font
              font.pixelSize: root.app.ui.fs.sm
              elide: Text.ElideRight
            }
            Change {
              id: figure
              anchors.right: removeBtn.left
              anchors.rightMargin: 4
              anchors.verticalCenter: parent.verticalCenter
              app: root.app
              badge: true
              value: legendRow.last
            }
            // Space where the remove button is, so rows line up.
            IconButton {
              id: removeBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              app: root.app
              glyph: "󰅖"
              label: "Remove " + legendRow.modelData.label
              size: 16
              color: root.app.ui.muted
              opacity: legendRow.modelData.id === root.coinId ? 0 : 1
              enabled: legendRow.modelData.id !== root.coinId
              onClicked: root.toggle(legendRow.modelData.id)
            }
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              color: root.app.ui.divider
            }
          }
        }
      }

      // Who else to put on it.
      Text {
        text: root.ids.length >= root.maxCoins ? "Up to " + root.maxCoins + " coins. Remove one to add another." : "Add a coin"
        color: root.app.ui.text
        font.family: root.app.ui.font
        font.pixelSize: root.app.ui.fs.md
        font.weight: Font.DemiBold
      }
      Flow {
        width: parent.width
        spacing: 6
        Repeater {
          model: root.candidates
          delegate: Chip {
            required property string modelData
            readonly property bool isOn: root.picked.indexOf(modelData) >= 0
            app: root.app
            hpad: 20
            text: root.symbolOf(modelData)
            selected: isOn
            opacity: isOn || root.ids.length < root.maxCoins ? 1 : 0.45
            onClicked: root.toggle(modelData)
          }
        }
      }

      Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "Every price is rebased to 0% at the start of the range, so coins of any size share one scale. Market data by CoinGecko."
        color: root.app.ui.muted
        font.family: root.app.ui.font
        font.pixelSize: root.app.ui.fs.xs
      }
    }
  }
}
