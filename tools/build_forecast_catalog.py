#!/usr/bin/env python3
"""Build the static forecast run catalog from published map directories."""

from __future__ import annotations

import json
import os
import re
import subprocess
from datetime import datetime, timezone, timedelta
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAPS_DIR = ROOT / "data" / "current" / "maps"
CATALOG_PATH = ROOT / "data" / "current" / "forecast-runs.json"
BJT = timezone(timedelta(hours=8))
DEFAULT_ASSET_BASE_URL = (
    "https://iaplacs-forecast-images-hk.oss-cn-hongkong.aliyuncs.com/iaplacs"
)
MAX_RUNS = int(os.environ.get("IAPLACS_MAX_RUNS", "5"))
ASSET_BASE_URL = os.environ.get(
    "IAPLACS_ASSET_BASE_URL", DEFAULT_ASSET_BASE_URL
).strip().rstrip("/")


RUN_DIR_RE = re.compile(r"^wrf_montage_(\d{8}_\d{2})$")
AIRPORT_YUNNAN_DIR_RE = re.compile(r"^airport_yunnan_(\d{8}_\d{2})$")
DETAIL_RE = re.compile(r"_combined_detail_p(\d{2})_")
LEAD_RANGE_RE = re.compile(r"T(\d{2})_T(\d{2})", re.IGNORECASE)
YUNNAN_AIRPORTS = [
    {"id": "dehong_mangshi", "label": "德宏芒市机场降水"},
    {"id": "xishuangbanna_gasa", "label": "西双版纳嘎洒机场降水"},
    {"id": "puer_lancang_jingmai", "label": "普洱澜沧景迈机场降水"},
]


def main() -> None:
    existing_catalog = read_existing_catalog()
    airport_yunnan_runs = merge_existing_runs(
        build_yunnan_airport_runs(),
        existing_catalog,
        "airport",
        id_prefix="airport_yunnan_",
    )
    airport_runs = airport_yunnan_runs or build_airport_sample_runs()
    wrf_runs = merge_existing_runs(build_wrf_runs(), existing_catalog, "shangrao")
    ningxia_runs = merge_existing_runs(build_ningxia_runs(), existing_catalog, "ningxia")
    shangrao_runs = wrf_runs
    catalog_published_at = latest_published_at(
        airport_runs + ningxia_runs + shangrao_runs
    )
    airport_note = (
        "机场服务页展示 WORK_yn 云南区域36小时降水拼图，并单独列出德宏芒市、西双版纳嘎洒、普洱澜沧景迈三个机场点的累计降水；2米气温和10米风场入口继续保留。"
        if airport_yunnan_runs
        else "主页作为机场服务入口，当前保留降水、2米气温和10米风场样例产品；后续可替换为机场实况、短临和专用模式产品。"
    )
    catalog = {
        "schema_version": 1,
        "site": {"name": "IAP-LACS Forecast", "domain": "iaplacs.xyz"},
        "published_at": catalog_published_at,
        "services": {
            "airport": {
                "title": "机场气象服务",
                "subtitle": "Airport weather service",
                "note": airport_note,
                "latest_run": airport_runs[0]["id"] if airport_runs else None,
                "runs": airport_runs,
            },
            "main": {
                "title": "机场气象服务",
                "subtitle": "Airport weather service",
                "note": airport_note,
                "latest_run": airport_runs[0]["id"] if airport_runs else None,
                "runs": airport_runs,
            },
            "ningxia": {
                "title": "宁夏预报",
                "subtitle": "Ningxia forecast",
                "note": "宁夏页面集中展示 WORK_nx 发布的宁夏区域预报图。新起报时次推送到仓库后，会自动出现在顶部起报时间选择区。",
                "latest_run": ningxia_runs[0]["id"] if ningxia_runs else None,
                "runs": ningxia_runs,
            },
            "shangrao": {
                "title": "上饶专项天气服务",
                "subtitle": "Shangrao service",
                "note": "上饶服务页按起报时次展示服务器定时发布的 WRF 逐小时降水拼图，页面会在新的清单提交后自动读取最新时次。",
                "latest_run": shangrao_runs[0]["id"] if shangrao_runs else None,
                "runs": shangrao_runs,
            },
        },
    }
    CATALOG_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        f"wrote {CATALOG_PATH.relative_to(ROOT)} "
        f"with {len(airport_runs)} airport run(s), "
        f"{len(ningxia_runs)} ningxia run(s), {len(shangrao_runs)} shangrao run(s)"
    )


