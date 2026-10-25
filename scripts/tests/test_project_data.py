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

    def test_story_discovery_must_reference_a_real_event(self):
        objective = next(
            row for row in self.docs["quests"]["quests"][0]["objectives"]
            if row["type"] == "discover"
        )
        objective["event"] = "missing_story_event"
        self.assertTrue(any("discovery must reference a story event" in x for x in validator.validate_data(self.docs)))

    def test_story_discovery_route_must_match_event_and_quest(self):
        objective = next(
            row for row in self.docs["quests"]["quests"][0]["objectives"]
            if row["type"] == "discover"
        )
        objective["route"] = "toxic_marsh"
        self.assertTrue(any("discovery route must match" in x for x in validator.validate_data(self.docs)))

    def test_story_event_route_is_bound_to_its_campaign_route(self):
        event = next(
            row for row in self.docs["events"]["events"]
            if row["id"] == "story_scrap_manifest"
        )
        event["route"] = "toxic_marsh"
        self.assertTrue(any("event is assigned to the wrong route" in x for x in validator.validate_data(self.docs)))

    def test_story_event_cannot_grant_a_direct_reward(self):
        event = next(
            row for row in self.docs["events"]["events"]
            if row["id"] == "story_scrap_manifest"
        )
        event["reward"] = {"ammo": 1}
        self.assertTrue(any("story events must not grant a direct reward" in x for x in validator.validate_data(self.docs)))

    def test_factory_blackbox_spells_out_the_water_allocation(self):
        event = next(
            row for row in self.docs["events"]["events"]
            if row["id"] == "story_factory_blackbox"
        )
        self.assertIn("處理水先供地下避難所", event["description"])
        self.assertIn("外圍住戶暫停供水", event["description"])
        self.assertIn("複測後再恢復", event["description"])
        self.assertNotIn("保護壓力", event["description"])

    def test_story_chapters_must_be_unique_and_complete(self):
        event = next(
            row for row in self.docs["events"]["events"]
            if row["id"] == "story_facility_memory"
        )
        event["chapter"] = 5
        self.assertTrue(any("chapters must cover 1 through 6 exactly" in x for x in validator.validate_data(self.docs)))

    def test_story_prerequisite_reference_must_exist(self):
        quest = next(
            row for row in self.docs["quests"]["quests"]
            if row["id"] == "facility_memory"
        )
        quest["prerequisites"] = ["missing_quest"]
        self.assertTrue(any("unknown prerequisite missing_quest" in x for x in validator.validate_data(self.docs)))

    def test_story_prerequisites_must_be_acyclic(self):
        metropolis = next(
            row for row in self.docs["quests"]["quests"]
            if row["id"] == "metropolis_archive"
        )
        metropolis["prerequisites"] = ["facility_memory"]
        self.assertTrue(any("prerequisites contain a cycle" in x for x in validator.validate_data(self.docs)))

    def test_outer_campaign_quests_remain_open_order(self):
        quests = {row["id"]: row for row in self.docs["quests"]["quests"]}
        outer_quests = ["clear_scrap_route", "toxic_sample", "crystal_scar_recon", "old_factory_core"]
        for quest_id in outer_quests:
            self.assertEqual(quests[quest_id].get("prerequisites", []), [])
        self.assertEqual(quests["metropolis_archive"]["prerequisites"], outer_quests)
        self.assertEqual(quests["facility_memory"]["prerequisites"], ["metropolis_archive"])

    def test_order_free_story_followups_do_not_prescribe_a_sequence(self):
        events = {row["id"]: row for row in self.docs["events"]["events"]}
        for event_id in ["story_scrap_manifest", "story_marsh_ledger", "story_crystal_echo"]:
            self.assertNotRegex(events[event_id]["follow_up"], r"先完成|交付委託後|備妥防護後")

    def test_chapter_two_samples_do_not_reveal_optional_ledger_findings(self):
        quests = {row["id"]: row for row in self.docs["quests"]["quests"]}
        quest = quests["toxic_sample"]
        sample_text = "\n".join([
            quest["story_step"],
            quest["description"],
            quest["completion_text"],
            quest["campaign_completion_text"],
            json.dumps(quest["campaign_outings"], ensure_ascii=False),
        ])
        for claim in ["處理紀錄顯示", "地下避難所", "留給避難所", "外圍家庭被隔離斷水", "隔離外線", "複測日期"]:
            self.assertNotIn(claim, sample_text)
        self.assertIn("帳本可補查", quest["story_step"])
        self.assertIn("不影響委託交付", quest["description"])

        ledger = next(row for row in self.docs["events"]["events"] if row["id"] == "story_marsh_ledger")
        discovery = next(
            row for row in quest["objectives"]
            if row["type"] == "discover" and row["event"] == ledger["id"]
        )
        self.assertTrue(discovery["optional"])
        self.assertIn("地下避難所", ledger["revelation"])
        self.assertIn("外圍管線因而被隔離", ledger["revelation"])
        self.assertNotIn("民用訊號轉送單", quest["description"])
        self.assertIn("民用訊號轉送單", quest["completion_discovery_text"])

        claim_fragments = ["留給避難所", "隔離外線", "沒寫複測日", "沒有複測日期", "複測日期空白"]
        optional_ledger_briefings = []
        for npc in self.docs["npcs"]["npcs"]:
            for line in npc.get("story_lines", []):
                discusses_chapter_two = (
                    line.get("requires_campaign_completed") == "toxic_sample"
                    or line.get("requires_active") == "toxic_sample"
                )
                if discusses_chapter_two:
                    self.assertFalse(any(claim in line["text"] for claim in claim_fragments), line["text"])
                    if "選讀線索" in line["text"]:
                        optional_ledger_briefings.append(line["text"])

        self.assertTrue(any("可補查外圍支線為何被關" in text for text in optional_ledger_briefings))
        self.assertTrue(any("沒找到也能交付委託" in text for text in optional_ledger_briefings))

    def test_free_order_quest_copy_does_not_assume_prior_optional_discoveries(self):
        quests = {row["id"]: row for row in self.docs["quests"]["quests"]}
        chapter_three = quests["crystal_scar_recon"]
        chapter_four = quests["old_factory_core"]
        chapter_three_copy = "\n".join([chapter_three["story_step"], chapter_three["description"]])
        chapter_four_copy = "\n".join([chapter_four["story_step"], chapter_four["description"]])

        self.assertNotIn("泵站留下水被送往何處", chapter_three_copy)
        self.assertNotIn("把處理水留給避難所", chapter_three_copy)
        self.assertNotIn("並指出當年工廠封門警報的來源", chapter_three_copy)
        self.assertNotIn("裂隙回波指向舊工廠", chapter_four_copy)
        self.assertNotIn("留給地下避難所", chapter_four_copy)

    def test_outer_chapter_debrief_copy_respects_free_order(self):
        quests = {row["id"]: row for row in self.docs["quests"]["quests"]}
        chapter_three = quests["crystal_scar_recon"]
        chapter_four = quests["old_factory_core"]

        chapter_three_copy = "\n".join([
            chapter_three[field]
            for field in [
                "story_step", "description", "completion_text", "campaign_completion_text",
                "completion_discovery_text", "preparation_hint",
            ]
        ] + [outing["return_text"] for outing in chapter_three["campaign_outings"]])
        for stale_claim in [
            "追查警報來源", "警報來源仍待查證", "警報來源仍在工廠",
            "需與工廠紀錄交叉核對", "封線者與重開條件，都得跟那裡的命令核對",
            "裂隙回波可留作後續核對",
        ]:
            self.assertNotIn(stale_claim, chapter_three_copy)
        self.assertIn("依 [J] 顯示的下一步", chapter_three["preparation_hint"])
        self.assertIn("已完成的調查不必重走", chapter_three["preparation_hint"])

        chapter_four_copy = "\n".join([
            chapter_four[field]
            for field in [
                "completion_text", "campaign_completion_text", "completion_discovery_text",
                "preparation_hint",
            ]
        ] + [outing["return_text"] for outing in chapter_four["campaign_outings"]])
        for stale_claim in [
            "查都心的戶號吧", "四份外圍委託結案後即可承接檔案委託",
            "下一步要把受影響住戶從總數還原成名冊",
        ]:
            self.assertNotIn(stale_claim, chapter_four_copy)
        self.assertIn("都心檔案要求前四份外圍主線全部結案", chapter_four["preparation_hint"])
        self.assertIn("當前接續步驟以 [J] 顯示為準", chapter_four["preparation_hint"])

    def test_mandatory_story_discovery_is_explicit(self):
        quest = next(
            row for row in self.docs["quests"]["quests"]
            if row["id"] == "facility_memory"
        )
        objective = next(row for row in quest["objectives"] if row["type"] == "discover")
        objective["optional"] = True
        self.assertTrue(any("optional flag does not match campaign contract" in x for x in validator.validate_data(self.docs)))

    def test_expanded_routes_cannot_shrink_to_the_original_map(self):
        self.docs["routes"]["routes"]["scrap_highway"]["size_tiles"] = [180, 140]
        self.assertTrue(any("size_tiles must exceed" in x for x in validator.validate_data(self.docs)))

    def test_exploration_point_event_ids_must_be_unique_within_a_route(self):
        points = self.docs["routes"]["routes"]["scrap_highway"]["exploration_points"]
        points[1]["event"] = points[0]["event"]
        self.assertTrue(any("point event ids must be unique" in x for x in validator.validate_data(self.docs)))

    def test_exploration_points_cannot_reuse_story_events(self):
        self.docs["routes"]["routes"]["scrap_highway"]["exploration_points"][0]["event"] = "story_scrap_manifest"
        self.assertTrue(any("reference a non-story event" in x for x in validator.validate_data(self.docs)))

    def test_exploration_rewards_require_known_items_and_positive_amounts(self):
        self.docs["routes"]["routes"]["scrap_highway"]["exploration_points"][0]["reward"] = {"missing_reward": -1}
        errors = validator.validate_data(self.docs)
        self.assertTrue(any("unknown item missing_reward" in x for x in errors))
        self.assertTrue(any("quantity must be a positive integer" in x for x in errors))

    def test_exploration_guards_cannot_be_bosses(self):
        self.docs["routes"]["routes"]["scrap_highway"]["exploration_points"][0]["guards"][0] = "waste_titan"
        self.assertTrue(any("known non-boss enemy" in x for x in validator.validate_data(self.docs)))

    def test_exploration_paths_reject_zero_length_and_unreachable_rewards(self):
        route = self.docs["routes"]["routes"]["scrap_highway"]
        route["exploration_paths"][0][1] = copy.deepcopy(route["exploration_paths"][0][0])
        route["exploration_points"][0]["position"] = [0.31, 0.31]
        errors = validator.validate_data(self.docs)
        self.assertTrue(any("segments must be nonzero" in x for x in errors))
        self.assertTrue(any("reachable from an authored path" in x for x in errors))

    def test_exploration_reward_can_lie_on_a_diagonal_path(self):
        route = self.docs["routes"]["routes"]["scrap_highway"]
        route["exploration_paths"].append([[0.2, 0.2], [0.4, 0.4]])
        route["exploration_points"][0]["position"] = [0.3, 0.3]
        self.assertEqual(validator.validate_data(self.docs), [])

    def test_directional_rectangles_must_fit_the_recorded_png(self):
        self.docs["art"]["assets"]["player_r17"]["directional_rects"][0] = [1700, 0, 500, 500]
        self.assertTrue(any("source rectangle 0 must fit" in x for x in validator.validate_data(self.docs)))

    def test_directional_views_require_eight_distinct_rectangles(self):
        asset = self.docs["art"]["assets"]["player_r17"]
        asset["directional_rects"][1] = copy.deepcopy(asset["directional_rects"][0])
        errors = validator.validate_data(self.docs)
        self.assertTrue(any("source rectangles must be unique" in x for x in errors))
        asset["directional_rects"].pop()
        self.assertTrue(any("exactly eight source rectangles" in x for x in validator.validate_data(self.docs)))

    def test_directional_feet_stay_inside_their_source_rectangle(self):
        self.docs["art"]["assets"]["player_r17"]["directional_feet"][0] = [0, 0]
        self.assertTrue(any("foot anchor 0 must fit" in x for x in validator.validate_data(self.docs)))

    def test_runtime_directional_files_match_the_current_metadata(self):
        self.assertEqual(validator.validate_directional_files(self.docs["art"]["assets"], ROOT), [])

    def test_directional_runtime_path_must_exist_inside_assets(self):
        asset = self.docs["art"]["assets"]["player_r17"]
        asset["directional_body_path"] = "res://assets/sprites/player/missing_turnaround.png"
        self.assertTrue(any("cannot read runtime PNG" in x for x in validator.validate_directional_files(self.docs["art"]["assets"], ROOT)))
        asset["directional_body_path"] = "res://assets/../../project.godot"
        self.assertTrue(any("remain inside assets" in x for x in validator.validate_directional_files(self.docs["art"]["assets"], ROOT)))

    def test_directional_runtime_dimensions_and_hash_are_checked_from_png_bytes(self):
        asset = self.docs["art"]["assets"]["player_r17"]
        asset["directional_dimensions"] = [1, 1]
        asset["directional_source_sha256"] = "0" * 64
        errors = validator.validate_directional_files(self.docs["art"]["assets"], ROOT)
        self.assertTrue(any("PNG dimensions disagree" in x for x in errors))
        self.assertTrue(any("PNG bytes disagree" in x for x in errors))


if __name__ == "__main__":
    unittest.main()
