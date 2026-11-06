// Pure-logic tests for the JS helpers (no Quickshell needed): node tests/logic.test.cjs
const fs = require("fs"), vm = require("vm");
function load(f) { const src = fs.readFileSync(require("path").join(__dirname, "..", f), "utf8").replace(/^\.pragma library/m, ""); const ctx = {}; vm.createContext(ctx); vm.runInContext(src, ctx); return ctx; }
const T = load("Treemap.js"), P = load("Portfolio.js"), C = load("Compare.js");
const assert = require("assert");

// --- treemap: tiles fill the box exactly and never overlap
for (const [W, H, n] of [[800, 500, 60], [360, 600, 60], [1000, 300, 5], [500, 500, 1], [400, 400, 2]]) {
  const w = []; for (let i = 0; i < n; i++) w.push(Math.pow(1e12 / (i + 1) ** 1.3, 0.6));
  const r = T.layout(w, W, H);
  assert.strictEqual(r.length, n);
  let area = 0;
  for (const t of r) { assert(t.w >= -1e-9 && t.h >= -1e-9); assert(t.x >= -1e-6 && t.y >= -1e-6 && t.x + t.w <= W + 1e-6 && t.y + t.h <= H + 1e-6); area += t.w * t.h; }
  assert(Math.abs(area - W * H) < 1e-3 * W * H / 1000, `area ${W}x${H}: ${area}`);
  for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) {
    const a = r[i], b = r[j];
    const ox = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x), oy = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
    assert(!(ox > 1e-6 && oy > 1e-6), `overlap ${i},${j}`);
  }
  // area proportional to weight
  const tot = w.reduce((s, v) => s + v, 0);
  r.forEach((t, i) => assert(Math.abs(t.w * t.h - w[i] / tot * W * H) < 1e-3));
  const worstAspect = Math.max(...r.map(t => Math.max(t.w / t.h, t.h / t.w)));
  console.log(`${W}x${H} n=${n}: ok, worst aspect ${worstAspect.toFixed(1)}`);
}
// degenerate input
assert.deepStrictEqual(Array.from(T.layout([], 100, 100)), []);
assert.strictEqual(T.layout([1, 2], 0, 100)[0].w, 0);
const bad = T.layout([5, NaN, -1, 5], 100, 100);
assert.strictEqual(bad[1].w, 0); assert.strictEqual(bad[2].w, 0); assert(Math.abs(bad[0].w * bad[0].h - 5000) < 1e-6);
console.log("treemap degenerate: ok");

// --- portfolio history
const DAY = 86400000, t0 = 1_000_000_000_000;
const pts = (f) => Array.from({ length: 11 }, (_, i) => [t0 + i * DAY, f(i)]);
const charts = { a: pts(i => 100 + i), b: pts(() => 10) };
const holdings = {
  a: { txs: [{ side: "buy", amount: 2, ts: t0 + 3 * DAY }, { side: "sell", amount: 1, ts: t0 + 7 * DAY }] },
  b: { txs: [{ side: "buy", amount: 5, ts: t0 - 50 * DAY }] }   // bought before the window
};
const h = P.history(holdings, charts, ["a", "b"]);
assert.strictEqual(h.length, 11);
assert.strictEqual(h[0][1], 50);                       // only b held: 5 * 10
assert.strictEqual(h[3][1], 2 * 103 + 50);             // a bought on day 3
assert.strictEqual(h[6][1], 2 * 106 + 50);
assert.strictEqual(h[7][1], 1 * 107 + 50);             // half sold on day 7
assert.strictEqual(h[10][1], 1 * 110 + 50);
// starts at the first holding
const h2 = P.history({ a: holdings.a }, { a: charts.a }, ["a"]);
assert.strictEqual(h2[0][0], t0 + 3 * DAY); assert.strictEqual(h2.length, 8);
// nothing held in the window, missing chart, bad txs
assert.deepStrictEqual(Array.from(P.history({ a: { txs: [{ side: "buy", amount: 1, ts: t0 + 99 * DAY }] } }, { a: charts.a }, ["a"])), []);
assert.deepStrictEqual(Array.from(P.history(holdings, {}, ["a", "b"])), []);
assert.deepStrictEqual(Array.from(P.history({ a: { txs: [{ side: "buy", amount: "x", ts: 1 }, { side: "buy", amount: -3, ts: 1 }] } }, { a: charts.a }, ["a"])), []);
// overselling never goes negative
const h3 = P.history({ a: { txs: [{ side: "buy", amount: 1, ts: t0 }, { side: "sell", amount: 5, ts: t0 + 2 * DAY }] } }, { a: charts.a }, ["a"]);
assert(h3.every(p => p[1] >= 0));
console.log("portfolio history: ok");

// --- compare
const n = C.normalize([[1, 100], [2, 110], [3, 90]]);
assert.deepStrictEqual(Array.from(n[0]), [1, 0]); assert(Math.abs(n[1][1] - 10) < 1e-9); assert(Math.abs(n[2][1] + 10) < 1e-9);
assert.deepStrictEqual(Array.from(C.normalize([[1, 0], [2, 5], [3, 10]])[2]), [3, 100]);  // skips a zero start
assert.deepStrictEqual(Array.from(C.normalize([[1, 0], [2, 0]])), []);
assert.deepStrictEqual(Array.from(C.normalize([[1, 5]])), []);
const s = [[10, 0], [20, 0], [30, 0], [40, 0]];
assert.strictEqual(C.nearest(s, 0), 0); assert.strictEqual(C.nearest(s, 24), 1); assert.strictEqual(C.nearest(s, 26), 2); assert.strictEqual(C.nearest(s, 99), 3);
assert.strictEqual(C.nearest([], 5), -1); assert.strictEqual(C.nearest([[5, 1]], 9), 0);
console.log("compare: ok");