def build_yunnan_airport_runs() -> list[dict]:
    runs = []
    if not MAPS_DIR.exists():
        return runs

    for run_dir in sorted(MAPS_DIR.iterdir()):
        if not run_dir.is_dir():
            continue
        match = AIRPORT_YUNNAN_DIR_RE.match(run_dir.name)
        if not match:
            continue

        fragment_path = run_dir / "manifest_fragment.json"
        fragment = {}
        if fragment_path.exists():
            fragment = json.loads(fragment_path.read_text(encoding="utf-8"))

        frames = build_yunnan_airport_frames(run_dir, fragment)
        if not frames:
            continue

        run_id = fragment.get("run_prefix") or match.group(1)
        run_time = fragment.get("run_time") or parse_run_time(run_id).isoformat()
        generated_at = fragment.get("generated_at") or latest_mtime(run_dir).isoformat()
        runs.append(
            {
                "id": f"airport_yunnan_{run_id}",
                "label": f"{format_run_label(run_time)} BJT",
                "run_time": run_time,
                "published_at": generated_at,
                "summary": "云南机场降水预报图集，覆盖德宏芒市、西双版纳嘎洒、普洱澜沧景迈三个机场点。",
                "products": [
                    build_yunnan_airport_product(run_id, frames, generated_at, fragment),
                    *build_airport_sample_products(include_precip=False),
                ],
            }
        )

    runs.sort(key=lambda item: item["run_time"], reverse=True)
    return runs[:MAX_RUNS]


def build_yunnan_airport_frames(run_dir: Path, fragment: dict) -> list[dict]:
    groups: dict[str, list[Path]] = {}
    for path in run_dir.iterdir():
        if path.suffix.lower() not in {".png", ".webp", ".jpg", ".jpeg"}:
            continue
        stem = frame_asset_stem(path)
        if "_combined_overview_" not in stem:
            continue
        groups.setdefault(stem, []).append(path)

    frames = []
    for _, candidates in sorted(groups.items()):
        existing = [path for path in candidates if path.exists()]
        if not existing:
            continue
        path = choose_frame_candidate("_combined_overview", existing)
        preview_path = choose_preview_candidate(existing)
        full_path = choose_full_candidate("_combined_overview", existing)
        lead_label = lead_label_from_name(path.name)
        if "T13_T48" in path.name:
            lead_label = "36小时拼图"
        frame = {
            "id": "overview",
            "lead": lead_value_from_label(lead_label),
            "lead_label": lead_label,
            "file": forecast_asset_url(path),
            "bytes": path.stat().st_size,
        }
        valid_time = fragment.get("valid_time")
        if valid_time:
            frame["valid_time"] = valid_time
        add_preview_asset(frame, path, preview_path)
        add_full_asset(frame, path, full_path)
        frames.append(frame)

    frames.sort(key=lambda item: (item.get("lead", 0), item["file"]))
    return frames


def build_yunnan_airport_product(
    run_id: str, frames: list[dict], generated_at: str, fragment: dict
) -> dict:
    metrics = [
        {"label": "起报时次", "value": run_id.replace("_", " ") + " UTC"},
        {"label": "生成时间", "value": format_run_label(generated_at) + " BJT"},
        {"label": "图像数量", "value": str(len(frames))},
    ]
    metrics.extend(yunnan_airport_precip_metrics(fragment))
    return {
        "id": "airport_yunnan_precip_series",
        "title": "云南机场降水预报图集",
        "category": "机场服务",
        "unit": "mm",
        "color": "#0f68c8",
        "description": "WORK_yn 云南区域逐小时降水 6x6 拼图，标注德宏芒市、西双版纳嘎洒、普洱澜沧景迈三个机场位置。",
        "metrics": metrics,
        "frames": frames,
    }


