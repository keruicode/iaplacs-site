const DEFAULT_REFRESH_MS = 2 * 60 * 1000;
const MAX_DISPLAY_RUNS = 5;
const MAX_VIEWER_SCALE = 6;
const VIEWER_ZOOM_STEP = 1.25;
const IMAGE_CACHE_NAME = "iaplacs-forecast-images-v1";
const IMAGE_PREFETCH_CONCURRENCY = 3;
const ACCESS_PASSWORD = "123";
const ACCESS_TOKEN_KEY = "iaplacs_access_token";
const ACCESS_TOKEN_VALUE = "iaplacs_access_granted_v1";
const SHANGRAO_PINNED_RUN_IDS = ["20260710_02"];

const pageConfig = {
  service: document.body.dataset.service || "airport",
  manifestUrl: document.body.dataset.manifestUrl || "./data/current/forecast-runs.json",
  fallbackManifestUrl:
    document.body.dataset.fallbackManifestUrl || "./data/current/manifest.json",
  assetBase: document.body.dataset.assetBase || "./",
  refreshMs: Number(document.body.dataset.refreshMs || DEFAULT_REFRESH_MS),
};

const state = {
  catalog: null,
  service: null,
  runIndex: 0,
  productIndex: 0,
  leadIndex: 0,
  refreshTimer: null,
  loading: false,
  hasNewLatestRun: false,
  imageRequestId: 0,
  imageSource: null,
  imageStatus: "idle",
  prefetchSignature: "",
};

const imageResourceCache = new Map();
let persistentImageCachePromise = null;

const els = {
  updateLabel: document.querySelector("#updateLabel"),
  runSummary: document.querySelector("#runSummary"),
  refreshCatalog: document.querySelector("#refreshCatalog"),
  runList: document.querySelector("#runList"),
  productList: document.querySelector("#productList"),
  runTime: document.querySelector("#runTime"),
  publishedAt: document.querySelector("#publishedAt"),
  sourceNote: document.querySelector("#sourceNote"),
  productUnit: document.querySelector("#productUnit"),
  productTitle: document.querySelector("#productTitle"),
  mapStage: document.querySelector(".map-stage"),
  forecastImage: document.querySelector("#forecastImage"),
  leadLabel: document.querySelector("#leadLabel"),
  validTime: document.querySelector("#validTime"),
  leadTabs: document.querySelector("#leadTabs"),
  prevLead: document.querySelector("#prevLead"),
  nextLead: document.querySelector("#nextLead"),
  imageLink: document.querySelector("#imageLink"),
  metricGrid: document.querySelector("#metricGrid"),
  productNote: document.querySelector("#productNote"),
};

const viewerState = {
  root: null,
  stage: null,
  image: null,
  title: null,
  meta: null,
  zoomLabel: null,
  scale: 1,
  x: 0,
  y: 0,
  pointers: new Map(),
  gesture: null,
  opener: null,
  source: null,
  requestId: 0,
  loading: false,
  resetOnImageLoad: false,
};

async function init() {
  setupImageViewer();
  await loadForecast({ preserveSelection: false });
  if (pageConfig.refreshMs > 0) {
    state.refreshTimer = window.setInterval(
      () => loadForecast({ preserveSelection: true }),
      pageConfig.refreshMs,
    );
  }
}

async function loadForecast({ preserveSelection }) {
  if (state.loading) return;
  state.loading = true;
  setRefreshState(true);
  const previous = preserveSelection ? currentSelection() : {};
  const previousLatestRunId = preserveSelection ? state.service?.latest_run : undefined;

  try {
    const raw = await fetchForecastData();
    const catalog = normalizeForecastData(raw);
    const service = selectService(catalog);
    const hasNewLatestRun = Boolean(
      previousLatestRunId &&
        service?.latest_run &&
        service.latest_run !== previousLatestRunId,
    );

    state.catalog = catalog;
    state.service = service;
    state.hasNewLatestRun = hasNewLatestRun;
    state.runIndex = chooseRunIndex(service, hasNewLatestRun ? undefined : previous.runId);
    state.productIndex = chooseProductIndex(currentRun(), previous.productId);
    state.leadIndex = chooseLeadIndex(currentProduct(), previous.frameId);
    syncForecastImageCache(catalog);
    render();
  } catch (error) {
    if (state.catalog) {
      setText(els.updateLabel, "更新检查失败，正在显示已有数据");
      console.error(error);
    } else {
      showError(error);
    }
  } finally {
    state.loading = false;
    setRefreshState(false);
  }
}

async function fetchForecastData() {
  try {
    return await fetchJson(withCacheBuster(pageConfig.manifestUrl));
  } catch (error) {
    console.warn(`primary forecast catalog failed: ${pageConfig.manifestUrl}`, error);
    return fetchJson(withCacheBuster(pageConfig.fallbackManifestUrl));
  }
}

async function fetchJson(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`${url} ${response.status}`);
  return response.json();
}

function normalizeForecastData(raw) {
  if (raw.services) return limitCatalogRuns(raw);

  const legacyRun = {
    id: "legacy-current",
    label: formatTime(raw.run_time),
    run_time: raw.run_time,
    published_at: raw.published_at,
    summary: raw.note,
    products: raw.products || [],
    station_series: raw.station_series,
  };

  return limitCatalogRuns({
    schema_version: 0,
    site: raw.site || { name: "IAP-LACS Forecast", domain: "iaplacs.xyz" },
    published_at: raw.published_at,
    services: {
      main: {
        title: "机场气象服务",
        note: raw.note,
        latest_run: legacyRun.id,
        runs: [legacyRun],
        station_series: raw.station_series,
      },
      airport: {
        title: "机场气象服务",
        note: raw.note,
        latest_run: legacyRun.id,
        runs: [legacyRun],
        station_series: raw.station_series,
      },
      shangrao: {
        title: "上饶专项天气服务",
        note: raw.note,
        latest_run: legacyRun.id,
        runs: [legacyRun],
        station_series: raw.station_series,
      },
    },
  });
}

