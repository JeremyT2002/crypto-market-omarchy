.pragma library

// What the recorded holdings were worth over time: at each point of the price
// history, every coin's quantity held then times its price then.
//
// `holdings` is the store's { id: { txs: [{ side, amount, ts }] } }, `charts`
// is { id: [[ms, price]] } for the same range and currency, and `ids` says
// which coins to count. Returns [[ms, value]] from the first moment anything
// was held, or [] when nothing was.
//
// A buy or a sell moves the line by its own size, on the day it was recorded:
// this is the value of what was held, not a return.

function history(holdings, charts, ids) {
  var coins = []
  var grid = null
  for (var i = 0; i < ids.length; i++) {
    var id = ids[i]
    var pts = charts[id]
    var h = holdings[id]
    if (!pts || pts.length < 2 || !h) continue

    var moves = []
    var txs = h.txs || []
    for (var j = 0; j < txs.length; j++) {
      var ts = Number(txs[j].ts)
      var amount = Number(txs[j].amount)
      if (!isFinite(ts) || !(amount > 0)) continue
      moves.push({ ts: ts, d: txs[j].side === "sell" ? -amount : amount })
    }
    moves.sort(function (a, b) { return a.ts - b.ts })

    coins.push({ pts: pts, moves: moves, p: 0, m: 0, qty: 0 })
    if (!grid || pts.length > grid.length) grid = pts
  }
  if (!grid) return []

  var out = []
  var started = false
  for (var g = 0; g < grid.length; g++) {
    var t = grid[g][0]
    var value = 0
    for (var c = 0; c < coins.length; c++) {
      var coin = coins[c]
      while (coin.m < coin.moves.length && coin.moves[coin.m].ts <= t) {
        coin.qty += coin.moves[coin.m].d
        coin.m++
      }
      while (coin.p + 1 < coin.pts.length && coin.pts[coin.p + 1][0] <= t) coin.p++
      if (coin.qty > 0) value += coin.qty * coin.pts[coin.p][1]
    }
    if (!started && value > 0) started = true
    if (started) out.push([t, value])
  }
  return out.length > 1 ? out : []
}