def yunnan_airport_precip_metrics(fragment: dict) -> list[dict]:
    totals = fragment.get("airport_precip_totals") or []
    by_id = {
        str(item.get("id")): item
        for item in totals
        if isinstance(item, dict) and item.get("id")
    }
    metrics = []
    for airport in YUNNAN_AIRPORTS:
        total = by_id.get(airport["id"], {})
        metrics.append(
            {"label": airport["label"], "value": yunnan_airport_metric_value(total)}
        )
    return metrics


def yunnan_airport_metric_value(total: dict) -> str:
    if total.get("status") == "outside_domain":
        return "无网格覆盖"
    value = format_mm(total.get("total_mm"))
    if total.get("status") == "nearest_grid" and total.get("total_mm") is not None:
        return f"{value} (近邻网格)"
    return value


def build_airport_sample_products(include_precip: bool = True) -> list[dict]:
    products = [
        build_airport_product(
            product_id="airport_precip",
            title="机场降水预报",
            category="机场服务",
            unit="mm",
            color="#0f68c8",
            description="机场周边降水落区和强度样例产品，用于后续接入机场短临保障数据。",
            metrics=[
                {"label": "产品状态", "value": "样例接入"},
                {"label": "图像数量", "value": "2"},
                {"label": "服务对象", "value": "机场保障"},
            ],
            frames=[
                ("f024", 24, "F024", "2026-07-10T08:00:00+08:00", "precip_f024.svg"),
                ("f048", 48, "F048", "2026-07-11T08:00:00+08:00", "precip_f048.svg"),
            ],
        ),
        build_airport_product(
            product_id="airport_temperature",
            title="机场 2 米气温",
            category="机场服务",
            unit="degC",
            color="#b73b3b",
            description="",
            metrics=[
                {"label": "区域最高", "value": "36.2 degC"},
                {"label": "区域最低", "value": "17.4 degC"},
                {"label": "产品状态", "value": "样例接入"},
            ],
            frames=[
                ("f024", 24, "F024", "2026-07-10T08:00:00+08:00", "temp_f024.svg"),
                ("f048", 48, "F048", "2026-07-11T08:00:00+08:00", "temp_f048.svg"),
            ],
        ),
        build_airport_product(
            product_id="airport_wind",
            title="机场 10 米风场",
            category="机场服务",
            unit="m/s",
            color="#2c5f9e",
            description="",
            metrics=[
                {"label": "最大风速", "value": "15.8 m/s"},
                {"label": "主导风向", "value": "SE"},
                {"label": "产品状态", "value": "样例接入"},
            ],
            frames=[
                ("f024", 24, "F024", "2026-07-10T08:00:00+08:00", "wind_f024.svg"),
                ("f048", 48, "F048", "2026-07-11T08:00:00+08:00", "wind_f048.svg"),
            ],
        ),
    ]
    if not include_precip:
        products = [product for product in products if product["id"] != "airport_precip"]
    return [product for product in products if product["frames"]]


def build_airport_sample_runs() -> list[dict]:
    products = build_airport_sample_products(include_precip=True)
    if not products:
        return []
    return [
        {
            "id": "airport_20260709_08",
            "label": "2026-07-09 08:00 BJT",
            "run_time": "2026-07-09T08:00:00+08:00",
            "published_at": latest_airport_mtime(products).isoformat(),
            "summary": "机场服务样例产品，包含降水、气温和风场。",
            "products": products,
        }
    ]