function limitCatalogRuns(catalog) {
  const services = Object.fromEntries(
    Object.entries(catalog.services || {}).map(([key, service]) => {
      const sourceRuns = Array.isArray(service?.runs) ? service.runs : [];
      const runs =
        key === "shangrao"
          ? normalizeShangraoRuns(sourceRuns)
          : sourceRuns.slice(0, MAX_DISPLAY_RUNS);
      const latestRunId = runs.some((run) => run.id === service?.latest_run)
        ? service.latest_run
        : runs[0]?.id || null;
      return [key, { ...service, latest_run: latestRunId, runs }];
    }),
  );
  return { ...catalog, services };
}

function normalizeShangraoRuns(sourceRuns) {
  const normalized = sourceRuns.map(normalizeShangraoRun);
  const latestRuns = normalized.slice(0, MAX_DISPLAY_RUNS);
  const runsById = new Map(latestRuns.map((run) => [run.id, run]));

  for (const run of normalized) {
    if (SHANGRAO_PINNED_RUN_IDS.includes(run.id) && !runsById.has(run.id)) {
      runsById.set(run.id, run);
    }
  }

  for (const runId of SHANGRAO_PINNED_RUN_IDS) {
    if (!runsById.has(runId)) {
      runsById.set(runId, createPinnedShangraoRun(runId));
    }
  }

  return [...runsById.values()].sort((a, b) => {
    const aTime = Date.parse(a.run_time || "");
    const bTime = Date.parse(b.run_time || "");
    return (Number.isFinite(bTime) ? bTime : 0) - (Number.isFinite(aTime) ? aTime : 0);
  });
}

function normalizeShangraoRun(run) {
  return {
    ...run,
    products: (run.products || []).map((product) => {
      const frames = normalizeShangraoFrames(run, product.frames || []);
      return {
        ...product,
        metrics: updateFrameCountMetric(product.metrics || [], frames.length),
        frames,
      };
    }),
  };
}

function updateFrameCountMetric(metrics, frameCount) {
  let replaced = false;
  const updated = metrics.map((metric) => {
    if (metric.label !== "图像数量") return metric;
    replaced = true;
    return { ...metric, value: String(frameCount) };
  });
  if (!replaced) updated.push({ label: "图像数量", value: String(frameCount) });
  return updated;
}

function normalizeShangraoFrames(run, frames) {
  const overviewFrames = [];
  const detailFrames = new Map();
  const otherFrames = [];

  for (const frame of frames) {
    if (isShangraoOverviewFrame(frame)) {
      overviewFrames.push(frame);
      continue;
    }
    const page = shangraoDetailPage(frame);
    if (page) {
      const current = detailFrames.get(page);
      if (!current || preferForecastFrame(frame, current)) detailFrames.set(page, frame);
      continue;
    }
    otherFrames.push(frame);
  }

  const normalized = [];
  if (overviewFrames.length) {
    normalized.push({
      ...overviewFrames.reduce((best, frame) => (preferForecastFrame(frame, best) ? frame : best)),
      id: "overview",
      lead_label: "总览",
      valid_label: "",
    });
  }

  [...detailFrames.entries()]
    .sort(([a], [b]) => a - b)
    .forEach(([page, frame]) => {
      normalized.push({
        ...frame,
        id: `detail_p${String(page).padStart(2, "0")}`,
        lead_label: formatShangraoWindow(run.run_time, page),
        valid_label: "",
      });
    });

  return normalized.concat(otherFrames);
}

function isShangraoOverviewFrame(frame) {
  return /overview/i.test(`${frame?.id || ""} ${frame?.lead_label || ""} ${frame?.file || ""}`);
}

function shangraoDetailPage(frame) {
  const value = `${frame?.id || ""} ${frame?.lead_label || ""} ${frame?.file || ""}`;
  const match = value.match(/detail_p0?([1-3])|细节\s*([1-3])\/3/i);
  if (!match) return 0;
  return Number(match[1] || match[2] || 0);
}

function preferForecastFrame(candidate, current) {
  const candidateFile = String(candidate?.file || "");
  const currentFile = String(current?.file || "");
  const candidateScore = forecastFramePreferenceScore(candidateFile);
  const currentScore = forecastFramePreferenceScore(currentFile);
  if (candidateScore !== currentScore) return candidateScore > currentScore;
  return Number(candidate?.bytes || Infinity) < Number(current?.bytes || Infinity);
}

function forecastFramePreferenceScore(file) {
  let score = 0;
  if (/_6x6_/i.test(file)) score += 4;
  if (/\.webp(?:\?|$)/i.test(file)) score += 2;
  if (/\.png(?:\?|$)/i.test(file)) score += 1;
  return score;
}

function formatShangraoWindow(runTime, page) {
  const runDate = new Date(runTime || "");
  if (Number.isNaN(runDate.getTime())) return `细节 ${page}/3`;
  const start = addHours(runDate, 12 + (page - 1) * 12);
  const end = addHours(runDate, 24 + (page - 1) * 12);
  const startParts = bjtParts(start);
  const endParts = bjtParts(end);
  return `${twoDigits(startParts.month)}-${twoDigits(startParts.day)} ${twoDigits(startParts.hour)}-${twoDigits(endParts.hour)}`;
}

function addHours(date, hours) {
  return new Date(date.getTime() + hours * 60 * 60 * 1000);
}

function bjtParts(date) {
  const bjtDate = new Date(date.getTime() + 8 * 60 * 60 * 1000);
  return {
    month: bjtDate.getUTCMonth() + 1,
    day: bjtDate.getUTCDate(),
    hour: bjtDate.getUTCHours(),
  };
}

function twoDigits(value) {
  return String(value).padStart(2, "0");
}

