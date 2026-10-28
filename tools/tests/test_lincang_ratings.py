"""Exercise rating lifecycle without touching production OSS."""

import importlib.util
import io
import json
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch


class LincangRatingsTest(unittest.TestCase):
    def test_catalog_describes_only_present_airports(self):
        from tools.build_forecast_catalog import build_yunnan_airport_product

        fragment = {"airport_precip_totals": [{"id": "dehong_mangshi"}]}
        product = build_yunnan_airport_product(
            "20261027_06", [], "2026-10-28T04:00:00Z", fragment
        )
        self.assertNotIn("临沧", product["description"])
        fragment["airport_precip_totals"].append({"id": "lincang_boshang"})
        product = build_yunnan_airport_product(
            "20261027_06", [], "2026-10-28T04:00:00Z", fragment
        )
        self.assertIn("临沧机场", product["description"])

    def test_rating_change_cancel_and_legacy_vote(self):
        records = {}
        bucket = types.SimpleNamespace(
            object_exists=lambda key: key in records,
            delete_object=lambda key: records.pop(key),
            put_object=lambda key, data, **kwargs: records.update({key: data}),
            get_object=lambda key: io.BytesIO(records[key].encode()),
        )
        oss = types.SimpleNamespace(
            ObjectIterator=lambda bucket, prefix: [
                types.SimpleNamespace(key=key)
                for key in sorted(records)
                if key.startswith(prefix)
            ]
        )
        path = Path(__file__).resolve().parents[2] / "cloud/airport-ratings-fc/index.py"
        spec = importlib.util.spec_from_file_location("rating_test_module", path)
        module = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {"oss2": oss}):
            spec.loader.exec_module(module)
        module._bucket = lambda context: bucket

        def vote(airport, rating):
            response = module.handler(
                {
                    "headers": {"Origin": "https://iaplacs.xyz"},
                    "requestContext": {"http": {"method": "POST"}},
                    "body": json.dumps(
                        {
                            "source_id": "huan",
                            "run_id": "airport_yunnan_20261027_06",
                            "client_id": "local_test_client_12345",
                            "airport_id": airport,
                            "rating": rating,
                        }
                    ),
                },
                None,
            )
            self.assertEqual(response["statusCode"], 200)
            return json.loads(response["body"])["ratings"]

        vote("dehong_mangshi", "accurate")
        counts = vote("lincang_boshang", "accurate")
        self.assertEqual(counts["lincang_boshang"]["accurate"], 1)
        counts = vote("lincang_boshang", "fair")
        self.assertEqual(counts["lincang_boshang"]["accurate"], 0)
        self.assertEqual(counts["lincang_boshang"]["fair"], 1)
        counts = vote("lincang_boshang", None)
        self.assertEqual(counts["lincang_boshang"]["total"], 0)
        self.assertEqual(counts["dehong_mangshi"]["accurate"], 1)
        self.assertEqual(len(counts), 4)


if __name__ == "__main__":
    unittest.main()