def build_airport_product(
    product_id: str,
    title: str,
    category: str,
    unit: str,
    color: str,
    description: str,
    metrics: list[dict],
    frames: list[tuple[str, int, str, str, str]],
) -> dict:
    built_frames = []
    for frame_id, lead, lead_label, valid_time, file_name in frames:
        file_path = MAPS_DIR / file_name
        if not file_path.exists():
            continue
        built_frames.append(
            {
                "id": frame_id,
                "lead": lead,
                "lead_label": lead_label,
                "valid_time": valid_time,
                "file": "./" + file_path.relative_to(ROOT).as_posix(),
                "bytes": file_path.stat().st_size,
            }
        )
    return {
        "id": product_id,
        "title": title,
        "category": category,
        "unit": unit,
        "color": color,
        "description": description,
        "metrics": metrics,
        "frames": built_frames,
    }


def build_wrf_runs() -> list[dict]:
    runs = []
    if not MAPS_DIR.exists():
        return runs

    for run_dir in sorted(MAPS_DIR.iterdir()):
        if not run_dir.is_dir():
            continue
        match = RUN_DIR_RE.match(run_dir.name)
        if not match:
            continue
        run_id = match.group(1)
        frames = build_frames(run_id, run_dir)
        if not frames:
            continue
        run_time = parse_run_time(run_id)
        runs.append(
            {
                "id": run_id,
                "label": f"{run_time:%Y-%m-%d %H:%M} BJT",
                "run_time": run_time.isoformat(),
                "published_at": latest_mtime(run_dir).isoformat(),
                "summary": f"WRF 逐小时降水拼图，共 {len(frames)} 张图",
                "products": [build_wrf_product(run_id, frames)],
            }
        )

    runs.sort(key=lambda item: item["run_time"], reverse=True)
    return runs[:MAX_RUNS]


def build_ningxia_runs() -> list[dict]:
    runs = []
    if not MAPS_DIR.exists():
        return runs

    for run_dir in sorted(MAPS_DIR.glob("worknx_summary_*")):
        if not run_dir.is_dir():
            continue
        fragment_path = run_dir / "manifest_fragment.json"
        if not fragment_path.exists():
            continue
        fragment = json.loads(fragment_path.read_text(encoding="utf-8"))
        frames = build_ningxia_frames(run_dir, fragment)
        if not frames:
            continue

        run_id = fragment.get("run_prefix") or run_dir.name.replace("worknx_summary_", "")
        run_time = fragment.get("run_time") or parse_run_time(run_id).isoformat()
        generated_at = fragment.get("generated_at") or latest_mtime(run_dir).isoformat()

        runs.append(
            {
                "id": run_id,
                "label": f"{format_run_label(run_time)} BJT",
                "run_time": run_time,
                "published_at": generated_at,
                "summary": f"宁夏区域预报图集，共 {len(frames)} 张图",
                "products": [build_ningxia_product(run_id, frames, generated_at)],
            }
        )

    runs.sort(key=lambda item: item["run_time"], reverse=True)
    return runs[:MAX_RUNS]


