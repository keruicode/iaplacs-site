const DEFAULT_REFRESH_MS = 2 * 60 * 1000;
const MAX_DISPLAY_RUNS = 5;
const MAX_VIEWER_SCALE = 6;
const VIEWER_ZOOM_STEP = 1.25;
const IMAGE_PREFETCH_CONCURRENCY = 1;
const IMAGE_PREFETCH_IDLE_TIMEOUT_MS = 3000;
const ACCESS_PASSWORD = "123";
const ACCESS_TOKEN_KEY = "iaplacs_access_token";
const ACCESS_TOKEN_VALUE = "iaplacs_access_granted_v1";
const DATA_SOURCE_TOKEN_KEY = "iaplacs_forecast_source";
const AIRPORT_RATING_CLIENT_ID_KEY = "iaplacs_airport_rating_client_v1";
const NINGXIA_PRODUCT_TITLE = "降水预报图集";
const NINGXIA_PRODUCT_DESCRIPTION = "默认显示宁夏区域图，可切换 WORK_nx 全国模拟图。";
const NATIONAL_FRAME_LABELS = {
  worknx_national: "中国中部",
  shangrao_national: "中国东南部",
  airport_national: "中国西南部",
};
const AIRPORT_RATING_TARGETS = [
  { id: "dehong_mangshi", label: "德宏芒市机场" },
  { id: "xishuangbanna_gasa", label: "西双版纳嘎洒机场" },
  { id: "puer_lancang_jingmai", label: "普洱澜沧景迈机场" },
];
const AIRPORT_RATING_OPTIONS = [
  { id: "accurate", label: "准" },
  { id: "inaccurate", label: "不准" },
  { id: "fair", label: "一般" },
];

const pageConfig = {
  service: document.body.dataset.service || "airport",
  manifestUrl: document.body.dataset.manifestUrl || "./data/current/forecast-runs.json",
  fallbackManifestUrl:
    document.body.dataset.fallbackManifestUrl || "./data/current/manifest.json",
  assetBase: document.body.dataset.assetBase || "./",
  refreshMs: Number(document.body.dataset.refreshMs || DEFAULT_REFRESH_MS),
  sources: [
    {
      id: "huan",
      label: "寰",
      manifestUrl:
        document.body.dataset.huanManifestUrl ||
        document.body.dataset.manifestUrl ||
        "./data/current/forecast-runs.json",
      fallbackManifestUrl:
        document.body.dataset.huanFallbackManifestUrl ||
        document.body.dataset.fallbackManifestUrl ||
        "./data/current/manifest.json",
    },
    {
      id: "tianhe",
      label: "天河",
      manifestUrl:
        document.body.dataset.tianheManifestUrl ||
        "./data/tianhe/current/forecast-runs.json",
      fallbackManifestUrl:
        document.body.dataset.tianheFallbackManifestUrl ||
        "./data/tianhe/current/manifest.json",
    },
  ],
  defaultSource: document.body.dataset.defaultSource || "huan",
  forceDefaultSource: document.body.dataset.forceDefaultSource === "true",
  autoSelectLatestSource: document.body.dataset.autoSelectLatestSource === "true",
  airportRatingsApiUrl: document.body.dataset.airportRatingsApiUrl || "",
};

const state = {
  catalog: null,
  service: null,
  runIndex: 0,
  productIndex: 0,
  leadIndex: 0,
  airportPanelIndex: 0,
  airportViewMode: "hourly",
  refreshTimer: null,
  loading: false,
  hasNewLatestRun: false,
  imageRequestId: 0,
  imageSource: null,
  imageStatus: "idle",
  airportRatings: {
    key: "",
    data: null,
    loading: false,
    saving: false,
    error: "",
    requestId: 0,
  },
  prefetchSignature: "",
  prefetchTimer: null,
  prefetchIdleId: null,
  sourceId: initialSourceId(),
};

const els = {
  updateLabel: document.querySelector("#updateLabel"),
  runSummary: document.querySelector("#runSummary"),
  refreshCatalog: document.querySelector("#refreshCatalog"),
  runList: document.querySelector("#runList"),
  productList: document.querySelector("#productList"),
  runTime: document.querySelector("#runTime"),
  publishedAt: document.querySelector("#publishedAt"),
  sourceNote: document.querySelector("#sourceNote"),
  dataSourceSwitch: document.querySelector("#dataSourceSwitch"),
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
  imageDownload: document.querySelector("#imageDownload"),
  airportViewMode: document.querySelector("#airportViewMode"),
  airportHourTimeline: document.querySelector("#airportHourTimeline"),
  metricGrid: document.querySelector("#metricGrid"),
  productNote: document.querySelector("#productNote"),
  airportFeedbackToggle: document.querySelector("#airportFeedbackToggle"),
  airportFeedback: document.querySelector("#airportFeedback"),
  airportRatingList: document.querySelector("#airportRatingList"),
  airportRatingStatus: document.querySelector("#airportRatingStatus"),
};

const viewerState = {
  root: null,
  stage: null,
  image: null,
  title: null,
  meta: null,
  zoomLabel: null,
  scale: 1,
  fitScale: 1,
  x: 0,
  y: 0,
  pointers: new Map(),
  gesture: null,
  opener: null,
  source: null,
  requestId: 0,
  loading: false,
  resetOnImageLoad: false,
  downloadLink: null,
  downloadSource: null,
  downloadName: "iaplacs-forecast.png",
};

async function init() {
  setupImageViewer();
  setupDataSourceSwitch();
  setupAirportViewMode();
  setupAirportFeedback();
  await selectLatestSource();
  await loadForecast({ preserveSelection: false });
  if (pageConfig.refreshMs > 0) {
    state.refreshTimer = window.setInterval(
      () => loadForecast({ preserveSelection: true }),
      pageConfig.refreshMs,
    );
  }
}

