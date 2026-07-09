const DEFAULT_REFRESH_MS = 5 * 60 * 1000;

const pageConfig = {
  service: document.body.dataset.service || "main",
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
  playbackTimer: null,
  refreshTimer: null,
};

const els = {
  updateLabel: document.querySelector("#updateLabel"),
  runList: document.querySelector("#runList"),
  productList: document.querySelector("#productList"),
  runTime: document.querySelector("#runTime"),
  publishedAt: document.querySelector("#publishedAt"),
  sourceNote: document.querySelector("#sourceNote"),
  productUnit: document.querySelector("#productUnit"),
  productTitle: document.querySelector("#productTitle"),
  forecastImage: document.querySelector("#forecastImage"),
  leadLabel: document.querySelector("#leadLabel"),
  validTime: document.querySelector("#validTime"),
  leadTabs: document.querySelector("#leadTabs"),
  prevLead: document.querySelector("#prevLead"),
  nextLead: document.querySelector("#nextLead"),
  playToggle: document.querySelector("#playToggle"),
  imageLink: document.querySelector("#imageLink"),
  metricGrid: document.querySelector("#metricGrid"),
  legendUnit: document.querySelector("#legendUnit"),
  legendBar: document.querySelector("#legendBar"),
  legendTicks: document.querySelector("#legendTicks"),
  stationChart: document.querySelector("#stationChart"),
};

async function init() {
  await loadForecast({ preserveSelection: false });
  if (pageConfig.refreshMs > 0) {
    state.refreshTimer = window.setInterval(
      () => loadForecast({ preserveSelection: true }),
      pageConfig.refreshMs,
    );
  }
}

async function loadForecast({ preserveSelection }) {
  const previous = preserveSelection ? currentSelection() : {};

  try {
    const raw = await fetchForecastData();
    const catalog = normalizeForecastData(raw);
    const service = selectService(catalog);

    state.catalog = catalog;
    state.service = service;
    state.runIndex = chooseRunIndex(service, previous.runId);
    state.productIndex = chooseProductIndex(currentRun(), previous.productId);
    state.leadIndex = chooseLeadIndex(currentProduct(), previous.frameId);
    stopPlayback();
    render();
  } catch (error) {
    showError(error);
  }
}

async function fetchForecastData() {
  try {
    return await fetchJson(pageConfig.manifestUrl);
  } catch (error) {
    console.warn(`primary forecast catalog failed: ${pageConfig.manifestUrl}`, error);
    return fetchJson(pageConfig.fallbackManifestUrl);
  }
}

async function fetchJson(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`${url} ${response.status}`);
  return response.json();
}

function normalizeForecastData(raw) {
  if (raw.services) return raw;

  const legacyRun = {
    id: "legacy-current",
    label: formatTime(raw.run_time),
    run_time: raw.run_time,
    published_at: raw.published_at,
    summary: raw.note,
    products: raw.products || [],
    station_series: raw.station_series,
  };

  return {
    schema_version: 0,
    site: raw.site || { name: "IAP-LACS Forecast", domain: "iaplacs.xyz" },
    published_at: raw.published_at,
    services: {
      main: {
        title: raw.site?.name || "综合预报",
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
  };
}

function selectService(catalog) {
  const services = catalog.services || {};
  return services[pageConfig.service] || services.main || Object.values(services)[0];
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
  setText(els.updateLabel, `已更新 ${formatTime(run.published_at || state.catalog.published_at)}`);
  setText(els.runTime, run.label || formatTime(run.run_time));
  setText(els.publishedAt, formatTime(run.published_at || state.catalog.published_at));
  setText(els.sourceNote, state.service.note || run.summary || state.catalog.note || "");

  renderRuns();
  renderProducts();
  renderLeads();
  renderMetrics(product);
  renderLegend(product);
  renderStationChart(run.station_series || state.service.station_series || state.catalog.station_series);

  const imageSrc = resolveAssetPath(frame.file);
  setText(els.productTitle, product.title);
  setText(els.productUnit, `${product.category || "预报产品"} | ${product.unit || "--"}`);
  if (els.forecastImage) {
    els.forecastImage.src = imageSrc;
    els.forecastImage.alt = `${product.title} ${frame.lead_label}`;
  }
  if (els.imageLink) els.imageLink.href = imageSrc;
  setText(els.leadLabel, frame.lead_label);
  setText(els.validTime, frame.valid_label || `有效时间 ${formatTime(frame.valid_time)}`);
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
}

function renderRuns() {
  if (!els.runList) return;
  els.runList.innerHTML = "";
  (state.service.runs || []).forEach((run, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `run-button${index === state.runIndex ? " is-active" : ""}`;
    button.innerHTML = `
      <span class="run-name">${run.label || run.id}</span>
      <span class="run-desc">${run.summary || `发布 ${formatTime(run.published_at)}`}</span>
    `;
    button.addEventListener("click", () => {
      state.runIndex = index;
      state.productIndex = 0;
      state.leadIndex = 0;
      stopPlayback();
      render();
    });
    els.runList.appendChild(button);
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
      stopPlayback();
      render();
    });
    els.productList.appendChild(button);
  });
}

