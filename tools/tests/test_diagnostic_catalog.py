import copy

import pytest
from check_diagnostic_catalog import verify_catalog


def test_catalog_requires_base_run_and_current_product():
    product = {
        "id": "xinjiang_visibility",
        "unit": "diagnostic",
        "frames": [{"individual_frames": [{"file": "a.png"}]}],
    }
    manifest = {"products": [product]}
    catalog = {"services": {"xinjiang": {"runs": []}}}
    with pytest.raises(ValueError, match="Base forecast"):
        verify_catalog(catalog, manifest, "workxj_summary", "20261031_00")
    run = {"id": "20261031_00", "products": []}
    catalog["services"]["xinjiang"]["runs"].append(run)
    with pytest.raises(ValueError, match="missing/stale"):
        verify_catalog(catalog, manifest, "workxj_summary", "20261031_00")
    run["products"] = [copy.deepcopy(product)]
    verify_catalog(catalog, manifest, "workxj_summary", "20261031_00")
    run["products"][0]["unit"] = "VIS_MIN"
    with pytest.raises(ValueError):
        verify_catalog(catalog, manifest, "workxj_summary", "20261031_00")
    run["products"][0] = copy.deepcopy(product)
    run["products"][0]["frames"][0]["individual_frames"] = []
    with pytest.raises(ValueError, match="hourly"):
        verify_catalog(catalog, manifest, "workxj_summary", "20261031_00")