def build_ningxia_frames(run_dir: Path, fragment: dict) -> list[dict]:
    groups: dict[str, list[Path]] = {}
    for path in run_dir.iterdir():
        if path.suffix.lower() not in {".png", ".webp", ".jpg", ".jpeg"}:
            continue
        groups.setdefault(frame_asset_stem(path), []).append(path)

    if not groups and fragment.get("file"):
        fallback = ROOT / fragment["file"].replace("./", "", 1)
        groups.setdefault(fallback.stem, []).append(fallback)

    # A regional 6x6 overview supersedes the legacy nationwide T01-T48 sheet.
    # Keeping this selection here makes a mixed transition directory render one
    # Ningxia regional product instead of exposing both products as frames.
    overview_groups = {
        key: candidates
        for key, candidates in groups.items()
        if "_combined_overview_" in key and "_6x6_" in key
    }
    if overview_groups:
        groups = overview_groups

    frames = []
    fragment_file = fragment.get("file", "")
    fragment_stem = Path(fragment_file).stem if fragment_file else ""
    for _, candidates in sorted(groups.items()):
        existing = [path for path in candidates if path.exists()]
        if not existing:
            continue
        path = choose_frame_candidate("", existing)
        preview_path = choose_preview_candidate(existing)
        full_path = choose_full_candidate("", existing)
        if not path.exists():
            continue
        lead_label = (
            "T13-T48"
            if "_combined_overview_" in path.stem and "T13_T48" in path.name
            else lead_label_from_name(path.name)
        )
        frame = {
            "id": path.stem.lower().replace("-", "_"),
            "lead": lead_value_from_label(lead_label),
            "lead_label": lead_label,
            "file": forecast_asset_url(path),
            "bytes": path.stat().st_size,
        }
        add_preview_asset(frame, path, preview_path)
        add_full_asset(frame, path, full_path)
        if fragment_stem and path.stem == fragment_stem:
            valid_time = fragment.get("valid_time")
            if valid_time:
                frame["valid_time"] = valid_time
        frames.append(frame)
    frames.sort(key=lambda item: (item.get("lead", 0), item["file"]))
    return frames


def build_ningxia_product(run_id: str, frames: list[dict], generated_at: str) -> dict:
    return {
        "id": "ningxia_precip_series",
        "title": "降水预报图集",
        "category": "宁夏预报",
        "unit": "mm",
        "color": "#0f68c8",
        "description": "WORK_nx 目录下的降水预报图集，按起报时次手动归档。",
        "metrics": [
            {"label": "起报时次", "value": run_id.replace("_", " ") + " UTC"},
            {"label": "生成时间", "value": format_run_label(generated_at) + " BJT"},
            {"label": "图像数量", "value": str(len(frames))},
        ],
        "frames": frames,
    }


def build_wrf_product(run_id: str, frames: list[dict]) -> dict:
    return {
        "id": "wrf_rain_montage",
        "title": "上饶 WRF 逐小时降水拼图",
        "category": "上饶预报",
        "unit": "mm",
        "color": "#0f68c8",
        "description": f"上饶服务起报时次 {run_id}，包含总览图和分段细节图。",
        "metrics": [
            {"label": "起报时次", "value": run_id.replace("_", " ") + " BJT"},
            {"label": "图像数量", "value": str(len(frames))},
            {"label": "产品状态", "value": "服务器发布"},
        ],
        "frames": frames,
    }


def build_frames(run_id: str, run_dir: Path) -> list[dict]:
    groups: dict[str, list[Path]] = {}
    for path in run_dir.iterdir():
        if path.suffix.lower() not in {".png", ".webp", ".jpg", ".jpeg"}:
            continue
        stem = frame_asset_stem(path)
        if not stem.startswith(run_id + "_combined_"):
            continue
        key = stem
        if key.endswith("_grid"):
            key = key[: -len("_grid")]
        if "_combined_overview_" in key:
            key = f"{run_id}_combined_overview"
        groups.setdefault(key, []).append(path)

    frames = []
    for key, candidates in sorted(groups.items(), key=frame_sort_key):
        chosen = choose_frame_candidate(key, candidates)
        full = choose_full_candidate(key, candidates)
        frame = frame_meta(run_id, key)
        frame["file"] = forecast_asset_url(chosen)
        frame["bytes"] = chosen.stat().st_size
        preview = choose_preview_candidate(candidates)
        add_preview_asset(frame, chosen, preview)
        add_full_asset(frame, chosen, full)
        frames.append(frame)
    return frames


def choose_frame_candidate(key: str, candidates: list[Path]) -> Path:
    if "_combined_overview" in key:
        six_by_six = [path for path in candidates if "_6x6_" in path.name]
        if six_by_six:
            candidates = six_by_six
    candidates = [path for path in candidates if not is_preview_asset(path)] or candidates
    return min(candidates, key=lambda item: (frame_candidate_score(item), item.stat().st_size))


