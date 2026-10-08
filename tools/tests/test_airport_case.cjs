const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'airpots/1005/index.html'), 'utf8');
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'airpots/1005/catalog.json')));
const runs = catalog.services.airport.runs;
assert.equal(runs.length, 6);
assert.equal(new Set(runs.map(run => run.id)).size, 6);
for (const run of runs) {
  const hasAccumulation = ['airport_yunnan_20261004_12', 'airport_yunnan_20261005_00'].includes(run.id);
  assert.equal(run.products.length, hasAccumulation ? 2 : 1);
  if (hasAccumulation) {
    assert.equal(run.products[1].id, 'airport_yunnan_accum_12h');
    assert.equal(run.products[1].frames.length, 1);
    assert(/T(08|20):00:00\+08:00$/.test(run.products[1].frames[0].valid_time));
  }
  assert.equal(run.products[0].description, 'WORK_yn 云南逐小时降水预报图。');
  assert.deepEqual(run.products[0].frames.map(frame => frame.id), ['airport_region', 'airport_national']);
  for (const frame of run.products[0].frames) {
    const expected = run.id.endsWith('20261004_00') ? 11 : 12;
    assert.equal(frame.individual_frames.length, expected);
    assert(frame.individual_frames.some(item => {
      const end = Date.parse(item.valid_time);
      return end > Date.parse('2026-10-05T00:00:00+08:00') &&
        end - 3600000 < Date.parse('2026-10-06T00:00:00+08:00');
    }));
  }
}
function checkUrls(value) {
  if (Array.isArray(value)) value.forEach(checkUrls);
  else if (value && typeof value === 'object') Object.values(value).forEach(checkUrls);
  else if (typeof value === 'string' && value.startsWith('https://') && value.includes('aliyuncs.com')) {
    assert(value.includes('/iaplacs/cases/20261005/'), value);
    assert(!value.includes('/data/current/maps/'), value);
  }
}
checkUrls(catalog);
assert(html.includes('data-max-display-runs="6"'));
assert(html.includes('data-force-default-source="true"'));
assert(!html.includes('data/current/forecast-runs.json'));
assert(html.includes('<h2>中国西南部</h2>'));
for (const requiredCopy of ['当前起报', 'id="publishedAt"', '服务评价']) assert(html.includes(requiredCopy));
for (const removedCopy of ['降水个例', '警报发布时间', '重点批次', '资料说明', '52 mm']) {
  assert(!html.includes(removedCopy), removedCopy);
}
const initialId = html.match(/data-initial-run="([^"]+)"/)[1];
const initialTime = html.match(/data-initial-valid-time="([^"]+)"/)[1];
const initialRun = runs.find(run => run.id === initialId);
assert.equal(initialRun.run_time, '2026-10-04T14:00:00+08:00');
const initialHour = initialRun.products[0].frames[0].individual_frames.find(
  frame => Date.parse(frame.valid_time) === Date.parse(initialTime),
);
assert(initialHour, 'The default event hour must exist');
const warningTime = Date.parse('2026-10-05T06:40:00+08:00');
assert(warningTime < Date.parse(initialHour.valid_time));
assert(warningTime >= Date.parse(initialHour.valid_time) - 3600000);
const app = fs.readFileSync(path.join(root, 'app.js'), 'utf8');
const declaration = app.slice(app.indexOf('const MAX_DISPLAY_RUNS'), app.indexOf('const MAX_VIEWER_SCALE'));
for (const [setting, expected] of [[undefined, 5], ['6', 6], ['bad', 5], ['1000', 50]]) {
  const actual = vm.runInNewContext(declaration + '\nMAX_DISPLAY_RUNS', {
    document: {body: {dataset: {maxDisplayRuns: setting}}},
  });
  assert.equal(actual, expected);
}
console.log('Airport case: six overlapping runs, isolated assets and default limits verified.');
