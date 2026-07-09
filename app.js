const state = {
  manifest: null,
  productIndex: 0,
  leadIndex: 0,
  timer: null,
};

const els = {
  updateLabel: document.querySelector("#updateLabel"),
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
  try {
    const response = await fetch("./data/current/manifest.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`manifest ${response.status}`);
    state.manifest = await response.json();
    state.productIndex = 0;
    state.leadIndex = 0;
    render();
  } catch (error) {
    els.updateLabel.textContent = "数据读取失败";
    els.productTitle.textContent = "无法读取 manifest.json";
    console.error(error);
  }
}

function render() {
  const { manifest } = state;
  const product = currentProduct();
  const frame = currentFrame();

  document.title = `${product.title} | ${manifest.site.name}`;
  els.updateLabel.textContent = `已更新 ${formatTime(manifest.published_at)}`;
  els.runTime.textContent = formatTime(manifest.run_time);
  els.publishedAt.textContent = formatTime(manifest.published_at);
  els.sourceNote.textContent = manifest.note;

  renderProducts();
  renderLeads();
  renderMetrics(product);
  renderLegend(product);
  renderStationChart(manifest.station_series);

  els.productTitle.textContent = product.title;
  els.productUnit.textContent = `${product.category} | ${product.unit}`;
  els.forecastImage.src = frame.file;
  els.forecastImage.alt = `${product.title} ${frame.lead_label}`;
  els.imageLink.href = frame.file;
  els.leadLabel.textContent = frame.lead_label;
  els.validTime.textContent = `有效时间 ${formatTime(frame.valid_time)}`;
}

function renderProducts() {
  els.productList.innerHTML = "";
  state.manifest.products.forEach((product, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `product-button${index === state.productIndex ? " is-active" : ""}`;
    button.innerHTML = `
      <span class="product-stripe" style="background:${product.color}"></span>
      <span>
        <span class="product-name">${product.title}</span>
        <span class="product-desc">${product.description}</span>
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
  const product = currentProduct();
  els.leadTabs.innerHTML = "";
  product.frames.forEach((frame, index) => {
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
  els.metricGrid.innerHTML = "";
  product.metrics.forEach((metric) => {
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
  els.legendUnit.textContent = product.unit;
  els.legendBar.style.background = product.legend.gradient;
  els.legendTicks.innerHTML = "";
  product.legend.ticks.forEach((tick) => {
    const span = document.createElement("span");
    span.textContent = tick;
    els.legendTicks.appendChild(span);
  });
}

function renderStationChart(series) {
  if (!series || !series.points?.length) return;
  const width = 320;
  const height = 140;
  const pad = 22;
  const values = series.points.map((point) => point.value);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const path = series.points
    .map((point, index) => {
      const x = pad + (index / (series.points.length - 1)) * (width - pad * 2);
      const y = height - pad - ((point.value - min) / span) * (height - pad * 2);
      return `${index === 0 ? "M" : "L"} ${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(" ");

  const area = `${path} L ${width - pad} ${height - pad} L ${pad} ${height - pad} Z`;

  els.stationChart.innerHTML = `
    <path d="${area}" fill="rgba(8, 125, 122, 0.12)"></path>
    <path d="${path}" fill="none" stroke="#087d7a" stroke-width="3"></path>
    <line x1="${pad}" y1="${height - pad}" x2="${width - pad}" y2="${height - pad}" stroke="#d8e0e6"></line>
    <text x="${pad}" y="18" fill="#667386" font-size="11">${series.name}</text>
    <text x="${width - pad}" y="18" text-anchor="end" fill="#667386" font-size="11">${series.unit}</text>
  `;
}

function currentProduct() {
  return state.manifest.products[state.productIndex];
}

function currentFrame() {
  return currentProduct().frames[state.leadIndex];
}

function stepLead(delta) {
  const count = currentProduct().frames.length;
  state.leadIndex = (state.leadIndex + delta + count) % count;
  render();
}

function togglePlayback() {
  if (state.timer) {
    stopPlayback();
    return;
  }
  els.playToggle.textContent = "暂停";
  state.timer = window.setInterval(() => stepLead(1), 1800);
}

function stopPlayback() {
  if (!state.timer) return;
  window.clearInterval(state.timer);
  state.timer = null;
  els.playToggle.textContent = "播放";
}

function formatTime(value) {
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date(value));
}

els.prevLead.addEventListener("click", () => stepLead(-1));
els.nextLead.addEventListener("click", () => stepLead(1));
els.playToggle.addEventListener("click", togglePlayback);

init();
