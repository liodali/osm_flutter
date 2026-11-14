// Run with: node --test test/js/maplibre_tile_layer_test.cjs
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {resolve} = require('node:path');
const vm = require('node:vm');

const html = readFileSync(resolve(__dirname, '../../lib/src/asset/index_maplibre.html'), 'utf8');
const script = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)]
  .map((match) => match[1]).join('\n');
const clone = (value) => JSON.parse(JSON.stringify(value));

function createMap({loaded = true} = {}) {
  class FakeMap {
    constructor(options) {
      this.options = options;
      this.handlers = new Map();
      this.style = clone(options.style);
      this.loaded = loaded;
      this.pendingStyles = [];
    }
    on(type, fn) {
      const handlers = this.handlers.get(type) || [];
      handlers.push(fn);
      this.handlers.set(type, handlers);
      return this;
    }
    off(type, fn) {
      this.handlers.set(type, (this.handlers.get(type) || []).filter((f) => f !== fn));
    }
    once(type, fn) {
      const listener = (...args) => { this.off(type, listener); fn(...args); };
      this.on(type, listener);
    }
    emit(type, ...args) {
      for (const fn of [...(this.handlers.get(type) || [])]) fn(...args);
    }
    isStyleLoaded() { return this.loaded; }
    getStyle() { return this.style; }
    setStyle(style) {
      this.loaded = false;
      this.pendingStyles.push(style);
    }
    finishStyle() {
      const style = this.pendingStyles.shift();
      this.style = typeof style === 'string'
        ? {version: 8, sources: {vector: {type: 'vector'}}, layers: [{id: 'vector-base', type: 'fill', source: 'vector'}]}
        : clone(style);
      this.loaded = true;
      this.emit('style.load');
    }
    getSource(id) { return this.style.sources[id]; }
    getLayer(id) { return this.style.layers.find((layer) => layer.id === id); }
    addSource(id, source) {
      assert.ok(this.loaded, 'cannot add source before style loads');
      assert.ok(!this.getSource(id), 'duplicate source');
      this.style.sources[id] = source;
    }
    addLayer(layer, before) {
      assert.ok(!this.getLayer(layer.id), 'duplicate layer');
      const index = before == null ? this.style.layers.length : this.style.layers.findIndex((l) => l.id === before);
      assert.ok(index >= 0);
      this.style.layers.splice(index, 0, layer);
    }
    removeLayer(id) {
      assert.ok(this.getLayer(id), 'missing layer');
      this.style.layers = this.style.layers.filter((layer) => layer.id !== id);
    }
    removeSource(id) {
      assert.ok(!this.style.layers.some((layer) => layer.source === id), 'source still in use');
      delete this.style.sources[id];
    }
  }
  const context = vm.createContext({maplibregl: {Map: FakeMap}, console, setTimeout, clearTimeout});
  vm.runInContext(script, context);
  return context;
}
const raster = (url = 'https://tiles.example/{z}/{x}/{y}.png') => ({url, tileSize: 256, minZoom: 2, maxZoom: 19});
const tick = () => new Promise((resolve) => setImmediate(resolve));

