.pragma library

// Helpers for the compare page: every coin's price history rebased to 0% at
// the start of the range, so coins that cost a cent and coins that cost
// thousands share one scale.

// [[ms, price]] -> [[ms, percent change since the first usable price]]
function normalize(points) {
  if (!points || points.length < 2) return []
  var base = 0
  for (var i = 0; i < points.length; i++) {
    if (points[i][1] > 0) { base = points[i][1]; break }
  }
  if (!(base > 0)) return []
  var out = []
  for (var j = 0; j < points.length; j++) out.push([points[j][0], (points[j][1] / base - 1) * 100])
  return out
}

// Index of the point closest in time to `t`, in a series sorted by time.
function nearest(points, t) {
  if (!points || !points.length) return -1
  var lo = 0, hi = points.length - 1
  while (hi - lo > 1) {
    var mid = (lo + hi) >> 1
    if (points[mid][0] <= t) lo = mid; else hi = mid
  }
  return Math.abs(points[lo][0] - t) <= Math.abs(points[hi][0] - t) ? lo : hi
}
