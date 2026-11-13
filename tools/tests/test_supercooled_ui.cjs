const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('app.js', 'utf8');
const snippet = name => {
  const start = source.indexOf(`function ${name}(`);
  const end = source.indexOf('\nfunction ', start + 1);
  assert.ok(start >= 0, name);
  return source.slice(start, end);
};
for (const enabled of [false, true]) {
  const context = vm.createContext({
    SUPERCOOLED_PATHS_ENABLED: enabled, MAX_DISPLAY_RUNS: 5,
    normalizeNingxiaRun: x => x, normalizeShangraoRuns: x => x,
  });
  vm.runInContext(snippet('limitCatalogRuns'), context);
  for (const service of ['ningxia', 'airport', 'xinjiang']) {
    const products = ['precip_series', 'supercooled_cloud', 'supercooled_rain']
      .map(id => ({id: `${service}_${id}`}));
    context.raw = { services: { [service]: { runs: [{id:'test', products}] } } };
    const result = vm.runInContext('limitCatalogRuns(raw)', context);
    assert.equal(result.services[service].runs[0].products.length, enabled ? 3 : 1);
    assert.equal(context.raw.services[service].runs[0].products.length, 3);
    for (const kind of ['cloud', 'rain']) {
      assert.ok(source.includes(`"${service}_supercooled_${kind}"`));
    }
  }
}
for (const file of ['index.html','airpots/index.html','xinjiang/index.html']) {
  assert.ok(!fs.readFileSync(file,'utf8').includes('data-supercooled-paths="enabled"'));
}
console.log('Supercooled UI: disabled by default, both products available on opt-in');
