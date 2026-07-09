#!/usr/bin/env python3
"""Build the static forecast run catalog from published map directories."""

from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[1]
MAPS_DIR = ROOT / "data" / "current" / "maps"
CATALOG_PATH = ROOT / "data" / "current" / "forecast-runs.json"
BJT = timezone(timedelta(hours=8))
MAX_RUNS = int(os.environ.get("IAPLACS_MAX_RUNS", "8"))
PRECIP_LEGEND = {
    "gradient": (
        "linear-gradient(90deg, "
        "#f7fbff 0 12.5%, #d6ecff 12.5% 25%, "
        "#8fc9ff 25% 37.5%, #3f8fc5 37.5% 50%, "
        "#31a354 50% 62.5%, #fdd049 62.5% 75%, "
        "#f46d43 75% 87.5%, #b2182b 87.5% 100%)"
    ),
    "ticks": ["0", "0.1", "2", "5", "10", "25", "50", "100+"],
}


RUN_DIR_RE = re.compile(r"^wrf_montage_(\d{8}_\d{2})$")
DETAIL_RE = re.compile(r"_combined_detail_p(\d{2})_")


def main() -> None:
    wrf_runs = build_wrf_runs()
    worknx_runs = build_worknx_runs()
    main_runs = merge_runs(worknx_runs + wrf_runs)
    shangrao_runs = wrf_runs
    catalog_published_at = latest_published_at(main_runs + shangrao_runs)
    catalog = {
        "schema_version": 1,
        "site": {"name": "IAP-LACS Forecast", "domain": "iaplacs.xyz"},
        "published_at": catalog_published_at,
        "services": {
            "main": {
                "title": "综合预报",
                "subtitle": "Multi-run forecast products",
                "note": "综合预报页面已接入服务器发布的 WORK_nx 综合图和 WRF 拼图目录；后续可继续加入其它模式、雷达或站点产品。",
                "latest_run": main_runs[0]["id"] if main_runs else None,
                "runs": main_runs,
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
        f"with {len(main_runs)} main run(s), {len(shangrao_runs)} shangrao run(s)"
    )


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


def build_worknx_runs() -> list[dict]:
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
        file_path = ROOT / fragment["file"].replace("./", "", 1)
        if not file_path.exists():
            continue

        run_id = fragment.get("run_prefix") or run_dir.name.replace("worknx_summary_", "")
        run_time = fragment.get("run_time") or parse_run_time(run_id).isoformat()
        generated_at = fragment.get("generated_at") or latest_mtime(run_dir).isoformat()
        valid_time = fragment.get("valid_time")
        byte_count = int(fragment.get("bytes") or file_path.stat().st_size)

        runs.append(
            {
                "id": run_id,
                "label": f"{format_run_label(run_time)} BJT",
                "run_time": run_time,
                "published_at": generated_at,
                "summary": "WORK_nx 综合降水预报拼图",
                "products": [build_worknx_product(run_id, fragment["file"], valid_time, byte_count, generated_at)],
            }
        )

    runs.sort(key=lambda item: item["run_time"], reverse=True)
    return runs[:MAX_RUNS]


def build_worknx_product(
    run_id: str, file_name: str, valid_time: Optional[str], byte_count: int, generated_at: str
) -> dict:
    return {
        "id": "worknx_precip_summary",
        "title": "WRF 综合降水预报 T01-T48",
        "category": "综合预报",
        "unit": "mm",
        "color": "#0f68c8",
        "description": "WORK_nx 生成的 WRF 全降水逐小时综合预报拼图。",
        "legend": PRECIP_LEGEND,
        "metrics": [
            {"label": "起报时次", "value": run_id.replace("_", " ") + " UTC"},
            {"label": "生成时间", "value": format_run_label(generated_at) + " BJT"},
            {"label": "图像大小", "value": human_size(byte_count)},
        ],
        "frames": [
            {
                "id": "summary_t01_t48",
                "lead": 48,
                "lead_label": "T01-T48",
                "valid_time": valid_time,
                "file": file_name,
                "bytes": byte_count,
            }
        ],
    }


def merge_runs(runs: list[dict]) -> list[dict]:
    merged: dict[str, dict] = {}
    for run in runs:
        current = merged.get(run["id"])
        if not current:
            merged[run["id"]] = run
            continue
        current.setdefault("products", []).extend(run.get("products", []))
        if run.get("published_at", "") > current.get("published_at", ""):
            current["published_at"] = run["published_at"]
    ordered = list(merged.values())
    ordered.sort(key=lambda item: item["run_time"], reverse=True)
    return ordered[:MAX_RUNS]


def build_wrf_product(run_id: str, frames: list[dict]) -> dict:
    return {
        "id": "wrf_rain_montage",
        "title": "WRF 逐小时降水拼图",
        "category": "模式预报",
        "unit": "mm",
        "color": "#0f68c8",
        "description": f"起报时次 {run_id}，包含总览图和分段细节图。",
        "legend": PRECIP_LEGEND,
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
        stem = path.stem
        if not stem.startswith(run_id + "_combined_"):
            continue
        key = stem
        if key.endswith("_grid"):
            key = key[: -len("_grid")]
        groups.setdefault(key, []).append(path)

    frames = []
    for key, candidates in sorted(groups.items(), key=frame_sort_key):
        chosen = min(candidates, key=lambda item: item.stat().st_size)
        frame = frame_meta(run_id, key)
        frame["file"] = "./" + chosen.relative_to(ROOT).as_posix()
        frame["bytes"] = chosen.stat().st_size
        frames.append(frame)
    return frames


def frame_sort_key(item: tuple[str, list[Path]]) -> tuple[int, int, str]:
    key = item[0]
    if "_combined_overview_" in key:
        return (0, 0, key)
    detail = DETAIL_RE.search(key)
    if detail:
        return (1, int(detail.group(1)), key)
    return (2, 0, key)


def frame_meta(run_id: str, key: str) -> dict:
    if "_combined_overview_" in key:
        return {
            "id": "overview",
            "lead": 48,
            "lead_label": "总览 6x6",
            "valid_label": "T13-T48 总览",
        }

    detail = DETAIL_RE.search(key)
    if detail:
        page = int(detail.group(1))
        start = 13 + (page - 1) * 12
        end = start + 11
        return {
            "id": f"detail_p{page:02d}",
            "lead": end,
            "lead_label": f"细节 {page}/3",
            "valid_label": f"T{start:02d}-T{end:02d}",
        }

    return {
        "id": key.replace(run_id + "_combined_", ""),
        "lead": 0,
        "lead_label": key.replace(run_id + "_combined_", ""),
        "valid_label": "组合图",
    }


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


def latest_published_at(runs: list[dict]) -> str:
    if not runs:
        return iso_now()
    return max(run["published_at"] for run in runs)


def latest_mtime(path: Path) -> datetime:
    latest = max(child.stat().st_mtime for child in path.iterdir() if child.is_file())
    return datetime.fromtimestamp(latest, tz=BJT)


def iso_now() -> str:
    return datetime.now(tz=BJT).replace(microsecond=0).isoformat()


if __name__ == "__main__":
    main()
