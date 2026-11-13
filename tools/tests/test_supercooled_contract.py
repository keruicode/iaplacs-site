"""Publication completeness, domain selection and catalog preservation tests."""

import copy
import json

import build_forecast_catalog as catalog
import pytest
from check_diagnostic_catalog import verify_catalog
from supercooled_contract import PROFILES, TITLES, choose_sources, validate_manifest


def bundle(root, profile="ningxia"):
    root.mkdir(parents=True, exist_ok=True)
    products = []
    for kind, title in TITLES.items():
        frames = []
        for area in ("regional", "wide"):
            filename = f"{kind}_{area}.png"
            (root / filename).write_bytes(b"test-only-image")
            frames.append(
                {
                    "id": area,
                    "file": filename,
                    "individual_frames": [
                        {"file": filename, "valid_time": "2026-11-13T07:00:00+00:00"}
                    ],
                }
            )
        products.append(
            {
                "id": f"{PROFILES[profile]['prefix']}_supercooled_{kind}",
                "title": title,
                "unit": "g/m²",
                "frames": frames,
            }
        )
    return {
        "profile": profile,
        "publication_ready": True,
        "products": products,
        "generated_at": "2026-11-13T16:00:00+08:00",
    }


def test_domain_selection(tmp_path):
    d01 = tmp_path / "wrfout_d01_2026-11-12_18:00:00"
    with pytest.raises(ValueError):
        choose_sources(d01)
    d01.touch()
    assert choose_sources(d01) == {"regional": d01, "wide": d01}
    d02 = tmp_path / "wrfout_d02_2026-11-12_18:00:00"
    d02.touch()  # Even empty d02 must be validated, not silently skipped.
    assert choose_sources(d01) == {"regional": d02, "wide": d01}


@pytest.mark.parametrize("profile", PROFILES)
def test_contract_requires_both_products_and_areas(tmp_path, profile):
    manifest = bundle(tmp_path, profile)
    validate_manifest(manifest, tmp_path)
    manifest["products"][1]["frames"].pop()
    with pytest.raises(ValueError, match="Regional"):
        validate_manifest(manifest, tmp_path)


def test_missing_image_and_changed_time(tmp_path):
    manifest = bundle(tmp_path)
    frame = manifest["products"][1]["frames"][1]
    frame["individual_frames"][0]["valid_time"] = "2026-11-13T08:00:00+00:00"
    with pytest.raises(ValueError, match="share times"):
        validate_manifest(manifest, tmp_path)
    manifest = bundle(tmp_path)
    (tmp_path / "cloud_regional.png").unlink()
    with pytest.raises(ValueError, match="Missing image"):
        validate_manifest(manifest, tmp_path)


def test_preview_cannot_publish(tmp_path):
    manifest = bundle(tmp_path)
    manifest["publication_ready"] = False
    validate_manifest(manifest, tmp_path, require_ready=False)
    with pytest.raises(ValueError, match="Preview"):
        validate_manifest(manifest, tmp_path)


def test_path_escape(tmp_path):
    manifest = bundle(tmp_path)
    manifest["products"][0]["frames"][0]["file"] = "../escape.png"
    with pytest.raises(ValueError, match="escapes"):
        validate_manifest(manifest, tmp_path)


@pytest.mark.parametrize("profile", PROFILES)
def test_catalog_merge_preserves_pair_after_staging_cleanup(
    tmp_path, monkeypatch, profile
):
    monkeypatch.setattr(catalog, "ROOT", tmp_path)
    run_id = "20261112_18"
    service = PROFILES[profile]["prefix"]
    family = PROFILES[profile]["family"]
    directory = tmp_path / "data/current/maps" / f"{family}_{run_id}"
    manifest = bundle(directory / "supercooled", profile)
    (directory / "supercooled/production_manifest.json").write_text(
        json.dumps(manifest), encoding="utf-8"
    )
    public_id = f"airport_yunnan_{run_id}" if service == "airport" else run_id
    base = {"id": public_id, "run_time": "2026-11-12T18:00:00+00:00", "products": []}
    merged = catalog.merge_existing_runs([base], {}, service)
    assert len(merged[0]["products"]) == 2
    public = {"services": {service: {"runs": merged}}}
    verify_catalog(public, manifest, family, run_id)
    (directory / "supercooled/production_manifest.json").unlink()
    fresh = copy.deepcopy(base)
    fresh["products"] = []
    rebuilt = catalog.merge_existing_runs([fresh], public, service)
    assert {p["id"] for p in rebuilt[0]["products"]} == {
        p["id"] for p in manifest["products"]
    }
    merged[0]["products"][0]["frames"][0]["file"] = "stale-generation.png"
    with pytest.raises(ValueError, match="generation"):
        verify_catalog(public, manifest, family, run_id)