async function selectLatestSource() {
  if (!pageConfig.autoSelectLatestSource) return;

  const candidates = await Promise.all(
    pageConfig.sources.map(async (source) => {
      try {
        const raw = await fetchForecastDataForSource(source);
        const catalog = normalizeForecastData(raw);
        const service = selectService(catalog);
        const latestRun =
          service?.runs?.find((run) => run.id === service.latest_run) || service?.runs?.[0];
        if (!serviceHasRenderableFrames(service) || !latestRun) return null;

        const runTime = Date.parse(latestRun.run_time || "");
        const publishedTime = Date.parse(catalog.published_at || "");
        return {
          id: source.id,
          time: Number.isFinite(runTime)
            ? runTime
            : Number.isFinite(publishedTime)
              ? publishedTime
              : 0,
        };
      } catch (error) {
        console.warn(`latest source check failed: ${source.manifestUrl}`, error);
        return null;
      }
    }),
  );

  const latest = candidates
    .filter(Boolean)
    .sort((a, b) => b.time - a.time)[0];
  if (latest) state.sourceId = latest.id;
}

async function loadForecast({ preserveSelection }) {
  if (state.loading) return;
  state.loading = true;
  setRefreshState(true);
  const previous = preserveSelection ? currentSelection() : {};
  const previousLatestRunId = preserveSelection ? state.service?.latest_run : undefined;

  try {
    let raw = await fetchForecastData();
    let catalog = normalizeForecastData(raw);
    if (state.sourceId === "huan") {
      catalog = await addHuanNationalFallback(catalog);
    }
    let service = selectService(catalog);

    // Shangrao has no Tianhe product yet. Keep the page useful when a browser
    // remembers Tianhe from another service by using the available Huan data.
    if (!serviceHasRenderableFrames(service)) {
      const fallbackSource = pageConfig.sources.find(
        (source) => source.id !== state.sourceId,
      );
      if (fallbackSource) {
        try {
          raw = await fetchForecastDataForSource(fallbackSource);
          const fallbackCatalog = normalizeForecastData(raw);
          const fallbackService = selectService(fallbackCatalog);
          if (serviceHasRenderableFrames(fallbackService)) {
            catalog = fallbackCatalog;
            service = fallbackService;
            state.sourceId = fallbackSource.id;
            renderDataSourceSwitch();
          }
        } catch (error) {
          console.warn(`forecast fallback failed: ${fallbackSource.manifestUrl}`, error);
        }
      }
    }

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

async function addHuanNationalFallback(catalog) {
  const frameIds = nationalFrameIds();
  if (!frameIds) return catalog;

  const service = selectService(catalog);
  const latestRun =
    service?.runs?.find((run) => run.id === service.latest_run) || service?.runs?.[0];
  if (!latestRun || findFrame(latestRun, frameIds.national)) return catalog;

  const tianheSource = pageConfig.sources.find((source) => source.id === "tianhe");
  if (!tianheSource) return catalog;

  try {
    const tianheCatalog = normalizeForecastData(
      await fetchForecastDataForSource(tianheSource),
    );
    const tianheService = selectService(tianheCatalog);
    const tianheRun =
      tianheService?.runs?.find((run) => run.id === tianheService.latest_run) ||
      tianheService?.runs?.[0];
    const currentRunTime = Date.parse(latestRun.run_time || "");
    const fallbackRunTime = Date.parse(tianheRun?.run_time || "");
    if (
      !tianheRun ||
      (Number.isFinite(currentRunTime) &&
        (!Number.isFinite(fallbackRunTime) || fallbackRunTime < currentRunTime))
    ) {
      return catalog;
    }
    const nationalFrame = findFrame(tianheRun, frameIds.national);
    if (!nationalFrame) return catalog;

    return limitCatalogRuns(
      addNationalFallbackToLatestRun(catalog, frameIds, nationalFrame),
    );
  } catch (error) {
    console.warn("Huan national fallback unavailable", error);
    return catalog;
  }
}

function nationalFrameIds() {
  const ids = {
    ningxia: { region: "ningxia_region", national: "worknx_national" },
    airport: { region: "airport_region", national: "airport_national" },
    shangrao: { region: "shangrao_region", national: "shangrao_national" },
  };
  return ids[pageConfig.service] || null;
}

function findFrame(run, frameId) {
  return run?.products
    ?.flatMap((product) => product.frames || [])
    .find((frame) => frame?.id === frameId);
}

function addNationalFallbackToLatestRun(catalog, frameIds, nationalFrame) {
  const serviceKey = catalog.services?.[pageConfig.service]
    ? pageConfig.service
    : pageConfig.service === "airport" && catalog.services?.main
      ? "main"
      : null;
  if (!serviceKey) return catalog;

  const service = catalog.services[serviceKey];
  const runs = (service.runs || []).map((run) => {
    if (run.id !== service.latest_run) return run;
    const products = (run.products || []).map((product) => {
      if (!isHourlyPrecipitationProduct(product)) return product;
      const frames = normalizeFallbackRegionFrame(product.frames || [], frameIds);
      if (frames.some((frame) => frame.id === frameIds.national)) return product;
      return {
        ...product,
        metrics: updateFrameCountMetric(product.metrics || [], frames.length + 1),
        frames: [
          ...frames,
          {
            ...nationalFrame,
            id: frameIds.national,
            lead: 1,
            lead_label: NATIONAL_FRAME_LABELS[frameIds.national],
            fallback_source: "tianhe",
          },
        ],
      };
    });
    return { ...run, products };
  });

  return {
    ...catalog,
    services: {
      ...catalog.services,
      [serviceKey]: { ...service, runs },
    },
  };
}

function isHourlyPrecipitationProduct(product) {
  return new Set([
    "airport_yunnan_precip_series",
    "ningxia_precip_series",
    "wrf_rain_montage",
  ]).has(product?.id);
}

function normalizeFallbackRegionFrame(frames, frameIds) {
  if (frames.some((frame) => frame.id === frameIds.region)) return frames;
  const overview = frames.find((frame) => /overview|总览|yunnanairports/i.test(
    `${frame?.id || ""} ${frame?.lead_label || ""} ${frame?.file || ""}`,
  ));
  if (!overview) return frames;
  return frames.map((frame) =>
    frame === overview
      ? { ...frame, id: frameIds.region, lead: 0, lead_label: "区域" }
      : frame,
  );
}

async function fetchForecastData() {
  return fetchForecastDataForSource(activeDataSource());
}

async function fetchForecastDataForSource(source) {
  try {
    return await fetchJson(withCacheBuster(source.manifestUrl));
  } catch (error) {
    console.warn(`primary forecast catalog failed: ${source.manifestUrl}`, error);
    return fetchJson(withCacheBuster(source.fallbackManifestUrl));
  }
}

function serviceHasRenderableFrames(service) {
  return Boolean(
    service?.runs?.some((run) =>
      run?.products?.some((product) =>
        product?.frames?.some((frame) => frame?.file || frame?.preview_file),
      ),
    ),
  );
}

function initialSourceId() {
  if (pageConfig.forceDefaultSource) return pageConfig.defaultSource;
  const preferred = readSavedSourceId();
  return pageConfig.sources.some((source) => source.id === preferred)
    ? preferred
    : pageConfig.defaultSource;
}

function readSavedSourceId() {
  try {
    return window.localStorage.getItem(DATA_SOURCE_TOKEN_KEY);
  } catch (error) {
    console.warn("forecast source preference unavailable", error);
    return null;
  }
}

function activeDataSource() {
  return (
    pageConfig.sources.find((source) => source.id === state.sourceId) ||
    pageConfig.sources[0]
  );
}

function setupDataSourceSwitch() {
  const root = els.dataSourceSwitch;
  if (!root) return;

  root.addEventListener("click", (event) => {
    const button = event.target.closest("[data-source-id]");
    const sourceId = button?.dataset.sourceId;
    if (!sourceId || sourceId === state.sourceId || state.loading) return;
    if (!pageConfig.sources.some((source) => source.id === sourceId)) return;

    closeImageViewer();
    state.sourceId = sourceId;
    state.catalog = null;
    state.service = null;
    state.prefetchSignature = "";
    saveSourceId(sourceId);
    renderDataSourceSwitch();
    loadForecast({ preserveSelection: false });
  });

  renderDataSourceSwitch();
}

function saveSourceId(sourceId) {
  try {
    window.localStorage.setItem(DATA_SOURCE_TOKEN_KEY, sourceId);
  } catch (error) {
    console.warn("forecast source preference could not be saved", error);
  }
}

function renderDataSourceSwitch() {
  const root = els.dataSourceSwitch;
  if (!root) return;

  root.querySelectorAll("[data-source-id]").forEach((button) => {
    const isActive = button.dataset.sourceId === state.sourceId;
    button.classList.toggle("is-active", isActive);
    button.classList.toggle("primary", isActive);
    button.setAttribute("aria-pressed", String(isActive));
    button.disabled = state.loading;
  });
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
          : key === "ningxia"
            ? sourceRuns.map(normalizeNingxiaRun).slice(0, MAX_DISPLAY_RUNS)
          : sourceRuns.slice(0, MAX_DISPLAY_RUNS);
      const latestRunId = runs.some((run) => run.id === service?.latest_run)
        ? service.latest_run
        : runs[0]?.id || null;
      return [key, { ...service, latest_run: latestRunId, runs }];
    }),
  );
  return { ...catalog, services };
}

