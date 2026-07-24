#!/usr/bin/env python3
"""Build the GitHub Pages catalog for forecast images relayed from Tianhe."""

from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_ROOT = Path(
    os.environ.get("IAPLACS_TIANHE_DATA_ROOT", ROOT / "data" / "tianhe" / "current")
)
MAPS_DIR = DATA_ROOT / "maps"
CATALOG_PATH = DATA_ROOT / "forecast-runs.json"
MAX_RUNS = int(os.environ.get("IAPLACS_MAX_RUNS", "5"))
BJT = timezone(timedelta(hours=8))
IMAGE_SUFFIXES = {".png", ".webp", ".jpg", ".jpeg"}


def main() -> None:
    ningxia_runs = scan_runs(
        "worknx_summary",
        build_ningxia_frames,
        build_ningxia_product,
        "天河 WORK_nx 宁夏降水预报",
    )
    airport_runs = scan_runs(
        "airport_yunnan",
        build_yunnan_frames,
        build_yunnan_product,
        "天河 WORK_yn 云南降水预报",
    )
    published_at = latest_published_at(ningxia_runs + airport_runs)
    catalog = {
        "schema_version": 1,
        "site": {"name": "IAP-LACS Forecast", "domain": "iaplacs.xyz"},
        "published_at": published_at,
        "note": "天河模型数据源。宁夏与云南图件由天河 WRF 结果生成并发布到 GitHub Pages。",
        "services": {
            "main": build_service(
                "机场气象服务",
                "Airport weather service",
                "天河 WORK_yn 云南机场降水产品。",
                airport_runs,
            ),
            "ningxia": build_service(
                "宁夏预报",
                "Ningxia forecast",
                "默认显示宁夏区域图，可切换同一时次的 WORK_nx 全国模拟图。",
                ningxia_runs,
            ),
            "airport": build_service(
                "机场气象服务",
                "Airport weather service",
                "天河 WORK_yn 云南区域 36 小时降水拼图，标注三个机场并给出逐机场峰值降水。",
                airport_runs,
            ),
            "shangrao": build_service(
                "上饶专项天气服务",
                "Shangrao service",
                "天河上饶产品生成链路已预留，等待首个完成时次后自动发布。",
                [],
            ),
        },
    }
    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CATALOG_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        f"wrote {CATALOG_PATH.relative_to(ROOT)} with "
        f"{len(ningxia_runs)} Ningxia and {len(airport_runs)} Yunnan run(s)"
    )


def scan_runs(prefix: str, frame_builder, product_builder, summary: str) -> list[dict]:
    if not MAPS_DIR.exists():
        return []

    runs = []
    for run_dir in MAPS_DIR.glob(f"{prefix}_*"):
        if not run_dir.is_dir():
            continue
        run_id = run_dir.name.removeprefix(prefix + "_")
        run_time = parse_run_time(run_id)
        if run_time is None:
            continue
        frames = frame_builder(run_dir)
        if not frames:
            continue
        published_at = latest_mtime(run_dir)
        runs.append(
            {
                "id": f"tianhe_{prefix}_{run_id}",
                "label": f"{run_time:%Y-%m-%d %H:%M} BJT",
                "run_time": run_time.isoformat(),
                "published_at": published_at.isoformat(),
                "summary": summary,
                "products": [product_builder(run_id, run_dir, frames, published_at)],
            }
        )
    runs.sort(key=lambda run: run["run_time"], reverse=True)
    return runs[:MAX_RUNS]


def build_service(title: str, subtitle: str, note: str, runs: list[dict]) -> dict:
    return {
        "title": title,
        "subtitle": subtitle,
        "note": note,
        "latest_run": runs[0]["id"] if runs else None,
        "runs": runs,
    }


def build_ningxia_product(
    run_id: str, _run_dir: Path, frames: list[dict], published_at: datetime
) -> dict:
    return {
        "id": "tianhe_ningxia_precip_series",
        "title": "降水预报图集",
        "category": "天河预报",
        "unit": "mm",
        "color": "#0f68c8",
        "description": "默认显示宁夏区域图，可切换 WORK_nx 全国模拟图。",
        "metrics": metrics(run_id, published_at, len(frames)),
        "frames": frames,
    }


def build_yunnan_product(
    run_id: str, run_dir: Path, frames: list[dict], published_at: datetime
) -> dict:
    product_metrics = metrics(run_id, published_at, len(frames))
    product_metrics.extend(yunnan_airport_metrics(run_dir))
    return {
        "id": "tianhe_airport_yunnan_precip_series",
        "title": "云南机场降水预报图集",
        "category": "天河预报",
        "unit": "mm",
        "color": "#0f68c8",
        "description": "WORK_yn 云南区域逐小时降水 6x6 拼图，标注德宏芒市、西双版纳嘎洒、普洱澜沧景迈三个机场位置。",
        "metrics": product_metrics,
        "frames": frames,
    }


def metrics(run_id: str, published_at: datetime, frame_count: int) -> list[dict]:
    return [
        {"label": "起报时次", "value": run_id.replace("_", " ") + " UTC"},
        {"label": "数据源", "value": "天河"},
        {"label": "生成时间", "value": published_at.strftime("%Y-%m-%d %H:%M BJT")},
        {"label": "图像数量", "value": str(frame_count)},
    ]