function createPinnedShangraoRun(runId) {
  const runTime = parseRunId(runId);
  const frameBase = `./data/current/maps/wrf_montage_${runId}`;
  const product = {
    id: "wrf_rain_montage",
    title: "上饶 WRF 逐小时降水拼图",
    category: "上饶预报",
    unit: "mm",
    color: "#0f68c8",
    description: `上饶服务起报时次 ${runId}，包含总览图和分段细节图。`,
    metrics: [
      { label: "起报时次", value: runId.replace("_", " ") + " BJT" },
      { label: "图像数量", value: "4" },
      { label: "产品状态", value: "历史补充" },
    ],
    frames: [
      {
        id: "overview",
        lead: 48,
        lead_label: "总览",
        valid_label: "",
        file: `${frameBase}/${runId}_combined_overview_6x6_grid.webp`,
      },
      ...[1, 2, 3].map((page) => ({
        id: `detail_p${String(page).padStart(2, "0")}`,
        lead: 12 + page * 12,
        lead_label: formatShangraoWindow(runTime, page),
        valid_label: "",
        file: `${frameBase}/${runId}_combined_detail_p${String(page).padStart(2, "0")}_4x3_grid.webp`,
      })),
    ],
  };

  return {
    id: runId,
    label: `${runId.slice(0, 4)}-${runId.slice(4, 6)}-${runId.slice(6, 8)} ${runId.slice(9, 11)}:00 BJT`,
    run_time: runTime,
    published_at: runTime,
    summary: "WRF 逐小时降水拼图，共 4 张图",
    products: [product],
  };
}

function parseRunId(runId) {
  return `${runId.slice(0, 4)}-${runId.slice(4, 6)}-${runId.slice(6, 8)}T${runId.slice(9, 11)}:00:00+08:00`;
}

function selectService(catalog) {
  const services = catalog.services || {};
  return (
    services[pageConfig.service] ||
    services.airport ||
    services.main ||
    Object.values(services)[0]
  );
}

function chooseRunIndex(service, previousRunId) {
  const runs = service?.runs || [];
  if (!runs.length) return 0;

  const targetId = previousRunId || service.latest_run;
  const found = runs.findIndex((run) => run.id === targetId);
  return found >= 0 ? found : 0;
}

function chooseProductIndex(run, previousProductId) {
  const products = run?.products || [];
  if (!products.length) return 0;
  const found = products.findIndex((product) => product.id === previousProductId);
  return found >= 0 ? found : 0;
}

function chooseLeadIndex(product, previousFrameId) {
  const frames = product?.frames || [];
  if (!frames.length) return 0;
  const found = frames.findIndex((frame) => frameId(frame) === previousFrameId);
  return found >= 0 ? found : 0;
}

function currentSelection() {
  return {
    runId: currentRun()?.id,
    productId: currentProduct()?.id,
    frameId: frameId(currentFrame()),
  };
}

function render() {
  const run = currentRun();
  const product = currentProduct();
  const frame = currentFrame();

  if (!state.catalog || !state.service || !run || !product || !frame) {
    renderEmpty();
    return;
  }

  document.title = `${state.service.title || product.title} | ${state.catalog.site.name}`;
  const updatePrefix = state.hasNewLatestRun ? "已切换至新时次" : "已更新";
  setText(
    els.updateLabel,
    `${updatePrefix} ${formatTime(run.published_at || state.catalog.published_at)}`,
  );
  setText(els.runSummary, formatRunSummary(state.service.runs || []));
  setText(els.runTime, run.label || formatTime(run.run_time));
  setText(els.publishedAt, formatTime(run.published_at || state.catalog.published_at));
  setText(
    els.sourceNote,
    pageConfig.service === "ningxia"
      ? ""
      : state.service.note || run.summary || state.catalog.note || "",
  );

  renderRuns();
  renderProducts();
  renderLeads();
  renderMetrics(product);
  renderProductNote(run, product, frame);
  updateControls(product);

  const imageSrc = forecastFrameSource(run, frame);
  const frameLabel = displayFrameLabel(frame);
  const imageAlt = `${product.title} ${frameLabel}`;
  setText(els.productTitle, product.title);
  setText(els.productUnit, `${product.category || "预报产品"} | ${product.unit || "--"}`);
  if (els.forecastImage) {
    loadForecastImage(imageSrc, imageAlt);
  }
  if (els.imageLink) els.imageLink.href = imageSrc;
  setText(els.leadLabel, frameLabel);
  setText(
    els.validTime,
    pageConfig.service === "ningxia" || pageConfig.service === "shangrao"
      ? ""
      : frame.valid_label || `有效时间 ${formatTime(frame.valid_time)}`,
  );
  updateViewerControls();
  if (viewerState.root && !viewerState.root.hidden) {
    syncViewerFrame(imageSrc, imageAlt, { reset: false });
  }
  warmServiceImages(state.service, imageSrc);
}

function updateControls(product) {
  const hasMultipleFrames = (product.frames || []).length > 1;
  if (els.prevLead) els.prevLead.disabled = !hasMultipleFrames;
  if (els.nextLead) els.nextLead.disabled = !hasMultipleFrames;
}

function renderEmpty() {
  setText(els.updateLabel, "暂无数据");
  setText(els.productTitle, "暂无可显示产品");
  setText(els.productUnit, "--");
  setText(els.leadLabel, "--");
  setText(els.validTime, "--");
  if (els.productList) els.productList.innerHTML = "";
  if (els.runList) els.runList.innerHTML = "";
  if (els.leadTabs) els.leadTabs.innerHTML = "";
  setText(els.runSummary, "暂无起报时次");
}

function renderRuns() {
  if (!els.runList) return;
  els.runList.innerHTML = "";
  const runs = state.service.runs || [];
  const latestRunId = state.service.latest_run;
  const displayRuns = runs
    .map((run, index) => ({ run, index }))
    .reverse();

  displayRuns.forEach(({ run, index }) => {
    const parts = formatRunParts(run);
    const button = document.createElement("button");
    button.type = "button";
    button.className = `run-button${index === state.runIndex ? " is-active" : ""}`;
    button.setAttribute("aria-pressed", String(index === state.runIndex));
    button.setAttribute(
      "aria-label",
      `${parts.date} ${parts.time} ${parts.zone}${run.id === latestRunId ? "，最新起报" : ""}`.trim(),
    );

    const date = document.createElement("span");
    date.className = "run-date";
    date.textContent = parts.date;

    const timeRow = document.createElement("span");
    timeRow.className = "run-time-row";
    const clock = document.createElement("span");
    clock.className = "run-clock";
    clock.textContent = parts.time;
    const zone = document.createElement("span");
    zone.className = "run-zone";
    zone.textContent = parts.zone;
    timeRow.append(clock, zone);

    if (run.id === latestRunId) {
      const latest = document.createElement("span");
      latest.className = "run-latest";
      latest.textContent = "最新";
      timeRow.appendChild(latest);
    }

    button.append(date, timeRow);
    button.addEventListener("click", () => {
      state.runIndex = index;
      state.productIndex = 0;
      state.leadIndex = 0;
      state.hasNewLatestRun = false;
      render();
    });
    els.runList.appendChild(button);
  });

  window.requestAnimationFrame(() => {
    els.runList.querySelector(".run-button.is-active")?.scrollIntoView({
      block: "nearest",
      inline: "nearest",
    });
  });
}