def choose_preview_candidate(candidates: list[Path]) -> Path:
    previews = [path for path in candidates if is_preview_asset(path)]
    if previews:
        return min(previews, key=lambda item: item.stat().st_size)
    return min(
        [path for path in candidates if not is_preview_asset(path)] or candidates,
        key=lambda item: (frame_candidate_score(item), item.stat().st_size),
    )


def choose_full_candidate(key: str, candidates: list[Path]) -> Path:
    if "_combined_overview" in key:
        six_by_six = [path for path in candidates if "_6x6_" in path.name]
        if six_by_six:
            candidates = six_by_six
    candidates = [path for path in candidates if not is_preview_asset(path)] or candidates
    pngs = [path for path in candidates if path.suffix.lower() == ".png"]
    if pngs:
        return max(pngs, key=lambda item: item.stat().st_size)
    return max(candidates, key=lambda item: item.stat().st_size)


def add_preview_asset(frame: dict, main_path: Path, preview_path: Path) -> None:
    if preview_path == main_path:
        return
    frame["preview_file"] = forecast_asset_url(preview_path)
    frame["preview_bytes"] = preview_path.stat().st_size


def add_full_asset(frame: dict, preview_path: Path, full_path: Path) -> None:
    if full_path == preview_path:
        return
    frame["full_file"] = forecast_asset_url(full_path)
    frame["full_bytes"] = full_path.stat().st_size


def is_preview_asset(path: Path) -> bool:
    return path.stem.endswith(".preview")


def frame_asset_stem(path: Path) -> str:
    stem = path.stem
    return stem[: -len(".preview")] if stem.endswith(".preview") else stem


def frame_candidate_score(path: Path) -> int:
    suffix = path.suffix.lower()
    if suffix == ".webp":
        return 0
    if suffix == ".png":
        return 1
    return 2


def forecast_asset_url(path: Path) -> str:
    relative = path.relative_to(ROOT).as_posix()
    if ASSET_BASE_URL:
        return f"{ASSET_BASE_URL}/{relative}"
    return f"./{relative}"


def frame_sort_key(item: tuple[str, list[Path]]) -> tuple[int, int, str]:
    key = item[0]
    if "_combined_overview" in key:
        return (0, 0, key)
    detail = DETAIL_RE.search(key)
    if detail:
        return (1, int(detail.group(1)), key)
    return (2, 0, key)


def frame_meta(run_id: str, key: str) -> dict:
    if "_combined_overview" in key:
        return {
            "id": "overview",
            "lead": 48,
            "lead_label": "总览",
            "valid_label": "",
        }

    detail = DETAIL_RE.search(key)
    if detail:
        page = int(detail.group(1))
        lead = 24 + (page - 1) * 12
        return {
            "id": f"detail_p{page:02d}",
            "lead": lead,
            "lead_label": detail_window_label(run_id, page),
            "valid_label": "",
        }

    return {
        "id": key.replace(run_id + "_combined_", ""),
        "lead": 0,
        "lead_label": key.replace(run_id + "_combined_", ""),
        "valid_label": "组合图",
    }


def detail_window_label(run_id: str, page: int) -> str:
    run_time = parse_run_time(run_id)
    start = run_time + timedelta(hours=12 + (page - 1) * 12)
    end = run_time + timedelta(hours=24 + (page - 1) * 12)
    return f"{start:%m-%d %H}-{end:%H}"


def lead_label_from_name(file_name: str) -> str:
    match = LEAD_RANGE_RE.search(file_name)
    if match:
        return f"T{match.group(1)}-T{match.group(2)}"
    return Path(file_name).stem


def lead_value_from_label(label: str) -> int:
    match = re.search(r"(\d+)(?!.*\d)", label)
    return int(match.group(1)) if match else 0


def parse_run_time(run_id: str) -> datetime:
    return datetime.strptime(run_id, "%Y%m%d_%H").replace(tzinfo=BJT)