function renderLeads() {
  if (!els.leadTabs) return;
  const product = currentProduct();
  els.leadTabs.innerHTML = "";
  (product.frames || []).forEach((frame, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `lead-tab${index === state.leadIndex ? " is-active" : ""}`;
    button.textContent = frame.lead_label;
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

function renderLegend(product) {
  if (!els.legendUnit || !els.legendBar || !els.legendTicks) return;
  els.legendUnit.textContent = product.unit || "--";
  els.legendBar.style.background =
    product.legend?.gradient ||
    "linear-gradient(90deg, #e6eef4, #7fc8e8, #2c7bb6, #36a852, #f6d64a, #ee8a35, #c33f3f)";
  els.legendTicks.innerHTML = "";
  (product.legend?.ticks || []).forEach((tick) => {
    const span = document.createElement("span");
    span.textContent = tick;
    els.legendTicks.appendChild(span);
  });
}

function renderStationChart(series) {
  if (!els.stationChart) return;
  if (!series || !series.points?.length) {
    els.stationChart.innerHTML = `
      <text x="24" y="72" fill="#667386" font-size="12">暂无站点序列</text>
    `;
    return;
  }

  const width = 320;
  const height = 140;
  const pad = 22;
  const values = series.points.map((point) => point.value);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const path = series.points
    .map((point, index) => {
      const denom = Math.max(series.points.length - 1, 1);
      const x = pad + (index / denom) * (width - pad * 2);
      const y = height - pad - ((point.value - min) / span) * (height - pad * 2);
      return `${index === 0 ? "M" : "L"} ${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(" ");

  const area = `${path} L ${width - pad} ${height - pad} L ${pad} ${height - pad} Z`;

  els.stationChart.innerHTML = `
    <path d="${area}" fill="rgba(15, 104, 200, 0.12)"></path>
    <path d="${path}" fill="none" stroke="#0f68c8" stroke-width="3"></path>
    <line x1="${pad}" y1="${height - pad}" x2="${width - pad}" y2="${height - pad}" stroke="#d8e0e6"></line>
    <text x="${pad}" y="18" fill="#667386" font-size="11">${series.name}</text>
    <text x="${width - pad}" y="18" text-anchor="end" fill="#667386" font-size="11">${series.unit}</text>
  `;
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

function stepLead(delta) {
  const frames = currentProduct()?.frames || [];
  if (!frames.length) return;
  state.leadIndex = (state.leadIndex + delta + frames.length) % frames.length;
  render();
}

function togglePlayback() {
  if (state.playbackTimer) {
    stopPlayback();
    return;
  }
  setText(els.playToggle, "暂停");
  state.playbackTimer = window.setInterval(() => stepLead(1), 1800);
}

function stopPlayback() {
  if (!state.playbackTimer) return;
  window.clearInterval(state.playbackTimer);
  state.playbackTimer = null;
  setText(els.playToggle, "播放");
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
  console.error(error);
}

function formatTime(value) {
  if (!value) return "--";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

els.prevLead?.addEventListener("click", () => stepLead(-1));
els.nextLead?.addEventListener("click", () => stepLead(1));
els.playToggle?.addEventListener("click", togglePlayback);

init();