def build_frames(run_dir: Path) -> list[dict]:
    groups: dict[str, list[Path]] = {}
    for path in run_dir.iterdir():
        if path.suffix.lower() not in IMAGE_SUFFIXES:
            continue
        groups.setdefault(asset_stem(path), []).append(path)

    frames = []
    for stem, candidates in groups.items():
        main = choose_main(candidates)
        preview = choose_preview(candidates)
        if main is None:
            continue
        label, lead = frame_label(stem)
        frame = {
            "id": stem.lower().replace(" ", "_"),
            "lead": lead,
            "lead_label": label,
            "file": asset_url(main),
            "bytes": main.stat().st_size,
        }
        if preview and preview != main:
            frame["preview_file"] = asset_url(preview)
            frame["preview_bytes"] = preview.stat().st_size
        frames.append(frame)
    frames.sort(key=lambda frame: (frame["lead"], frame["lead_label"]))
    return frames


def build_ningxia_frames(run_dir: Path) -> list[dict]:
    groups: dict[str, list[Path]] = {}
    for path in run_dir.iterdir():
        if path.suffix.lower() not in IMAGE_SUFFIXES:
            continue
        groups.setdefault(asset_stem(path), []).append(path)

    frames = []
    for stem, candidates in groups.items():
        main = choose_main(candidates)
        preview = choose_preview(candidates)
        if main is None:
            continue
        lowered = stem.lower()
        if "ningxia" in lowered and "combined_overview" in lowered:
            frame_id, lead, label, valid_label = (
                "ningxia_region",
                0,
                "宁夏区域",
                "当前显示：宁夏区域",
            )
        elif "allrain" in lowered:
            frame_id, lead, label, valid_label = (
                "worknx_national",
                1,
                "全国",
                "当前显示：WORK_nx 全国模拟图",
            )
        else:
            continue
        frame = {
            "id": frame_id,
            "lead": lead,
            "lead_label": label,
            "valid_label": valid_label,
            "file": asset_url(main),
            "bytes": main.stat().st_size,
        }
        if preview and preview != main:
            frame["preview_file"] = asset_url(preview)
            frame["preview_bytes"] = preview.stat().st_size
        frames.append(frame)
    frames.sort(key=lambda frame: (frame["lead"], frame["file"]))
    return frames


def build_yunnan_frames(run_dir: Path) -> list[dict]:
    frames = build_frames(run_dir)
    self_drawn = [
        frame
        for frame in frames
        if "yunnanairports" in str(frame.get("file", "")).lower()
        and "combined_overview" in str(frame.get("file", "")).lower()
    ]
    if self_drawn:
        for frame in self_drawn:
            frame.update({"id": "overview", "lead": 0, "lead_label": "36小时拼图"})
        return self_drawn
    return frames


def asset_stem(path: Path) -> str:
    stem = path.stem
    return stem[: -len(".preview")] if stem.endswith(".preview") else stem


def choose_main(candidates: list[Path]) -> Path | None:
    normal = [path for path in candidates if not path.stem.endswith(".preview")]
    if not normal:
        return None
    return min(normal, key=lambda path: (asset_score(path), path.stat().st_size))


def choose_preview(candidates: list[Path]) -> Path | None:
    previews = [path for path in candidates if path.stem.endswith(".preview")]
    if previews:
        return min(previews, key=lambda path: path.stat().st_size)
    return choose_main(candidates)


def asset_score(path: Path) -> int:
    return {".webp": 0, ".png": 1, ".jpg": 2, ".jpeg": 2}.get(path.suffix.lower(), 3)


def frame_label(stem: str) -> tuple[str, int]:
    lowered = stem.lower()
    if "yunnanairports" in lowered and "combined_overview" in lowered:
        return "36小时拼图", 0
    if "yunnanlocal" in lowered:
        return "云南局地", 0
    if "yunnandomain" in lowered:
        return "模式全域", 1
    if "allrain" in lowered:
        return "逐小时降水 T01-T48", 0
    return "降水拼图", 0


def yunnan_airport_metrics(run_dir: Path) -> list[dict]:
    totals_path = run_dir / "airport_precip_totals.json"
    if not totals_path.exists():
        return []
    try:
        totals = json.loads(totals_path.read_text(encoding="utf-8")).get("airports", [])
    except (OSError, json.JSONDecodeError):
        return []

    by_id = {
        str(item.get("id")): item
        for item in totals
        if isinstance(item, dict) and item.get("id")
    }
    labels = (
        ("dehong_mangshi", "德宏芒市"),
        ("xishuangbanna_gasa", "西双版纳嘎洒"),
        ("puer_lancang_jingmai", "普洱澜沧景迈"),
    )
    metrics = []
    for airport_id, label in labels:
        item = by_id.get(airport_id, {})
        if item.get("status") == "outside_domain":
            value = "无网格覆盖"
        elif item.get("max_hourly_mm") is None:
            continue
        else:
            peak = float(item["max_hourly_mm"])
            when = item.get("max_hourly_time") or "时间未定"
            value = f"最大小时降水 {peak:.1f} mm {when}"
        metrics.append({"label": label, "value": value})
    return metrics


def asset_url(path: Path) -> str:
    return "./" + path.relative_to(ROOT).as_posix()


def parse_run_time(run_id: str) -> datetime | None:
    try:
        # WORK directory names and InitUTC filenames are UTC.  The website
        # labels every run in Beijing time, so convert rather than relabeling
        # the UTC clock value as BJT.
        return datetime.strptime(run_id, "%Y%m%d_%H").replace(
            tzinfo=timezone.utc
        ).astimezone(BJT)
    except ValueError:
        return None


def latest_mtime(path: Path) -> datetime:
    mtime = max(item.stat().st_mtime for item in path.iterdir() if item.is_file())
    return datetime.fromtimestamp(mtime, tz=BJT)


def latest_published_at(runs: list[dict]) -> str:
    if not runs:
        return datetime.now(tz=BJT).isoformat()
    return max(run["published_at"] for run in runs)


if __name__ == "__main__":
    main()