def format_run_label(value: str) -> str:
    try:
        return datetime.fromisoformat(value).astimezone(BJT).strftime("%Y-%m-%d %H:%M")
    except ValueError:
        return value


def human_size(byte_count: int) -> str:
    units = ["B", "KB", "MB", "GB"]
    value = float(byte_count)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{byte_count} B"


def format_mm(value: object) -> str:
    try:
        return f"{float(value):.1f} mm"
    except (TypeError, ValueError):
        return "--"


def read_existing_catalog() -> dict:
    catalog = read_catalog_file(CATALOG_PATH)
    for ref in ("HEAD", "HEAD~1", "HEAD~2"):
        catalog = merge_catalog_service_runs(catalog, read_git_catalog(ref))
    return catalog


def read_catalog_file(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def read_git_catalog(ref: str) -> dict:
    try:
        result = subprocess.run(
            ["git", "-C", str(ROOT), "show", f"{ref}:data/current/forecast-runs.json"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return {}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}


def merge_catalog_service_runs(primary: dict, fallback: dict) -> dict:
    if not primary:
        return fallback
    if not fallback:
        return primary

    services = primary.setdefault("services", {})
    fallback_services = fallback.get("services") or {}
    for service_key, fallback_service in fallback_services.items():
        if not isinstance(fallback_service, dict):
            continue
        current_service = services.get(service_key)
        if not isinstance(current_service, dict):
            services[service_key] = fallback_service
            continue

        current_runs = current_service.get("runs") or []
        fallback_runs = fallback_service.get("runs") or []
        merged_runs: dict[str, dict] = {}
        for run in fallback_runs + current_runs:
            run_id = str(run.get("id", ""))
            if run_id:
                merged_runs[run_id] = run

        if len(merged_runs) <= len(current_runs):
            continue

        runs = list(merged_runs.values())
        runs.sort(key=lambda item: item.get("run_time", ""), reverse=True)
        preserved = {**fallback_service, **current_service}
        preserved["runs"] = runs[:MAX_RUNS]
        latest_run = current_service.get("latest_run")
        if not any(run.get("id") == latest_run for run in preserved["runs"]):
            latest_run = preserved["runs"][0].get("id") if preserved["runs"] else None
        preserved["latest_run"] = latest_run
        services[service_key] = preserved
    return primary


def merge_existing_runs(
    local_runs: list[dict],
    existing_catalog: dict,
    service_key: str,
    id_prefix: str = "",
) -> list[dict]:
    service = existing_catalog.get("services", {}).get(service_key, {})
    existing_runs = service.get("runs") or []
    merged: dict[str, dict] = {}

    for run in existing_runs:
        run_id = str(run.get("id", ""))
        if not run_id:
            continue
        if id_prefix and not run_id.startswith(id_prefix):
            continue
        merged[run_id] = run

    for run in local_runs:
        run_id = str(run.get("id", ""))
        if run_id:
            merged[run_id] = run

    runs = list(merged.values())
    runs.sort(key=lambda item: item.get("run_time", ""), reverse=True)
    return runs[:MAX_RUNS]


def latest_published_at(runs: list[dict]) -> str:
    if not runs:
        return iso_now()
    return max(run["published_at"] for run in runs)


def latest_airport_mtime(products: list[dict]) -> datetime:
    mtimes = []
    for product in products:
        for frame in product.get("frames", []):
            path = ROOT / frame["file"].replace("./", "", 1)
            if path.exists():
                mtimes.append(path.stat().st_mtime)
    if not mtimes:
        return datetime.now(tz=BJT)
    return datetime.fromtimestamp(max(mtimes), tz=BJT)


def latest_mtime(path: Path) -> datetime:
    latest = max(child.stat().st_mtime for child in path.iterdir() if child.is_file())
    return datetime.fromtimestamp(latest, tz=BJT)


def iso_now() -> str:
    return datetime.now(tz=BJT).replace(microsecond=0).isoformat()


if __name__ == "__main__":
    main()