function renderProducts() {
  if (!els.productList) return;
  els.productList.innerHTML = "";
  (currentRun().products || []).forEach((product, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `product-button${index === state.productIndex ? " is-active" : ""}`;
    button.innerHTML = `
      <span class="product-stripe" style="background:${product.color || "#0f68c8"}"></span>
      <span>
        <span class="product-name">${product.title}</span>
        <span class="product-desc">${product.description || ""}</span>
      </span>
    `;
    button.addEventListener("click", () => {
      state.productIndex = index;
      state.leadIndex = 0;
      render();
    });
    els.productList.appendChild(button);
  });
}

function renderLeads() {
  if (!els.leadTabs) return;
  const product = currentProduct();
  els.leadTabs.innerHTML = "";
  const frames = product.frames || [];
  const hideSingleNingxiaFrame = pageConfig.service === "ningxia" && frames.length <= 1;
  els.leadTabs.hidden = hideSingleNingxiaFrame;
  if (hideSingleNingxiaFrame) return;
  frames.forEach((frame, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `lead-tab${index === state.leadIndex ? " is-active" : ""}`;
    button.textContent = displayFrameLabel(frame);
    button.addEventListener("click", () => {
      state.leadIndex = index;
      render();
    });
    els.leadTabs.appendChild(button);
  });
}

function renderMetrics(product) {
  if (!els.metricGrid) return;
  els.metricGrid.innerHTML = "";
  const metrics = product.metrics?.length
    ? product.metrics
    : [{ label: "图像数量", value: String(product.frames?.length || 0) }];

  metrics.forEach((metric) => {
    const block = document.createElement("div");
    block.className = "metric";
    block.innerHTML = `
      <p class="metric-label">${metric.label}</p>
      <p class="metric-value">${metric.value}</p>
    `;
    els.metricGrid.appendChild(block);
  });
}

function renderProductNote(run, product, frame) {
  if (!els.productNote) return;
  const parts = [
    product.description,
    run.summary,
    pageConfig.service === "shangrao"
      ? ""
      : frame.valid_label || (frame.valid_time ? `有效时间 ${formatTime(frame.valid_time)}` : ""),
  ].filter(Boolean);
  els.productNote.textContent = parts.join(" ");
}

function displayFrameLabel(frame) {
  return frame?.lead_label || frame?.valid_label || "--";
}

function currentRun() {
  return state.service?.runs?.[state.runIndex];
}

function currentProduct() {
  return currentRun()?.products?.[state.productIndex];
}

function currentFrame() {
  return currentProduct()?.frames?.[state.leadIndex];
}

function forecastFrameSource(run, frame) {
  return withAssetVersion(
    resolveAssetPath(frame?.file),
    frame?.version || run?.published_at || state.catalog?.published_at,
  );
}

function collectServiceImageSources(service) {
  const sources = new Set();
  for (const run of service?.runs || []) {
    for (const product of run.products || []) {
      for (const frame of product.frames || []) {
        const source = forecastFrameSource(run, frame);
        if (source) sources.add(source);
      }
    }
  }
  return [...sources];
}

function collectCatalogImageSources(catalog) {
  const sources = new Set();
  for (const service of Object.values(catalog?.services || {})) {
    collectServiceImageSources(service).forEach((source) => sources.add(source));
  }
  return sources;
}

function syncForecastImageCache(catalog) {
  const desiredSources = collectCatalogImageSources(catalog);
  for (const [source, entry] of imageResourceCache) {
    if (desiredSources.has(source) || !entry.objectUrl) continue;
    URL.revokeObjectURL(entry.objectUrl);
    imageResourceCache.delete(source);
  }
  void prunePersistentImageCache(desiredSources);
}

function warmServiceImages(service, activeSource) {
  const sources = collectServiceImageSources(service);
  const signature = sources.join("\n");
  if (state.prefetchSignature === signature) return;
  state.prefetchSignature = signature;

  const orderedSources = [
    activeSource,
    ...sources.filter((source) => source !== activeSource),
  ].filter(Boolean);
  let cursor = 0;
  const worker = async () => {
    while (cursor < orderedSources.length) {
      const source = orderedSources[cursor];
      cursor += 1;
      try {
        await getImageResource(source);
      } catch (error) {
        console.warn("forecast image prefetch failed", source, error);
      }
    }
  };

  const workerCount = Math.min(IMAGE_PREFETCH_CONCURRENCY, orderedSources.length);
  void Promise.all(Array.from({ length: workerCount }, () => worker()));
}

function openPersistentImageCache() {
  if (!("caches" in window)) return Promise.resolve(null);
  if (!persistentImageCachePromise) {
    persistentImageCachePromise = window.caches
      .open(IMAGE_CACHE_NAME)
      .catch((error) => {
        console.warn("persistent forecast image cache unavailable", error);
        return null;
      });
  }
  return persistentImageCachePromise;
}

async function prunePersistentImageCache(desiredSources) {
  const cache = await openPersistentImageCache();
  if (!cache) return;
  try {
    const requests = await cache.keys();
    await Promise.all(
      requests
        .filter((request) => !desiredSources.has(request.url))
        .map((request) => cache.delete(request)),
    );
  } catch (error) {
    console.warn("persistent forecast image cache cleanup failed", error);
  }
}

function getImageResource(source) {
  const existing = imageResourceCache.get(source);
  if (existing) return existing.promise;

  const entry = { objectUrl: null, promise: null };
  entry.promise = readForecastImage(source)
    .then((blob) => {
      entry.objectUrl = URL.createObjectURL(blob);
      return entry.objectUrl;
    })
    .catch((error) => {
      if (imageResourceCache.get(source) === entry) imageResourceCache.delete(source);
      throw error;
    });
  imageResourceCache.set(source, entry);
  return entry.promise;
}

