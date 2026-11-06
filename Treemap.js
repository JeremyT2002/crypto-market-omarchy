.pragma library

// Squarified treemap (Bruls, Huizing, van Wijk): `weights`, largest first,
// become rectangles that tile a W x H box exactly, each as close to square as
// the order allows, so a label fits in as many as possible.
//
// Returns [{ x, y, w, h }], one per weight and in the same order. A weight
// that is not a positive number gets an empty rectangle rather than an error.

function worst(areas, from, to, sum, side) {
  var lo = Infinity, hi = 0
  for (var i = from; i < to; i++) {
    lo = Math.min(lo, areas[i])
    hi = Math.max(hi, areas[i])
  }
  var s2 = side * side
  return Math.max(s2 * hi / (sum * sum), sum * sum / (s2 * lo))
}

function layout(weights, W, H) {
  var n = weights ? weights.length : 0
  var out = []
  for (var z = 0; z < n; z++) out.push({ x: 0, y: 0, w: 0, h: 0 })
  if (!n || !(W > 0) || !(H > 0)) return out

  var items = []
  var total = 0
  for (var i = 0; i < n; i++) {
    var v = Number(weights[i])
    if (v > 0 && isFinite(v)) { items.push({ at: i, v: v }); total += v }
  }
  if (!items.length) return out

  var areas = []
  for (var a = 0; a < items.length; a++) areas.push(items[a].v / total * W * H)

  var x = 0, y = 0, w = W, h = H
  var start = 0
  while (start < items.length) {
    var side = Math.min(w, h)
    var end = start + 1
    var sum = areas[start]
    var best = worst(areas, start, end, sum, side)
    while (end < items.length) {
      var next = sum + areas[end]
      var r = worst(areas, start, end + 1, next, side)
      if (r > best) break
      sum = next
      best = r
      end++
    }

    // The row runs along the shorter side, `thick` deep.
    var thick = sum / side
    if (w >= h) {
      var cy = y
      for (var k = start; k < end; k++) {
        var ch = areas[k] / thick
        out[items[k].at] = { x: x, y: cy, w: thick, h: ch }
        cy += ch
      }
      x += thick
      w -= thick
    } else {
      var cx = x
      for (var m = start; m < end; m++) {
        var cw = areas[m] / thick
        out[items[m].at] = { x: cx, y: y, w: cw, h: thick }
        cx += cw
      }
      y += thick
      h -= thick
    }
    start = end
  }
  return out
}
