import json

from render_regional_visibility import main, prefix_frame, retire_flat_assets


def test_frame_paths_preserve_original():
    frame = {"file": "all.png", "individual_frames": [{"file": "one.png"}]}
    result = prefix_frame(frame, "wide")
    assert result["file"] == "wide/all.png"
    assert result["individual_frames"][0]["file"] == "wide/one.png"
    assert frame["file"] == "all.png"


def test_retirement_only_owned_flat_assets(tmp_path):
    for name in ("all.png", "all.webp", "untouched.png"):
        (tmp_path / name).touch()
    previous = {"products": [{"frames": [{"file": "all.png"}]}]}
    retire_flat_assets(tmp_path, previous)
    assert not (tmp_path / "all.png").exists()
    assert not (tmp_path / "all.webp").exists()
    assert (tmp_path / "untouched.png").exists()


def test_both_domains_and_cache(tmp_path, monkeypatch):
    import render_regional_visibility as module

    calls = []

    def select(path, profile, *, prefer_nested=True):
        return (
            path.with_name("wrfout_d02_case") if prefer_nested else path
        ), "diagnostic"

    def render(arguments):
        area = arguments[arguments.index("--area") + 1]
        calls.append((area, arguments[arguments.index("--domain") + 1]))
        out = module.Path(arguments[arguments.index("--output") + 1])
        out.mkdir(parents=True, exist_ok=True)
        (out / "all.png").touch()
        (out / "one.png").touch()
        data = {
            "source_signature": {"area": area},
            "source_variable": "DIAGNOSTIC_CLOUD_VIS",
            "run_time": "2026-10-31T00:00:00Z",
            "generated_at": "2026-10-31T12:00:00Z",
            "products": [
                {
                    "id": "airport_visibility",
                    "unit": "diagnostic",
                    "frames": [
                        {"file": "all.png", "individual_frames": [{"file": "one.png"}]}
                    ],
                }
            ],
        }
        (out / "production_manifest.json").write_text(json.dumps(data))
        return 0

    monkeypatch.setattr(module, "select_source", select)
    monkeypatch.setattr(module, "render_cloud", render)
    args = [
        "--input",
        str(tmp_path / "wrfout_d02_case"),
        "--output",
        str(tmp_path / "result"),
        "--profile",
        "yunnan",
        "--province-shp",
        "fixture.shp",
    ]
    assert main(args) == 0
    assert calls == [("regional", "d02"), ("wide", "d01")]
    p = tmp_path / "result/production_manifest.json"
    before = p.read_bytes()
    assert len(json.loads(before)["products"][0]["frames"]) == 2
    assert main(args) == 0
    assert p.read_bytes() == before
