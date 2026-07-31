#!/usr/bin/env python3
"""Download BJT 08/20 CMA 24-hour precipitation observation maps."""

from __future__ import annotations

import argparse
import json
import re
import ssl
import urllib.request
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse


PAGE_URL = "https://www.asdf-bj.cn/publish/observations/24hour-precipitation.html"
IMAGE_HOST = "image.nmc.cn"
TIME_FORMAT = "%Y/%m/%d %H:%M"


class ObservationPageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.entries: list[tuple[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "div":
            return
        values = dict(attrs)
        timestamp = values.get("data-time1")
        image_url = values.get("data-img")
        if timestamp and image_url:
            self.entries.append((timestamp, image_url))


def fetch_bytes(url: str, context: ssl.SSLContext) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "IAP-LACS/1.0"})
    with urllib.request.urlopen(request, timeout=60, context=context) as response:
        return response.read()


def parse_entries(html: str) -> list[tuple[datetime, str]]:
    parser = ObservationPageParser()
    parser.feed(html)
    entries: list[tuple[datetime, str]] = []
    seen: set[datetime] = set()
    for timestamp, image_url in parser.entries:
        try:
            end = datetime.strptime(timestamp, TIME_FORMAT)
        except ValueError:
            continue
        if end.hour not in {8, 20} or end in seen:
            continue
        parsed = urlparse(image_url)
        if parsed.scheme != "https" or parsed.hostname != IMAGE_HOST:
            continue
        seen.add(end)
        entries.append((end, image_url))
    return sorted(entries, reverse=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--page-url", default=PAGE_URL)
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()
    if args.limit < 1:
        parser.error("--limit must be positive")

    context = ssl._create_unverified_context()
    page = fetch_bytes(args.page_url, context).decode("utf-8", errors="replace")
    entries = parse_entries(page)[: args.limit]
    if not entries:
        raise RuntimeError("no BJT 08/20 CMA 24-hour observation images found")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    kept: set[Path] = set()
    manifest = []
    for end, image_url in entries:
        stamp = end.strftime("%Y%m%d%H")
        suffix = Path(urlparse(image_url).path).suffix.lower() or ".jpg"
        output = args.output_dir / f"cma_24h_obs_{stamp}_BJT{suffix}"
        output.write_bytes(fetch_bytes(image_url, context))
        kept.add(output)
        manifest.append(
            {
                "end_bjt": end.strftime("%Y-%m-%d %H:%M"),
                "image": output.name,
                "source_url": image_url,
            }
        )

    for candidate in args.output_dir.glob("cma_24h_obs_*_BJT.*"):
        if candidate not in kept:
            candidate.unlink()
    (args.output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"downloaded {len(manifest)} CMA 24-hour observation map(s)")


if __name__ == "__main__":
    main()