// No tile server requests are made: the real iframe logic runs against a map fake.
test('default OSM uses canonical HTTPS endpoint, attribution and explicit referrer policy', () => {
  const c = createMap();
  assert.equal(c.defaultStyle.sources['osm-raster'].tiles[0], 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  assert.ok(c.mymap.options.attributionControl !== false);
  assert.equal(c.mymap.options.transformRequest('https://tile.openstreetmap.org/2/1/1.png', 'Tile').referrerPolicy,
    'strict-origin-when-cross-origin');
  assert.match(html, /<meta name="referrer" content="strict-origin-when-cross-origin">/);
  assert.doesNotMatch(script, /removeUnecessaryStaff|removeChild\(/);
});

test('legacy OSM subdomains normalize without changing other providers', () => {
  const c = createMap();
  const urls = c.buildTileUrls({...raster('https://{s}.tile.openstreetmap.org/'), subDomains: 'abc', tileExtension: '.png'});
  assert.deepEqual(clone(urls), ['https://tile.openstreetmap.org/{z}/{x}/{y}.png']);
  assert.deepEqual(clone(c.buildTileUrls({...raster('https://{s}.tiles.example/'), subDomains: 'ab', tileExtension: '.png'})),
    ['https://a.tiles.example/{z}/{x}/{y}.png', 'https://b.tiles.example/{z}/{x}/{y}.png']);
});

test('raster replacement stays below overlays and reset restores default idempotently', async () => {
  const c = createMap();
  c.mymap.addSource('road', {type: 'geojson'});
  c.mymap.addLayer({id: 'road-layer', source: 'road', type: 'line'});
  await c.changeTileLayer(raster());
  assert.equal(c.mymap.style.layers.at(-1).id, 'road-layer');
  const first = c.currentCustomSourceId;
  await c.changeTileLayer(raster('https://other.example/{z}/{x}/{y}.png'));
  assert.ok(!c.mymap.getSource(first));
  assert.equal(c.mymap.style.layers.at(-1).id, 'road-layer');
  await c.changeTileLayer(null);
  await c.changeTileLayer(null);
  assert.ok(c.mymap.getSource('osm-raster'));
  assert.deepEqual(c.mymap.style.layers.map((l) => l.id), ['osm-raster-layer', 'road-layer']);
});

test('style change waits for style.load and restores gradient road metrics', async () => {
  const c = createMap();
  c.routesLayer.set('gradient', {
    geojson: {type: 'Feature', geometry: {type: 'LineString', coordinates: [[0, 0], [1, 1]]}},
    layerId: 'road-layer-gradient',
    paint: {'line-gradient': ['interpolate', ['linear'], ['line-progress'], 0, 'red', 1, 'blue']},
  });
  let finished = false;
  const change = c.changeTileLayer({styleURL: 'https://styles.example/style.json'}).then(() => { finished = true; });
  await tick();
  assert.equal(finished, false);
  c.mymap.finishStyle();
  await change;
  assert.equal(c.mymap.getSource('road-gradient').lineMetrics, true);
  assert.ok(c.mymap.getLayer('road-layer-gradient').paint['line-gradient']);
});

test('vector to raster clears old basemap and serializes a following reset', async () => {
  const c = createMap();
  const vector = c.changeTileLayer({styleURL: 'https://styles.example/style.json'});
  await tick(); c.mymap.finishStyle(); await vector;
  const replacement = c.changeTileLayer(raster());
  const reset = c.changeTileLayer(null);
  await tick();
  assert.equal(c.mymap.pendingStyles.length, 1);
  c.mymap.finishStyle();
  await replacement;
  await reset;
  assert.ok(!c.mymap.getLayer('vector-base'));
  assert.ok(c.mymap.getLayer('osm-raster-layer'));
  assert.equal(c.currentCustomSourceId, null);
});

test('early raster selection waits for initial style load', async () => {
  const c = createMap({loaded: false});
  let complete = false;
  const change = c.changeTileLayer(raster()).then(() => { complete = true; });
  await tick();
  assert.equal(complete, false);
  c.mymap.loaded = true;
  c.mymap.emit('style.load');
  await change;
  assert.ok(c.mymap.getSource(c.currentCustomSourceId));
});


test('failed style rejects its caller but a reset can recover', async () => {
  const c = createMap();
  const url = 'https://styles.example/missing.json';
  const failed = assert.rejects(c.changeTileLayer({styleURL: url}), /style unavailable/);
  await tick();
  c.mymap.pendingStyles.shift();
  c.mymap.emit('error', {error: Object.assign(new Error('style unavailable'), {url})});
  await failed;
  const reset = c.changeTileLayer(null);
  await tick();
  c.mymap.finishStyle();
  await reset;
  assert.ok(c.mymap.getLayer('osm-raster-layer'));
});
