// Only verified OSS manifests expose a download; changing run cancels stale UI.
(() => {
  const block = document.querySelector("#regionalDataBlock");
  const link = document.querySelector("#regionalDataDownload");
  if (!block || !link) return;
  const base = document.body.dataset.downloadBase ||
    "https://iaplacs-forecast-images-hk.oss-cn-hongkong.aliyuncs.com/iaplacs";
  const cache = new Map();
  let selection = "";
  let controller;
  window.updateRegionalDataDownload = async (run, service, source) => {
    const id = service === "ningxia" && source === "huan" && /^\d{8}_\d{2}$/.test(run?.id || "")
      ? run.id : "";
    const cached = cache.get(id);
    if (selection === id && cached && Date.now() - cached.checked < 120000) return;
    controller?.abort();
    selection = id;
    block.hidden = true;
    link.removeAttribute("href");
    if (!id) return;
    const directory = `${base.replace(/\/$/, "")}/data/current/maps/worknx_summary_${id}/downloads/`;
    controller = new AbortController();
    const signal = controller.signal;
    try {
      let data = cached && Date.now() - cached.checked < 120000 ? cached.data : null;
      if (!data) {
        const response = await fetch(`${directory}index.json?t=${Math.floor(Date.now() / 120000)}`, { signal, cache: "no-store" });
        if (!response.ok) throw new Error(`NC manifest HTTP ${response.status}`);
        data = await response.json();
        if (data.run_id !== id || data.schema_version !== 1 ||
            !/^ningxia_\d{10}_d\d{2}_[a-f0-9]{16}\.nc$/.test(data.file || "") ||
            !/^[a-f0-9]{64}$/.test(data.sha256 || "") || !(data.bytes > 0)) {
          throw new Error("Invalid NC download manifest");
        }
        cache.set(id, { data, checked: Date.now() });
      }
      if (selection !== id || signal.aborted) return;
      link.href = directory + data.file + "?download=1";
      link.download = data.file.replace(/_[a-f0-9]{16}\.nc$/, ".nc");
      link.title = `宁夏区域 · ${(data.bytes / 1048576).toFixed(1)} MB`;
      block.hidden = false;
    } catch (error) {
      if (error.name !== "AbortError" && selection === id) {
        cache.set(id, { data: null, checked: Date.now() });
      }
    }
  };
})();
