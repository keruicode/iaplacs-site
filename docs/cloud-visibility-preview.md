# Cloud Visibility Preview

## Production Integration (2026-10-31)

After user approval, the same method is enabled as the last fallback for both
Yunnan and Xinjiang by `publish_work_visibility.sh`. Within the selected usable
domain (d02 preferred), priority is VIS_MIN, then VIS, then complete cloud-moment
inputs. Ningxia remains native VIS_MIN only. The existing completed-WRF gate,
post-spin-up times, two-minute audits, upload receipts and retry locks remain.

The wrapper passes `--production` for diagnostic runs. Production manifests
identify DIAGNOSTIC_CLOUD_VIS and the UI unit says diagnostic visibility. Cache
signatures use the original WRF size/mtime, method and plotting hashes, region,
SHP, resolution and time selection. Native fields are checked before consulting
the diagnostic cache, so newly available native data replaces diagnostic images.
Temporary diagnostic NetCDF files are removed, not uploaded to OSS/GitHub.
PNG originals and WebP display images use the existing OSS/catalog pipeline.
Initial publication targets completed 2026103100 Yunnan and Xinjiang runs.

The following describes the original isolated experiment and method.

This isolated Xinjiang experiment does not change the deployed production renderer,
publisher, crontab, WRF files, or native VIS_MIN/VIS selection.

## Method

- Use lowest-model-level QCLOUD, NW (or QNCLOUD), and NW_Z at each output time.
- Reuse the user's FOG three-moment `vis1` implementation in
  `tools/cloud_visibility_moments.py`. Multiple complete cloud spectra are handled
  by adding extinction, not averaging visibility. Incomplete or ambiguous spectra
  fail explicitly.
- Reconstruct dry-air density from P+PB, dry potential temperature T+300, QVAPOR:
  `Tk = theta * (p/100000) ** (287/1004.5)` and
  `rho_d = p / (287 * Tk * (1 + (461.6/287) * qv))`.
  This is not claimed identical to the microphysics substep RHO_0.
  Temperature inputs follow [NCAR wrf_tk](https://www.ncl.ucar.edu/Document/Functions/Built-in/wrf_tk.shtml).
- The inspected IAP `module_mp_iap_lacs.F` assigns NW directly from
  droplet_number, and NW_Z from linear droplet reflectivity divided by rho_0.
  Sampled NW values reach hundreds of millions per kg, contradicting its legacy
  `log10` units attribute. This experiment explicitly treats NW as linear;
  it never exponentiates these values. The inspected source directory is
  `zhoubj/WRF/wrf413_3d/phys`; exact executable build provenance is not established.
- Cloud extinction alone excludes rain, ice and aerosol extinction. Do not call
  this total atmospheric visibility, runway visual range, 2-m visibility, or an
  hourly minimum. No within-hour minimum can be recovered from hourly snapshots.

## Quality Control

Missing inputs remain masked. Cloud mass with zero/absent number or sixth moment
is masked rather than declared clear. Negative mass/water-vapor mixing ratios
below -1e-12 are masked; tiny negative roundoff down to -1e-12 is counted and
treated as zero for this preview. FOG's q<1e-10 threshold, shape-parameter limits
and extinction conversion are retained. Zero cloud extinction and estimates
above 100 km use FOG's 100-km display ceiling; this does not assert real-world
clear-air visibility. All >=1 km values and invalid cells are white in the
requested FOG palette. The original WRF values are never modified.

## Reproduction

Run `tools/render_cloud_visibility_preview.py` with `--input`, `--output`,
`--profile xinjiang --domain d02` and `--province-shp`. `--county-shp` is optional;
the present IAP SHP folder has no xinjiang_city.shp, so this case uses province
boundaries only, as the existing Xinjiang visibility publisher does.
Use only a completed input. By default the first selected output is lead 13 h.
The renderer produces 400-dpi PNG hourly maps and montage, diagnostic_fields.nc,
diagnostic_provenance.json and a preview-only production_manifest.json.
The manifest identifies DIAGNOSTIC_CLOUD_VIS, not native VIS or VIS_MIN.
Input hashes, source stat, code hashes, density range and QC counts are retained.

The first case is WORK_xj/2026103018 d02, initialized October 31 02:00 BJT,
with 12 selected times October 31 15:00 through November 1 02:00 BJT.
The newer 2026103100 was still running at selection and was not used.
Native production remains VIS_MIN first, VIS second; no diagnostic fallback has
been added to automatic publication.

The local renderer and isolated server copy additionally use longitude ticks
anchored at 72 E every 8 degrees, latitude ticks anchored at 34 N every 4 degrees
for Xinjiang only. Tick locations are restricted to the actual plotted domain.
Other region ticks are unchanged. This code adjustment has not been deployed
to the production scripts directory.