function invalidateImageResource(source) {
  const entry = imageResourceCache.get(source);
  if (!entry) return;
  if (entry.objectUrl) URL.revokeObjectURL(entry.objectUrl);
  imageResourceCache.delete(source);
}

async function readForecastImage(source) {
  const persistentCache = await openPersistentImageCache();
  if (persistentCache) {
    try {
      const cachedResponse = await persistentCache.match(source);
      if (cachedResponse) return cachedResponse.blob();
    } catch (error) {
      await persistentCache.delete(source).catch(() => {});
      console.warn("persistent forecast image cache read failed", source, error);
    }
  }

  let response = null;
  let lastError = null;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const requestUrl = attempt > 0 ? withRetryVersion(source, attempt) : source;
    try {
      response = await fetch(requestUrl, {
        cache: attempt > 0 ? "no-store" : "force-cache",
      });
      if (response.ok) break;
      lastError = new Error(`${requestUrl} ${response.status}`);
    } catch (error) {
      lastError = error;
    }
  }
  if (!response?.ok) throw lastError || new Error(`image request failed: ${source}`);

  const cacheResponse = persistentCache ? response.clone() : null;
  const blob = await response.blob();
  if (persistentCache && cacheResponse) {
    persistentCache.put(source, cacheResponse).catch((error) => {
      console.warn("persistent forecast image cache write failed", source, error);
    });
  }
  return blob;
}

function stepLead(delta) {
  const frames = currentProduct()?.frames || [];
  if (!frames.length) return;
  state.leadIndex = (state.leadIndex + delta + frames.length) % frames.length;
  render();
}

function withCacheBuster(url) {
  const separator = url.includes("?") ? "&" : "?";
  return `${url}${separator}v=${Date.now()}`;
}

