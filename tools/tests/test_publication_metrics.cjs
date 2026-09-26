const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "../../app.js"), "utf8");
const blocks = [];
const context = vm.createContext({
  Intl,
  Date,
  document: { createElement: () => ({}) },
  els: { metricGrid: { innerHTML: "", appendChild: (block) => blocks.push(block) } },
});
for (const [start, end] of [
  ["function renderMetrics(", "function renderProductNote("],
  ["function formatPublicationTime(", "els.prevLead?."],
]) {
  const offset = source.indexOf(start);
  assert.ok(offset >= 0);
  const finish = source.indexOf(end, offset);
  assert.ok(finish > offset);
  vm.runInContext(source.slice(offset, finish), context);
}

const product = { metrics: [
  { label: "起报时次", value: "20260926 00 UTC" },
  { label: "生成时间", value: "2026-09-26 19:16 BJT" },
  { label: "图像数量", value: "3" },
] };
const original = JSON.stringify(product);
context.renderMetrics(product, { publication_time: "2026-09-26T11:37:33+00:00" });
assert.equal(blocks.length, 3);
assert.match(blocks[1].innerHTML, /生成时间/);
assert.match(blocks[2].innerHTML, /发布时间/);
assert.match(blocks[2].innerHTML, /2026-09-26 19:37 BJT/);
assert.ok(blocks.every((block) => !block.innerHTML.includes("图像数量")));
assert.equal(JSON.stringify(product), original);
assert.equal(context.formatPublicationTime("2026-09-26T16:00:00Z"), "2026-09-27 00:00 BJT");
assert.equal(context.formatPublicationTime("invalid"), "--");
assert.equal(context.formatPublicationTime(null), "--");
console.log("Publication metric order, BJT conversion, midnight and missing-time checks passed");
