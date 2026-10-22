"""Negative cases for cross-file validation; operate on in-memory data only."""
import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("project_data", ROOT / "scripts/tools/validate_project_data.py")
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


class ProjectDataTests(unittest.TestCase):
    def setUp(self):
        self.docs = {
            key: json.loads((ROOT / path).read_text(encoding="utf-8"))
            for key, path in validator.DOCUMENTS.items()
        }

    def test_current_data(self):
        self.assertEqual(validator.validate_data(self.docs), [])

    def test_unknown_route_enemy(self):
        self.docs["routes"]["routes"]["scrap_highway"]["enemy_mix"].append("missing_enemy")
        self.assertTrue(any("unknown id missing_enemy" in x for x in validator.validate_data(self.docs)))

    def test_missing_equipment_art(self):
        self.docs["items"]["equipment"]["rust_blade"]["icon_asset_id"] = "missing_icon"
        self.assertTrue(any("unknown asset missing_icon" in x for x in validator.validate_data(self.docs)))

    def test_duplicate_quest_id(self):
        quests = self.docs["quests"]["quests"]
        quests.append(copy.deepcopy(quests[0]))
        self.assertTrue(any("quests ids must be unique" in x for x in validator.validate_data(self.docs)))

    def test_negative_recipe_quantity(self):
        self.docs["recipes"]["recipes"][0]["cost"]["scrap"] = -1
        self.assertTrue(any("quantity must be a positive integer" in x for x in validator.validate_data(self.docs)))

    def test_unsupported_objective_counter(self):
        self.docs["quests"]["quests"][0]["objectives"][0]["counter"] = "typo_boss"
        self.assertTrue(any("unsupported objective counter" in x for x in validator.validate_data(self.docs)))

    def test_malformed_nested_structure(self):
        self.docs["items"]["equipment"]["rust_blade"] = []
        self.assertTrue(any("must be an object" in x for x in validator.validate_data(self.docs)))

    def test_footprint_outside_source_canvas(self):
        self.docs["art"]["assets"]["prop_highway_bus"]["collision_footprint"] = [0.8, 0.8, 0.4, 0.4]
        self.assertTrue(any("collision_footprint" in x for x in validator.validate_data(self.docs)))


if __name__ == "__main__":
    unittest.main()