function normalizeNingxiaRun(run) {
  return {
    ...run,
    products: (run.products || []).map((product) => {
      if (product.id !== "ningxia_precip_series") return product;
      const frames = normalizeNingxiaFrames(product.frames || []);
      return {
        ...product,
        title: NINGXIA_PRODUCT_TITLE,
        description: NINGXIA_PRODUCT_DESCRIPTION,
        metrics: updateFrameCountMetric(product.metrics || [], frames.length),
        frames,
      };
    }),
  };
}

function normalizeNingxiaFrames(frames) {
  return frames
    .map((frame) => {
      const source = [frame.file, frame.preview_file, frame.full_file]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      if (source.includes("_wrf_allrain_")) {
        return {
          ...frame,
          id: "worknx_national",
          lead: 1,
          lead_label: "中国中部",
          valid_label: "当前显示：中国中部",
        };
      }
      if (source.includes("_wrf_ningxia_")) {
        return {
          ...frame,
          id: "ningxia_region",
          lead: 0,
          lead_label: "宁夏区域",
          valid_label: "当前显示：宁夏区域",
        };
      }
      return frame;
    })
    .sort((a, b) => Number(a.lead || 0) - Number(b.lead || 0));
}

function normalizeShangraoRuns(sourceRuns) {
  return sourceRuns.map(normalizeShangraoRun).slice(0, MAX_DISPLAY_RUNS).sort((a, b) => {
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
  const explicitRegionNational = frames.filter((frame) =>
    ["shangrao_region", "shangrao_national"].includes(frame?.id),
  );
  if (explicitRegionNational.length) {
    return explicitRegionNational
      .map((frame) => ({ ...frame, valid_label: "" }))
      .sort((a, b) => Number(a.lead || 0) - Number(b.lead || 0));
  }

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
    year: bjtDate.getUTCFullYear(),
    month: bjtDate.getUTCMonth() + 1,
    day: bjtDate.getUTCDate(),
    hour: bjtDate.getUTCHours(),
  };
}

function twoDigits(value) {
  return String(value).padStart(2, "0");
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
  if (product?.id === "cma_observed_precip_24h") {
    return defaultLeadIndex(product);
  }
  const found = frames.findIndex((frame) => frameId(frame) === previousFrameId);
  return found >= 0 ? found : defaultLeadIndex(product);
}

function defaultLeadIndex(product) {
  const frames = product?.frames || [];
  return product?.id === "cma_observed_precip_24h"
    ? Math.max(0, frames.length - 1)
    : 0;
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
  const selectedFrame = currentFrame();

  reconcileAirportViewMode(product, selectedFrame);
  const frame = currentDisplayFrame();

  if (!state.catalog || !state.service || !run || !product || !selectedFrame || !frame) {
    renderEmpty();
    return;
  }

  document.title = `${state.service.title || product.title} | ${state.catalog.site.name}`;
  const updatePrefix = state.hasNewLatestRun ? "已切换至新时次" : "已更新";
  setText(
    els.updateLabel,
    `${activeDataSource().label} | ${updatePrefix} ${formatTime(run.published_at || state.catalog.published_at)}`,
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
  renderAirportViewMode(product, selectedFrame);
  renderAirportHourTimeline(product, selectedFrame);
  renderMetrics(product);
  renderProductNote(run, product, frame);
  renderAirportFeedback();
  updateControls(product);

  const imageSrc = forecastFrameSource(run, frame);
  const viewerSrc = viewerFrameSource(run, frame) || imageSrc;
  const downloadSrc = highQualityFrameSource(run, frame) || viewerSrc;
  const downloadName = imageDownloadName(run, product, frame, downloadSrc);
  const frameLabel = displayFrameLabel(frame);
  const imageAlt = `${product.title} ${frameLabel}`;
  setText(els.productTitle, product.title);
  setText(els.productUnit, `${product.category || "预报产品"} | ${product.unit || "--"}`);
  if (els.forecastImage) {
    loadForecastImage(imageSrc, imageAlt);
  }
  if (els.imageLink) els.imageLink.href = viewerSrc;
  if (els.imageDownload) {
    els.imageDownload.href = downloadSrc;
    els.imageDownload.download = downloadName;
  }
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
}

function updateControls(product) {
  const frames = isAirportHourlyView(product, currentFrame())
    ? airportHourlyFrames(currentFrame())
    : product.frames || [];
  const hasMultipleFrames = frames.length > 1;
  if (els.prevLead) els.prevLead.disabled = !hasMultipleFrames;
  if (els.nextLead) els.nextLead.disabled = !hasMultipleFrames;
}

function renderEmpty() {
  setText(els.updateLabel, `${activeDataSource().label} | 暂无数据`);
  setText(els.productTitle, "暂无可显示产品");
  setText(els.productUnit, "--");
  setText(els.leadLabel, "--");
  setText(els.validTime, "--");
  setText(els.sourceNote, state.service?.note || state.catalog?.note || "");
  if (els.productList) els.productList.innerHTML = "";
  if (els.runList) els.runList.innerHTML = "";
  if (els.leadTabs) els.leadTabs.innerHTML = "";
  if (els.metricGrid) els.metricGrid.innerHTML = "";
  if (els.forecastImage) els.forecastImage.removeAttribute("src");
  if (els.imageLink) els.imageLink.href = "#";
  if (els.imageDownload) els.imageDownload.href = "#";
  if (els.airportViewMode) els.airportViewMode.hidden = true;
  if (els.airportHourTimeline) {
    els.airportHourTimeline.hidden = true;
    els.airportHourTimeline.innerHTML = "";
  }
  renderAirportFeedback();
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
      state.airportPanelIndex = 0;
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
      state.leadIndex = defaultLeadIndex(product);
      state.airportPanelIndex = 0;
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
      state.airportPanelIndex = 0;
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
  return NATIONAL_FRAME_LABELS[frame?.id] || frame?.lead_label || frame?.valid_label || "--";
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

function isYunnanAirportPrecipProduct(product = currentProduct()) {
  return (
    pageConfig.service === "airport" &&
    product?.id === "airport_yunnan_precip_series"
  );
}

function airportHourlyFrames(frame = currentFrame()) {
  return Array.isArray(frame?.individual_frames)
    ? frame.individual_frames.filter((item) => item?.file)
    : [];
}

function isAirportHourlyView(product = currentProduct(), frame = currentFrame()) {
  return (
    state.airportViewMode === "hourly" &&
    isYunnanAirportPrecipProduct(product) &&
    airportHourlyFrames(frame).length > 0
  );
}

function reconcileAirportViewMode(product, frame) {
  const panels = airportHourlyFrames(frame);
  if (!isYunnanAirportPrecipProduct(product)) return;
  if (panels.length === 0) {
    state.airportViewMode = "montage";
    state.airportPanelIndex = 0;
    return;
  }
  state.airportPanelIndex = Math.min(
    Math.max(0, state.airportPanelIndex),
    panels.length - 1,
  );
}

function currentDisplayFrame() {
  const frame = currentFrame();
  if (!isAirportHourlyView(currentProduct(), frame)) return frame;
  return airportHourlyFrames(frame)[state.airportPanelIndex] || frame;
}

function renderAirportViewMode(product, frame) {
  if (!els.airportViewMode) return;
  const isAirportProduct = isYunnanAirportPrecipProduct(product);
  const hasPanels = airportHourlyFrames(frame).length > 0;
  els.airportViewMode.hidden = !isAirportProduct;
  if (!isAirportProduct) return;

  els.airportViewMode.querySelectorAll("[data-airport-view-mode]").forEach((button) => {
    const mode = button.dataset.airportViewMode;
    const active = mode === state.airportViewMode;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
    button.disabled = mode === "hourly" && !hasPanels;
  });
}

function renderAirportHourTimeline(product, frame) {
  const root = els.airportHourTimeline;
  if (!root) return;

  const showTimeline = isAirportHourlyView(product, frame);
  root.hidden = !showTimeline;
  root.innerHTML = "";
  if (!showTimeline) return;

  const panels = airportHourlyFrames(frame);
  root.classList.toggle("is-at-start", state.airportPanelIndex === 0);
  let activeButton = null;
  panels.forEach((panel, index) => {
    const button = document.createElement("button");
    const isActive = index === state.airportPanelIndex;
    const isRealtime = index === 0 && isAirportRealtimePanel(panel);
    const label = airportHourLabel(panel, isRealtime);
    button.type = "button";
    button.className = `airport-hour-button${isActive ? " is-active" : ""}`;
    button.setAttribute("aria-pressed", String(isActive));
    button.setAttribute("aria-label", isRealtime ? `实时 ${airportHourRange(panel)}` : airportHourRange(panel));
    button.textContent = isRealtime ? "实时" : label;
    button.addEventListener("click", () => {
      if (index === state.airportPanelIndex) return;
      state.airportPanelIndex = index;
      render();
    });
    root.appendChild(button);
    if (isActive) activeButton = button;
  });

  window.requestAnimationFrame(() => {
    if (state.airportPanelIndex === 0) {
      root.scrollTo({ left: 0, behavior: "auto" });
      return;
    }
    activeButton?.scrollIntoView({
      behavior: "smooth",
      block: "nearest",
      inline: "center",
    });
  });
}

function airportHourLabel(frame, isRealtime) {
  if (isRealtime) return "实时";
  const end = Date.parse(frame?.valid_time || "");
  if (Number.isNaN(end)) return frame?.lead_label || "--";
  const startParts = bjtParts(new Date(end - 60 * 60 * 1000));
  return `${twoDigits(startParts.month)}-${twoDigits(startParts.day)} ${twoDigits(startParts.hour)}时`;
}

function airportHourRange(frame) {
  const end = Date.parse(frame?.valid_time || "");
  if (Number.isNaN(end)) return frame?.valid_label || frame?.lead_label || "--";
  const startParts = bjtParts(new Date(end - 60 * 60 * 1000));
  const endParts = bjtParts(new Date(end));
  return `${startParts.year}-${twoDigits(startParts.month)}-${twoDigits(startParts.day)} ${twoDigits(startParts.hour)}:00-${twoDigits(endParts.hour)}:00 BJT`;
}

function isAirportRealtimePanel(frame) {
  const end = Date.parse(frame?.valid_time || "");
  if (Number.isNaN(end)) return false;
  const now = Date.now();
  return now >= end - 60 * 60 * 1000 && now < end;
}

function renderAirportFeedback() {
  const root = els.airportFeedback;
  const list = els.airportRatingList;
  const run = currentRun();
  if (!root || !list) return;

  const available = pageConfig.service === "airport" && Boolean(run?.id);
  root.hidden = !available || root.hidden;
  if (!available) {
    list.innerHTML = "";
    return;
  }

  const context = airportRatingContext(run);
  ensureAirportRatings(context);
  list.innerHTML = "";
  const snapshot = airportRatingsForContext(context);
  const viewerRatings = snapshot?.viewer_ratings || {};
  const aggregateRatings = snapshot?.ratings || {};
  const controlsDisabled = !pageConfig.airportRatingsApiUrl || state.airportRatings.loading || state.airportRatings.saving;
  AIRPORT_RATING_TARGETS.forEach((airport) => {
    const row = document.createElement("div");
    row.className = "airport-rating-row";

    const label = document.createElement("div");
    label.className = "airport-rating-airport";
    label.innerHTML = `<span class="airport-rating-plane" aria-hidden="true">&#9992;</span><span>${airport.label}</span>`;

    const choices = document.createElement("div");
    choices.className = "airport-rating-choices";
    choices.setAttribute("role", "group");
    choices.setAttribute("aria-label", `${airport.label}预报评分`);
    AIRPORT_RATING_OPTIONS.forEach((option) => {
      const button = document.createElement("button");
      const isSelected = viewerRatings[airport.id]?.rating === option.id;
      button.type = "button";
      button.className = `airport-rating-button${isSelected ? " is-active" : ""}`;
      button.textContent = option.label;
      button.setAttribute("aria-pressed", String(isSelected));
      button.disabled = controlsDisabled;
      button.addEventListener("click", () => toggleAirportRating(context, airport.id, option.id));
      choices.appendChild(button);
    });

    const summary = document.createElement("p");
    summary.className = "airport-rating-summary";
    const counts = aggregateRatings[airport.id] || {};
    summary.textContent = AIRPORT_RATING_OPTIONS
      .map((option) => `${option.label} ${Number(counts[option.id] || 0)}`)
      .join(" · ");

    row.append(label, choices, summary);
    list.appendChild(row);
  });

  setText(els.airportRatingStatus, airportRatingStatusText());
}

function setupAirportFeedback() {
  els.airportFeedbackToggle?.addEventListener("click", () => {
    if (!els.airportFeedback) return;
    const willOpen = els.airportFeedback.hidden;
    els.airportFeedback.hidden = !willOpen;
    els.airportFeedbackToggle.setAttribute("aria-expanded", String(willOpen));
    if (willOpen) renderAirportFeedback();
  });
}

function airportRatingContext(run = currentRun()) {
  const runId = run?.id || "";
  const sourceId = state.sourceId || "";
  return {
    sourceId,
    runId,
    key: airportRatingKey(sourceId, runId),
  };
}

function airportRatingKey(sourceId, runId) {
  return `${sourceId}:${runId}`;
}

function airportRatingsForContext(context) {
  return state.airportRatings.key === context.key ? state.airportRatings.data : null;
}

function airportRatingsApiUrl(context) {
  if (!pageConfig.airportRatingsApiUrl || !context?.runId || !context?.sourceId) return "";
  const url = new URL(pageConfig.airportRatingsApiUrl);
  url.searchParams.set("source_id", context.sourceId);
  url.searchParams.set("run_id", context.runId);
  url.searchParams.set("client_id", airportRatingClientId());
  return url.toString();
}

function airportRatingClientId() {
  try {
    const saved = window.localStorage.getItem(AIRPORT_RATING_CLIENT_ID_KEY);
    if (saved && /^[A-Za-z0-9_-]{6,128}$/.test(saved)) return saved;
    const generated = window.crypto?.randomUUID?.() || `browser_${Date.now()}_${Math.random().toString(36).slice(2)}`;
    window.localStorage.setItem(AIRPORT_RATING_CLIENT_ID_KEY, generated);
    return generated;
  } catch (error) {
    console.warn("airport rating identifier storage unavailable", error);
    return `browser_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  }
}

function ensureAirportRatings(context) {
  const url = airportRatingsApiUrl(context);
  if (!url || state.airportRatings.key === context.key) return;

  const requestId = state.airportRatings.requestId + 1;
  state.airportRatings = {
    key: context.key,
    data: null,
    loading: true,
    saving: false,
    error: "",
    requestId,
  };
  void fetchAirportRatings(url, context, requestId);
}

async function fetchAirportRatings(url, context, requestId) {
  try {
    const response = await fetch(url, { cache: "no-store", credentials: "omit" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    if (state.airportRatings.key !== context.key || state.airportRatings.requestId !== requestId) return;
    state.airportRatings.data = data;
    state.airportRatings.loading = false;
  } catch (error) {
    console.warn("airport ratings could not be loaded", error);
    if (state.airportRatings.key !== context.key || state.airportRatings.requestId !== requestId) return;
    state.airportRatings.loading = false;
    state.airportRatings.error = "评分暂时无法同步";
  }
  renderAirportFeedback();
}

async function toggleAirportRating(context, airportId, rating) {
  const url = airportRatingsApiUrl(context);
  if (!url || state.airportRatings.saving || state.airportRatings.loading) return;

  const previous = airportRatingsForContext(context)?.viewer_ratings?.[airportId]?.rating;
  state.airportRatings.saving = true;
  state.airportRatings.error = "";
  renderAirportFeedback();
  try {
    const response = await fetch(url, {
      method: "POST",
      cache: "no-store",
      credentials: "omit",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        source_id: context.sourceId,
        run_id: context.runId,
        airport_id: airportId,
        rating: previous === rating ? null : rating,
        client_id: airportRatingClientId(),
      }),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    if (state.airportRatings.key === context.key) state.airportRatings.data = data;
  } catch (error) {
    console.warn("airport rating could not be saved", error);
    if (state.airportRatings.key === context.key) state.airportRatings.error = "评分暂时无法同步，请重试";
  } finally {
    if (state.airportRatings.key === context.key) state.airportRatings.saving = false;
    renderAirportFeedback();
  }
}

function airportRatingStatusText() {
  if (!pageConfig.airportRatingsApiUrl) return "评分服务尚未配置";
  if (state.airportRatings.loading) return "正在同步评分…";
  if (state.airportRatings.saving) return "正在自动存档…";
  if (state.airportRatings.error) return state.airportRatings.error;
  return "评分自动存档";
}

function forecastFrameSource(run, frame) {
  return frameAssetSource(run, frame, frame?.preview_file || frame?.file);
}

function viewerFrameSource(run, frame) {
  return frameAssetSource(run, frame, frame?.viewer_file || frame?.file || frame?.preview_file);
}

function highQualityFrameSource(run, frame) {
  const file = highQualityFrameFile(frame);
  return file ? frameAssetSource(run, frame, file) : forecastFrameSource(run, frame);
}

function frameAssetSource(run, frame, file) {
  const assetSizes = [frame?.bytes, frame?.preview_bytes, frame?.full_bytes]
    .filter((value) => Number.isFinite(Number(value)))
    .join("-");
  const assetVersion = [frame?.version, assetSizes].filter(Boolean).join("-");
  return withAssetVersion(
    resolveAssetPath(file),
    assetVersion || run?.published_at || state.catalog?.published_at,
  );
}

function highQualityFrameFile(frame) {
  return (
    frame?.full_file ||
    frame?.download_file ||
    frame?.png_file ||
    frame?.file
  );
}

function collectServicePreloadSources(service) {
  const sources = new Set();
  const appendFrameSources = (run, frame) => {
    const viewerSource = viewerFrameSource(run, frame);
    const previewSource = forecastFrameSource(run, frame);
    if (viewerSource) sources.add(viewerSource);
    if (previewSource) sources.add(previewSource);
  };

  const activeRun = currentRun();
  const activeFrame = currentDisplayFrame();
  if (activeRun && activeFrame) appendFrameSources(activeRun, activeFrame);

  for (const run of service?.runs || []) {
    for (const product of run.products || []) {
      for (const frame of product.frames || []) appendFrameSources(run, frame);
    }
  }
  return [...sources];
}

function scheduleServiceImageWarmup(service) {
  if (state.prefetchTimer) window.clearTimeout(state.prefetchTimer);
  if (state.prefetchIdleId && "cancelIdleCallback" in window) {
    window.cancelIdleCallback(state.prefetchIdleId);
  }
  state.prefetchTimer = window.setTimeout(() => {
    state.prefetchTimer = null;
    const warmup = () => {
      state.prefetchIdleId = null;
      warmServiceImages(service);
    };
    if ("requestIdleCallback" in window) {
      state.prefetchIdleId = window.requestIdleCallback(warmup, {
        timeout: IMAGE_PREFETCH_IDLE_TIMEOUT_MS,
      });
      return;
    }
    warmup();
  }, 700);
}

function warmServiceImages(service) {
  if (!shouldWarmImages()) return;
  const sources = collectServicePreloadSources(service);
  const signature = sources.join("\n");
  if (state.prefetchSignature === signature) return;
  state.prefetchSignature = signature;

  const orderedSources = sources.filter(Boolean);
  let cursor = 0;
  const worker = async () => {
    while (cursor < orderedSources.length) {
      const source = orderedSources[cursor];
      cursor += 1;
      await preloadImageSource(source);
    }
  };

  const workerCount = Math.min(IMAGE_PREFETCH_CONCURRENCY, orderedSources.length);
  void Promise.all(Array.from({ length: workerCount }, () => worker()));
}

function shouldWarmImages() {
  const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
  if (!connection) return true;
  return !connection.saveData && !/^(slow-2g|2g)$/.test(connection.effectiveType || "");
}

function preloadImageSource(source) {
  return new Promise((resolve) => {
    const image = new Image();
    image.decoding = "async";
    image.onload = image.onerror = () => resolve();
    image.src = source;
  });
}

function stepLead(delta) {
  if (isAirportHourlyView()) {
    const frames = airportHourlyFrames();
    if (frames.length <= 1) return;
    state.airportPanelIndex =
      (state.airportPanelIndex + delta + frames.length) % frames.length;
    render();
    return;
  }
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
  const displaySource = attempt > 0 ? withRetryVersion(source, attempt) : source;

  els.forecastImage.onload = () => {
    if (requestId !== state.imageRequestId) return;
    state.imageStatus = "ready";
    setImageState("ready");
    scheduleServiceImageWarmup(state.service);
  };
  els.forecastImage.onerror = () => {
    if (requestId !== state.imageRequestId) return;
    retryForecastImage({ source, requestId, attempt });
  };
  els.forecastImage.src = displaySource;
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
  renderDataSourceSwitch();
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
      <a class="viewer-download-button" href="#" data-viewer-download download>下载原图</a>
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
  viewerState.downloadLink = root.querySelector("[data-viewer-download]");

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
  window.addEventListener("resize", handleViewerResize);

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
  els.imageDownload?.addEventListener("click", handleDownloadClick);
  viewerState.downloadLink?.addEventListener("click", handleDownloadClick);
}

function setupAirportViewMode() {
  els.airportViewMode?.addEventListener("click", (event) => {
    const button = event.target.closest("[data-airport-view-mode]");
    const mode = button?.dataset.airportViewMode;
    if (!mode || button.disabled || mode === state.airportViewMode) return;
    state.airportViewMode = mode;
    state.airportPanelIndex = 0;
    render();
  });
}

function viewerEntries() {
  if (isAirportHourlyView()) {
    const run = currentRun();
    const product = currentProduct();
    const leadIndex = state.leadIndex;
    return airportHourlyFrames().map((frame, airportPanelIndex) => ({
      runIndex: state.runIndex,
      productIndex: state.productIndex,
      leadIndex,
      airportPanelIndex,
      run,
      product,
      frame,
      source: viewerFrameSource(run, frame),
    }));
  }

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
          source: viewerFrameSource(run, frame),
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
      entry.leadIndex === state.leadIndex &&
      (entry.airportPanelIndex === undefined || entry.airportPanelIndex === state.airportPanelIndex),
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
  state.airportPanelIndex = next.airportPanelIndex || 0;
  state.hasNewLatestRun = false;
  render();
}

function syncViewerFrame(source, alt, { reset = false } = {}) {
  if (!viewerState.root || viewerState.root.hidden || !source) return;

  const run = currentRun();
  const product = currentProduct();
  const frame = currentDisplayFrame();
  // Use the medium WebP in the viewer. It stays sharp without decoding the
  // original 7000px PNG, and direct <img> requests do not require OSS CORS.
  const viewerSource = viewerFrameSource(run, frame) || source;
  const downloadSource = highQualityFrameSource(run, frame) || source;
  const downloadName = imageDownloadName(run, product, frame, downloadSource);
  const entries = viewerEntries();
  const position = entries.length ? `${currentViewerEntryIndex(entries) + 1}/${entries.length}` : "--";
  viewerState.title.textContent = product?.title || "预报图";
  viewerState.meta.textContent = [run?.label, position, displayFrameLabel(frame), frame?.valid_label]
    .filter(Boolean)
    .join(" · ");
  updateViewerControls();
  updateViewerDownload(downloadSource, downloadName);

  if (viewerState.source === viewerSource && (viewerState.loading || viewerState.image.src)) {
    if (reset) resetViewer();
    return;
  }

  viewerState.source = viewerSource;
  viewerState.requestId += 1;
  const requestId = viewerState.requestId;
  viewerState.loading = true;
  viewerState.resetOnImageLoad = reset;
  viewerState.image.alt = alt;
  if (reset) resetViewer();

  loadViewerImage({
    source: viewerSource,
    requestId,
  });
}

function loadViewerImage({ source, requestId }) {
  if (!viewerState.image) return;

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
    console.warn("viewer image request failed", source);
  };
  viewerState.image.removeAttribute("src");
  viewerState.image.src = source;
}

function openImageViewer(opener) {
  const frame = currentDisplayFrame();
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

function updateViewerDownload(source, name) {
  viewerState.downloadSource = source;
  viewerState.downloadName = name || "iaplacs-forecast.png";
  if (!viewerState.downloadLink) return;
  viewerState.downloadLink.href = source || "#";
  viewerState.downloadLink.download = viewerState.downloadName;
}

async function handleDownloadClick(event) {
  event.preventDefault();
  const link = event.currentTarget;
  const source = link === viewerState.downloadLink
    ? viewerState.downloadSource
    : link?.href;
  const name = link === viewerState.downloadLink
    ? viewerState.downloadName
    : link?.download || "iaplacs-forecast.png";
  if (!source || source === "#") return;

  try {
    const response = await fetch(source, { mode: "cors", cache: "no-store" });
    if (!response.ok) throw new Error(`download failed: ${response.status}`);
    const blob = await response.blob();
    const objectUrl = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = objectUrl;
    anchor.download = name;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
  } catch (error) {
    console.warn("direct download unavailable; opening source", error);
    window.open(source, "_blank", "noopener");
  }
}

function imageDownloadName(run, product, frame, source) {
  const extension = imageExtension(source);
  const parts = [
    pageConfig.service,
    run?.id,
    product?.id,
    frameId(frame),
  ]
    .filter(Boolean)
    .map((part) => String(part).replace(/[^a-zA-Z0-9_-]+/g, "_"));
  return `${parts.join("_") || "iaplacs-forecast"}${extension}`;
}

function imageExtension(source) {
  try {
    const pathname = new URL(source, window.location.href).pathname;
    const match = pathname.match(/\.(png|webp|jpe?g|svg)$/i);
    return match ? `.${match[1].toLowerCase()}` : ".png";
  } catch (error) {
    const match = String(source || "").match(/\.(png|webp|jpe?g|svg)(?:$|[?#])/i);
    return match ? `.${match[1].toLowerCase()}` : ".png";
  }
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
    viewerState.scale <= viewerMinScale() * 1.05 &&
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
    viewerMinScale(),
    viewerMaxScale(),
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
  const scale = clamp(nextScale, viewerMinScale(), viewerMaxScale());
  const point = Number.isFinite(clientX) && Number.isFinite(clientY)
    ? viewerPoint(clientX, clientY)
    : { x: 0, y: 0 };
  const ratio = scale / oldScale;
  viewerState.x = point.x - (point.x - viewerState.x) * ratio;
  viewerState.y = point.y - (point.y - viewerState.y) * ratio;
  viewerState.scale = scale;
  if (scale <= viewerMinScale() * 1.001) {
    viewerState.x = 0;
    viewerState.y = 0;
  }
  applyViewerTransform();
}

function resetViewer() {
  fitViewerImage();
  viewerState.fitScale = 1;
  viewerState.scale = viewerMinScale();
  viewerState.x = 0;
  viewerState.y = 0;
  applyViewerTransform();
}

function applyViewerTransform() {
  if (!viewerState.image || !viewerState.stage) return;
  viewerState.scale = clamp(viewerState.scale, viewerMinScale(), viewerMaxScale());
  clampViewerTranslation();
  viewerState.image.style.transform =
    `translate3d(${viewerState.x}px, ${viewerState.y}px, 0) scale(${viewerState.scale})`;
  if (viewerState.zoomLabel) {
    viewerState.zoomLabel.textContent = `${Math.round(viewerState.scale * 100)}%`;
  }
  viewerState.stage.classList.toggle("is-zoomed", viewerState.scale > viewerMinScale() * 1.01);
}

function clampViewerTranslation() {
  const imageWidth = viewerState.image.offsetWidth * viewerState.scale;
  const imageHeight = viewerState.image.offsetHeight * viewerState.scale;
  const maxX = Math.max(0, (imageWidth - viewerState.stage.clientWidth) / 2);
  const maxY = Math.max(0, (imageHeight - viewerState.stage.clientHeight) / 2);
  viewerState.x = clamp(viewerState.x, -maxX, maxX);
  viewerState.y = clamp(viewerState.y, -maxY, maxY);
}

function fitViewerImage() {
  if (!viewerState.image || !viewerState.stage) return 1;
  const naturalWidth = viewerState.image.naturalWidth || viewerState.image.offsetWidth || 1;
  const naturalHeight = viewerState.image.naturalHeight || viewerState.image.offsetHeight || 1;
  const stageWidth = Math.max(1, viewerState.stage.clientWidth - 32);
  const stageHeight = Math.max(1, viewerState.stage.clientHeight - 32);
  const scale = Math.min(1, stageWidth / naturalWidth, stageHeight / naturalHeight);
  viewerState.image.style.width = `${Math.max(1, Math.round(naturalWidth * scale))}px`;
  viewerState.image.style.height = `${Math.max(1, Math.round(naturalHeight * scale))}px`;
  return scale;
}

function viewerMinScale() {
  return 1;
}

function viewerMaxScale() {
  return MAX_VIEWER_SCALE;
}

function handleViewerResize() {
  if (!viewerState.root || viewerState.root.hidden) return;
  fitViewerImage();
  applyViewerTransform();
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