function resolveAssetPath(file) {
  if (!file) return "";
  if (/^(https?:)?\/\//.test(file) || file.startsWith("/")) return file;
  const cleanFile = file.replace(/^\.?\//, "");
  const cleanBase = pageConfig.assetBase.endsWith("/")
    ? pageConfig.assetBase
    : `${pageConfig.assetBase}/`;
  return `${cleanBase}${cleanFile}`;
}

function withAssetVersion(url, version) {
  if (!url || url.startsWith("data:")) return url;
  const separator = url.includes("?") ? "&" : "?";
  return `${url}${separator}v=${encodeURIComponent(version || Date.now())}`;
}

function loadForecastImage(source, alt) {
  const image = els.forecastImage;
  if (!image || !source) return;
  image.alt = alt;

  if (
    state.imageSource === source &&
    (state.imageStatus === "loading" || state.imageStatus === "ready")
  ) {
    return;
  }

  state.imageRequestId += 1;
  const requestId = state.imageRequestId;
  state.imageSource = source;
  state.imageStatus = "loading";
  setImageState("loading");
  image.removeAttribute("src");

  resolveForecastImage({ source, requestId, attempt: 0 });
}

async function resolveForecastImage({ source, requestId, attempt }) {
  try {
    const objectUrl = await getImageResource(source);
    if (requestId !== state.imageRequestId) return;

    els.forecastImage.onload = () => {
      if (requestId !== state.imageRequestId) return;
      state.imageStatus = "ready";
      setImageState("ready");
    };
    els.forecastImage.onerror = () => {
      if (requestId !== state.imageRequestId) return;
      invalidateImageResource(source);
      retryForecastImage({ source, requestId, attempt });
    };
    els.forecastImage.src = objectUrl;
  } catch (error) {
    if (requestId !== state.imageRequestId) return;
    console.warn("forecast image request failed", error);
    retryForecastImage({ source, requestId, attempt });
  }
}

function retryForecastImage({ source, requestId, attempt }) {
  if (attempt < 1) {
    window.setTimeout(() => {
      if (requestId !== state.imageRequestId) return;
      resolveForecastImage({ source, requestId, attempt: attempt + 1 });
    }, 350);
    return;
  }

  state.imageStatus = "error";
  state.imageSource = null;
  setImageState("error");
}

function withRetryVersion(url, attempt) {
  const separator = url.includes("?") ? "&" : "?";
  return `${url}${separator}retry=${Date.now()}-${attempt}`;
}

function setImageState(status) {
  if (els.mapStage) els.mapStage.dataset.imageState = status;
  if (els.forecastImage) {
    els.forecastImage.setAttribute("aria-busy", String(status === "loading"));
  }
}

function frameId(frame) {
  if (!frame) return undefined;
  return frame.id || frame.file || frame.lead_label;
}

function setText(element, text) {
  if (element) element.textContent = text;
}

function showError(error) {
  setText(els.updateLabel, "数据读取失败");
  setText(els.productTitle, "无法读取预报清单");
  setText(els.runSummary, "无法读取时次清单");
  console.error(error);
}

function setRefreshState(isLoading) {
  if (!els.refreshCatalog) return;
  els.refreshCatalog.disabled = isLoading;
  els.refreshCatalog.classList.toggle("is-loading", isLoading);
}

function formatRunSummary(runs) {
  if (!runs.length) return "暂无起报时次";
  const latest = runs.find((run) => run.id === state.service?.latest_run) || runs[0];
  const parts = formatRunParts(latest);
  return `已接入 ${runs.length} 个起报时次 · 最新 ${parts.date} ${parts.time} ${parts.zone}`.trim();
}

function formatRunParts(run) {
  const label = String(run?.label || "");
  const labelMatch = label.match(/(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})/);
  if (labelMatch) {
    return { date: labelMatch[1], time: labelMatch[2], zone: "BJT" };
  }

  const date = new Date(run?.run_time || "");
  if (!Number.isNaN(date.getTime())) {
    const datePart = new Intl.DateTimeFormat("zh-CN", {
      timeZone: "Asia/Shanghai",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    })
      .format(date)
      .replace(/\//g, "-");
    const timePart = new Intl.DateTimeFormat("zh-CN", {
      timeZone: "Asia/Shanghai",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).format(date);
    return { date: datePart, time: timePart, zone: "BJT" };
  }

  return { date: label || String(run?.id || "--"), time: "--", zone: "" };
}

function setupImageViewer() {
  if (viewerState.root) return;

  const root = document.createElement("div");
  root.id = "imageViewer";
  root.className = "image-viewer";
  root.hidden = true;
  root.setAttribute("role", "dialog");
  root.setAttribute("aria-modal", "true");
  root.setAttribute("aria-labelledby", "imageViewerTitle");
  root.innerHTML = `
    <div class="viewer-toolbar">
      <div class="viewer-heading">
        <strong id="imageViewerTitle">预报图</strong>
        <span id="imageViewerMeta"></span>
      </div>
      <div class="viewer-actions">
        <button class="viewer-icon-button" type="button" data-viewer-action="zoom-out" title="缩小" aria-label="缩小">&#8722;</button>
        <output class="viewer-zoom" aria-live="polite">100%</output>
        <button class="viewer-icon-button" type="button" data-viewer-action="zoom-in" title="放大" aria-label="放大">+</button>
        <button class="viewer-icon-button" type="button" data-viewer-action="reset" title="复位" aria-label="复位">&#8634;</button>
        <button class="viewer-icon-button viewer-close" type="button" data-viewer-action="close" title="关闭" aria-label="关闭">&times;</button>
      </div>
    </div>
    <div class="viewer-stage" tabindex="0">
      <div class="viewer-frame-nav" aria-label="服务图像切换">
        <button class="viewer-icon-button" type="button" data-viewer-action="previous-frame" title="上一张" aria-label="上一张">&#8249;</button>
        <button class="viewer-icon-button" type="button" data-viewer-action="next-frame" title="下一张" aria-label="下一张">&#8250;</button>
      </div>
      <img class="viewer-image" alt="" draggable="false" />
    </div>
  `;
  document.body.appendChild(root);

  viewerState.root = root;
  viewerState.stage = root.querySelector(".viewer-stage");
  viewerState.image = root.querySelector(".viewer-image");
  viewerState.title = root.querySelector("#imageViewerTitle");
  viewerState.meta = root.querySelector("#imageViewerMeta");
  viewerState.zoomLabel = root.querySelector(".viewer-zoom");

  root.addEventListener("click", handleViewerAction);
  root.querySelector(".viewer-frame-nav")?.addEventListener("pointerdown", (event) => {
    event.stopPropagation();
  });
  root.querySelector(".viewer-frame-nav")?.addEventListener("pointerup", (event) => {
    event.stopPropagation();
  });
  viewerState.stage.addEventListener("wheel", handleViewerWheel, { passive: false });
  viewerState.stage.addEventListener("pointerdown", handleViewerPointerDown);
  viewerState.stage.addEventListener("pointermove", handleViewerPointerMove);
  viewerState.stage.addEventListener("pointerup", handleViewerPointerEnd);
  viewerState.stage.addEventListener("pointercancel", handleViewerPointerEnd);
  document.addEventListener("keydown", handleViewerKeydown);
  window.addEventListener("resize", applyViewerTransform);

  els.forecastImage?.addEventListener("click", () => openImageViewer(els.forecastImage));
  els.forecastImage?.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    event.preventDefault();
    openImageViewer(els.forecastImage);
  });
  els.imageLink?.addEventListener("click", (event) => {
    event.preventDefault();
    openImageViewer(els.imageLink);
  });
}

function viewerEntries() {
  const entries = [];
  const runs = state.service?.runs || [];
  for (let runIndex = runs.length - 1; runIndex >= 0; runIndex -= 1) {
    const run = runs[runIndex];
    for (let productIndex = 0; productIndex < (run.products || []).length; productIndex += 1) {
      const product = run.products[productIndex];
      for (let leadIndex = 0; leadIndex < (product.frames || []).length; leadIndex += 1) {
        const frame = product.frames[leadIndex];
        entries.push({
          runIndex,
          productIndex,
          leadIndex,
          run,
          product,
          frame,
          source: forecastFrameSource(run, frame),
        });
      }
    }
  }
  return entries;
}

function currentViewerEntryIndex(entries) {
  const index = entries.findIndex(
    (entry) =>
      entry.runIndex === state.runIndex &&
      entry.productIndex === state.productIndex &&
      entry.leadIndex === state.leadIndex,
  );
  return index >= 0 ? index : 0;
}

function updateViewerControls() {
  if (!viewerState.root) return;
  const entries = viewerEntries();
  const hasMultipleFrames = entries.length > 1;
  viewerState.root
    .querySelector('[data-viewer-action="previous-frame"]')
    ?.toggleAttribute("disabled", !hasMultipleFrames);
  viewerState.root
    .querySelector('[data-viewer-action="next-frame"]')
    ?.toggleAttribute("disabled", !hasMultipleFrames);
}

function stepViewerFrame(delta) {
  const entries = viewerEntries();
  if (entries.length <= 1) return;
  const currentIndex = currentViewerEntryIndex(entries);
  const nextIndex = (currentIndex + delta + entries.length) % entries.length;
  const next = entries[nextIndex];
  state.runIndex = next.runIndex;
  state.productIndex = next.productIndex;
  state.leadIndex = next.leadIndex;
  state.hasNewLatestRun = false;
  render();
}

function syncViewerFrame(source, alt, { reset = false } = {}) {
  if (!viewerState.root || viewerState.root.hidden || !source) return;

  const run = currentRun();
  const product = currentProduct();
  const frame = currentFrame();
  const entries = viewerEntries();
  const position = entries.length ? `${currentViewerEntryIndex(entries) + 1}/${entries.length}` : "--";
  viewerState.title.textContent = product?.title || "预报图";
  viewerState.meta.textContent = [run?.label, position, displayFrameLabel(frame), frame?.valid_label]
    .filter(Boolean)
    .join(" · ");
  updateViewerControls();

  if (viewerState.source === source && (viewerState.loading || viewerState.image.src)) {
    if (reset) resetViewer();
    return;
  }

  viewerState.source = source;
  viewerState.requestId += 1;
  const requestId = viewerState.requestId;
  viewerState.loading = true;
  viewerState.resetOnImageLoad = reset;
  viewerState.image.alt = alt;
  if (reset) resetViewer();

  getImageResource(source)
    .then((objectUrl) => {
      if (requestId !== viewerState.requestId) return;
      viewerState.image.onload = () => {
        if (requestId !== viewerState.requestId) return;
        viewerState.loading = false;
        if (viewerState.resetOnImageLoad) {
          viewerState.resetOnImageLoad = false;
          resetViewer();
        } else {
          applyViewerTransform();
        }
      };
      viewerState.image.onerror = () => {
        if (requestId !== viewerState.requestId) return;
        viewerState.loading = false;
        invalidateImageResource(source);
      };
      viewerState.image.src = objectUrl;
    })
    .catch((error) => {
      if (requestId !== viewerState.requestId) return;
      viewerState.loading = false;
      console.warn("viewer image request failed", error);
    });
}

function openImageViewer(opener) {
  const frame = currentFrame();
  const product = currentProduct();
  const run = currentRun();
  if (!viewerState.root || !frame || !product) return;

  viewerState.opener = opener;
  viewerState.root.hidden = false;
  document.body.classList.add("viewer-open");
  syncViewerFrame(
    forecastFrameSource(run, frame),
    `${product.title} ${frame.lead_label || ""}`.trim(),
    { reset: true },
  );
  window.requestAnimationFrame(() => {
    viewerState.root.querySelector('[data-viewer-action="close"]')?.focus();
  });
}

function closeImageViewer() {
  if (!viewerState.root || viewerState.root.hidden) return;
  viewerState.root.hidden = true;
  viewerState.pointers.clear();
  viewerState.gesture = null;
  document.body.classList.remove("viewer-open");
  if (viewerState.opener?.isConnected) viewerState.opener.focus();
}

function handleViewerAction(event) {
  const button = event.target.closest("[data-viewer-action]");
  if (!button) return;
  const action = button.dataset.viewerAction;
  if (action === "close") closeImageViewer();
  if (action === "previous-frame") stepViewerFrame(-1);
  if (action === "next-frame") stepViewerFrame(1);
  if (action === "reset") resetViewer();
  if (action === "zoom-in") zoomViewer(viewerState.scale * VIEWER_ZOOM_STEP);
  if (action === "zoom-out") zoomViewer(viewerState.scale / VIEWER_ZOOM_STEP);
}

function handleViewerWheel(event) {
  event.preventDefault();
  const factor = Math.exp(-event.deltaY * 0.0015);
  zoomViewer(viewerState.scale * factor, event.clientX, event.clientY);
}

function handleViewerPointerDown(event) {
  if (event.pointerType === "mouse" && event.button !== 0) return;
  event.preventDefault();
  viewerState.stage.setPointerCapture(event.pointerId);
  viewerState.pointers.set(event.pointerId, {
    id: event.pointerId,
    x: event.clientX,
    y: event.clientY,
  });

  if (viewerState.pointers.size >= 2) {
    viewerState.gesture = createPinchGesture();
    return;
  }

  viewerState.gesture = {
    type: "drag",
    pointerId: event.pointerId,
    startX: event.clientX,
    startY: event.clientY,
    originX: viewerState.x,
    originY: viewerState.y,
    moved: false,
  };
}

function handleViewerPointerMove(event) {
  if (!viewerState.pointers.has(event.pointerId)) return;
  event.preventDefault();
  viewerState.pointers.set(event.pointerId, {
    id: event.pointerId,
    x: event.clientX,
    y: event.clientY,
  });

  if (viewerState.pointers.size >= 2) {
    if (viewerState.gesture?.type !== "pinch") viewerState.gesture = createPinchGesture();
    updatePinchGesture();
    return;
  }

  const gesture = viewerState.gesture;
  if (gesture?.type !== "drag" || gesture.pointerId !== event.pointerId) return;
  const dx = event.clientX - gesture.startX;
  const dy = event.clientY - gesture.startY;
  gesture.moved = gesture.moved || Math.hypot(dx, dy) > 5;
  viewerState.x = gesture.originX + dx;
  viewerState.y = gesture.originY + dy;
  applyViewerTransform();
}

function handleViewerPointerEnd(event) {
  if (!viewerState.pointers.has(event.pointerId)) return;
  const gesture = viewerState.gesture;
  const swipeX = gesture ? event.clientX - gesture.startX : 0;
  const swipeY = gesture ? event.clientY - gesture.startY : 0;
  const isTouchSwipe =
    event.pointerType === "touch" &&
    viewerState.pointers.size === 1 &&
    gesture?.type === "drag" &&
    viewerState.scale <= 1.05 &&
    Math.abs(swipeX) > 56 &&
    Math.abs(swipeX) > Math.abs(swipeY) * 1.2;

  viewerState.pointers.delete(event.pointerId);
  if (viewerState.pointers.size >= 2) {
    viewerState.gesture = createPinchGesture();
  } else if (viewerState.pointers.size === 1) {
    const remaining = [...viewerState.pointers.values()][0];
    viewerState.gesture = {
      type: "drag",
      pointerId: remaining.id,
      startX: remaining.x,
      startY: remaining.y,
      originX: viewerState.x,
      originY: viewerState.y,
      moved: false,
    };
  } else {
    viewerState.gesture = null;
  }

  if (isTouchSwipe) {
    stepViewerFrame(swipeX < 0 ? 1 : -1);
  }
}

function createPinchGesture() {
  const [first, second] = [...viewerState.pointers.values()].slice(0, 2);
  const center = midpoint(first, second);
  return {
    type: "pinch",
    distance: Math.max(1, distance(first, second)),
    center,
    startScale: viewerState.scale,
    startX: viewerState.x,
    startY: viewerState.y,
  };
}

function updatePinchGesture() {
  const gesture = viewerState.gesture;
  const [first, second] = [...viewerState.pointers.values()].slice(0, 2);
  if (!gesture || !first || !second) return;

  const currentCenter = midpoint(first, second);
  const nextScale = clamp(
    gesture.startScale * (distance(first, second) / gesture.distance),
    1,
    MAX_VIEWER_SCALE,
  );
  const startPoint = viewerPoint(gesture.center.x, gesture.center.y);
  const currentPoint = viewerPoint(currentCenter.x, currentCenter.y);
  const ratio = nextScale / gesture.startScale;
  viewerState.scale = nextScale;
  viewerState.x = currentPoint.x - (startPoint.x - gesture.startX) * ratio;
  viewerState.y = currentPoint.y - (startPoint.y - gesture.startY) * ratio;
  applyViewerTransform();
}

function zoomViewer(nextScale, clientX, clientY) {
  const oldScale = viewerState.scale;
  const scale = clamp(nextScale, 1, MAX_VIEWER_SCALE);
  const point = Number.isFinite(clientX) && Number.isFinite(clientY)
    ? viewerPoint(clientX, clientY)
    : { x: 0, y: 0 };
  const ratio = scale / oldScale;
  viewerState.x = point.x - (point.x - viewerState.x) * ratio;
  viewerState.y = point.y - (point.y - viewerState.y) * ratio;
  viewerState.scale = scale;
  if (scale === 1) {
    viewerState.x = 0;
    viewerState.y = 0;
  }
  applyViewerTransform();
}

function resetViewer() {
  viewerState.scale = 1;
  viewerState.x = 0;
  viewerState.y = 0;
  applyViewerTransform();
}

function applyViewerTransform() {
  if (!viewerState.image || !viewerState.stage) return;
  clampViewerTranslation();
  viewerState.image.style.transform =
    `translate3d(${viewerState.x}px, ${viewerState.y}px, 0) scale(${viewerState.scale})`;
  if (viewerState.zoomLabel) {
    viewerState.zoomLabel.textContent = `${Math.round(viewerState.scale * 100)}%`;
  }
  viewerState.stage.classList.toggle("is-zoomed", viewerState.scale > 1.01);
}

function clampViewerTranslation() {
  const imageWidth = viewerState.image.offsetWidth * viewerState.scale;
  const imageHeight = viewerState.image.offsetHeight * viewerState.scale;
  const maxX = Math.max(0, (imageWidth - viewerState.stage.clientWidth) / 2);
  const maxY = Math.max(0, (imageHeight - viewerState.stage.clientHeight) / 2);
  viewerState.x = clamp(viewerState.x, -maxX, maxX);
  viewerState.y = clamp(viewerState.y, -maxY, maxY);
}

function viewerPoint(clientX, clientY) {
  const rect = viewerState.stage.getBoundingClientRect();
  return {
    x: clientX - (rect.left + rect.width / 2),
    y: clientY - (rect.top + rect.height / 2),
  };
}

function handleViewerKeydown(event) {
  if (!viewerState.root || viewerState.root.hidden) return;
  if (event.key === "Escape") {
    event.preventDefault();
    closeImageViewer();
    return;
  }
  if (event.key === "+" || event.key === "=") zoomViewer(viewerState.scale * VIEWER_ZOOM_STEP);
  if (event.key === "-") zoomViewer(viewerState.scale / VIEWER_ZOOM_STEP);
  if (event.key === "0") resetViewer();
  if (event.key === "ArrowLeft") {
    event.preventDefault();
    stepViewerFrame(-1);
    return;
  }
  if (event.key === "ArrowRight") {
    event.preventDefault();
    stepViewerFrame(1);
    return;
  }
  if (event.key.startsWith("Arrow")) {
    event.preventDefault();
    const amount = 48;
    if (event.key === "ArrowLeft") viewerState.x += amount;
    if (event.key === "ArrowRight") viewerState.x -= amount;
    if (event.key === "ArrowUp") viewerState.y += amount;
    if (event.key === "ArrowDown") viewerState.y -= amount;
    applyViewerTransform();
  }
}

function midpoint(first, second) {
  return { x: (first.x + second.x) / 2, y: (first.y + second.y) / 2 };
}

function distance(first, second) {
  return Math.hypot(second.x - first.x, second.y - first.y);
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function formatTime(value) {
  if (!value) return "--";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat("zh-CN", {
    timeZone: "Asia/Shanghai",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

els.prevLead?.addEventListener("click", () => stepLead(-1));
els.nextLead?.addEventListener("click", () => stepLead(1));
els.refreshCatalog?.addEventListener("click", () =>
  loadForecast({ preserveSelection: true }),
);
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && state.catalog) {
    loadForecast({ preserveSelection: true });
  }
});
window.addEventListener("pagehide", (event) => {
  if (event.persisted) return;
  for (const entry of imageResourceCache.values()) {
    if (entry.objectUrl) URL.revokeObjectURL(entry.objectUrl);
  }
  imageResourceCache.clear();
});

if (ensureAccess()) init();

function ensureAccess() {
  if (hasAccessToken()) {
    unlockPage();
    return true;
  }
  renderAccessGate();
  return false;
}

function hasAccessToken() {
  try {
    return window.localStorage.getItem(ACCESS_TOKEN_KEY) === ACCESS_TOKEN_VALUE;
  } catch (error) {
    console.warn("access token unavailable", error);
    return false;
  }
}

function saveAccessToken() {
  try {
    window.localStorage.setItem(ACCESS_TOKEN_KEY, ACCESS_TOKEN_VALUE);
  } catch (error) {
    console.warn("access token could not be saved", error);
  }
}

function unlockPage() {
  document.body.classList.remove("auth-lock");
  document.querySelector("#authGate")?.remove();
}

function renderAccessGate() {
  const gate = document.createElement("div");
  gate.id = "authGate";
  gate.className = "auth-gate";
  gate.innerHTML = `
    <form class="auth-card" autocomplete="off">
      <div>
        <p class="eyebrow">Access</p>
        <h2>访问验证</h2>
        <p class="auth-copy">请输入访问密码继续查看 IAP-LACS 预报服务。</p>
      </div>
      <label class="auth-field">
        <span>密码</span>
        <input id="accessPassword" type="password" inputmode="numeric" autocomplete="current-password" autofocus />
      </label>
      <p id="authError" class="auth-error" aria-live="polite"></p>
      <button class="auth-submit" type="submit">进入网站</button>
    </form>
  `;

  gate.querySelector("form").addEventListener("submit", (event) => {
    event.preventDefault();
    const input = gate.querySelector("#accessPassword");
    const error = gate.querySelector("#authError");
    if (input.value === ACCESS_PASSWORD) {
      saveAccessToken();
      unlockPage();
      init();
      return;
    }
    error.textContent = "密码不正确";
    input.value = "";
    input.focus();
  });

  document.body.appendChild(gate);
  window.setTimeout(() => gate.querySelector("#accessPassword")?.focus(), 0);
}
