"""Pure unit checks for QA path and command safety helpers."""

import importlib.util
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("run_qa.py")
SPEC = importlib.util.spec_from_file_location("run_qa_under_test", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
run_qa = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(run_qa)


class QaHelperTests(unittest.TestCase):
    def test_local_codebase_index_is_excluded_from_qa_mirrors(self):
        ignored = run_qa.ignore_copy(
            str(MODULE_PATH.parents[2]),
            [".codebase-memory", "assets", "scripts"],
        )
        self.assertIn(".codebase-memory", ignored)

    def test_docs_pngs_and_import_sidecars_are_excluded_but_runtime_pngs_are_kept(self):
        docs_ignored = run_qa.ignore_copy(
            str(run_qa.PROJECT_ROOT / "docs" / "captures"),
            ["review.png", "review.png.import", "SCREEN_STATE_MATRIX.md"],
        )
        runtime_ignored = run_qa.ignore_copy(
            str(run_qa.PROJECT_ROOT / "assets"),
            ["recycler_tileset.png", "recycler_tileset.png.import"],
        )

        self.assertEqual(docs_ignored, {"review.png", "review.png.import"})
        self.assertEqual(runtime_ignored, set())

    def test_output_inside_project_is_rejected(self):
        root = Path("C:/workspace/game").resolve()
        with self.assertRaisesRegex(ValueError, "outside the project"):
            run_qa.resolve_output_root(str(root / "reports"), root)

    def test_output_sibling_is_accepted(self):
        root = Path("C:/workspace/game").resolve()
        output = run_qa.resolve_output_root(str(root.parent / "qa-output"), root)
        self.assertEqual(output, (root.parent / "qa-output").resolve())

    def test_custom_user_directory_is_added_to_application_section(self):
        source = "config_version=5\n\n[application]\nconfig/name=\"Example\"\n\n[rendering]\n"
        patched = run_qa.render_user_dir_config(source, "run-123")
        self.assertIn('config/use_custom_user_dir=true', patched)
        self.assertIn('config/custom_user_dir_name="FirstGame-QA-run-123"', patched)
        self.assertLess(patched.index("[application]"), patched.index("[rendering]"))

    def test_existing_custom_directory_setting_is_replaced(self):
        source = "[application]\nconfig/use_custom_user_dir=false\nconfig/custom_user_dir_name=\"old\"\n"
        patched = run_qa.render_user_dir_config(source, "new")
        self.assertEqual(patched.count("config/use_custom_user_dir="), 1)
        self.assertEqual(patched.count("config/custom_user_dir_name="), 1)
        self.assertIn('config/custom_user_dir_name="FirstGame-QA-new"', patched)

    def test_godot_user_arguments_follow_separator(self):
        command = run_qa.build_godot_command(
            "godot", Path("C:/workspace/mirror"), "res://scenes/tests/Runner.tscn",
            user_args=("--qa-output", "C:/temp/run"),
        )
        separator = command.index("--")
        self.assertEqual(command[separator + 1:], ["--qa-output", "C:/temp/run"])
        self.assertIn("--headless", command[:separator])

    def test_gui_command_does_not_force_headless_mode(self):
        command = run_qa.build_godot_command("godot", Path("C:/workspace/mirror"), headless=False)
        self.assertNotIn("--headless", command)

    def test_visual_resolution_can_select_the_full_narrow_screen_profile(self):
        args = run_qa.parser().parse_args(["--profile", "visual", "--visual-resolution", "800x600"])
        self.assertEqual(args.visual_resolution, "800x600")

    def test_visual_resolution_rejects_unreviewed_profiles(self):
        with self.assertRaises(SystemExit):
            run_qa.parser().parse_args(["--profile", "visual", "--visual-resolution", "640x480"])

    def test_godot_error_log_detection(self):
        lines = run_qa.extract_godot_errors(
            "SCRIPT ERROR: Parse Error: missing method\nordinary startup message",
            "ERROR: Failed to load resource: res://missing.tscn",
        )
        self.assertEqual(len(lines), 2)

    def test_log_filename_is_safe(self):
        self.assertEqual(run_qa.safe_name("Visual review / startup"), "visual-review-startup")

    def test_only_the_project_bound_godot_version_is_supported(self):
        self.assertTrue(run_qa.supports_godot_version("4.6.3.stable.official.7d41c59c4"))
        self.assertFalse(run_qa.supports_godot_version("4.6.4.stable.official.123456"))
        self.assertFalse(run_qa.supports_godot_version("4.6.3.rc1"))

    def test_story_visual_review_captures_are_required(self):
        required = {
            "story_journal.png",
            "story_journal_1024x768.png",
            "story_discovery.png",
            "story_ending.png",
            "route_ruined_metropolis.png",
            "route_underground_facility.png",
            "story_site_scrap_highway.png",
            "story_site_toxic_marsh.png",
            "story_site_crystal_scar.png",
            "story_site_old_factory.png",
            "story_site_ruined_metropolis.png",
            "story_site_underground_facility.png",
        }
        self.assertTrue(required.issubset(set(run_qa.VISUAL_IMAGES)))

    def test_expansion_visual_review_captures_are_required(self):
        self.assertTrue({
            "world_atlas.png", "world_atlas_1024x768.png", "exploration_scrap.png",
            "exploration_crystal.png", "scene_entrance.png",
        }.issubset(set(run_qa.VISUAL_IMAGES)))

    def test_cold_narrow_title_capture_is_required_by_visual_profile(self):
        self.assertIn("cold_narrow/main_title_cold_800x600.png", run_qa.VISUAL_IMAGES)
        runner_path = MODULE_PATH.parents[1] / "tests" / "VisualReviewRunner.gd"
        runner_source = runner_path.read_text(encoding="utf-8")
        self.assertIn('"main_title_cold_800x600"', runner_source)
        self.assertIn('"--qa-cold-narrow"', runner_source)

    def test_new_game_existing_save_confirmation_capture_is_required(self):
        self.assertIn("new_game_existing_save_confirmation.png", run_qa.VISUAL_IMAGES)
        runner_path = MODULE_PATH.parents[1] / "tests" / "VisualReviewRunner.gd"
        runner_source = runner_path.read_text(encoding="utf-8")
        required_list = re.search(r"const REQUIRED_CAPTURES := \[(.*?)\n\]", runner_source, re.S)
        self.assertIsNotNone(required_list)
        registered_captures = re.findall(r'"([^"\n]+)"', required_list.group(1))
        self.assertIn("new_game_existing_save_confirmation", registered_captures)

    def test_visual_capture_coverage_accepts_nested_cold_start_image(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            visual_dir = Path(temporary_directory)
            cold_dir = visual_dir / "cold_narrow"
            cold_dir.mkdir()
            (cold_dir / "main_title_cold_800x600.png").write_bytes(b"png")
            missing = run_qa.missing_visual_images(
                visual_dir,
                ("cold_narrow/main_title_cold_800x600.png",),
            )
        self.assertEqual(missing, [])

    def test_visual_capture_names_are_copied_into_the_typed_array_safely(self):
        runner_path = MODULE_PATH.parents[1] / "tests" / "VisualReviewRunner.gd"
        runner_source = runner_path.read_text(encoding="utf-8")
        self.assertIn("_required_capture_names.assign(COLD_NARROW_REQUIRED_CAPTURES)", runner_source)
        self.assertIn("_required_capture_names.assign(REQUIRED_CAPTURES)", runner_source)
        self.assertNotRegex(runner_source, r"_required_capture_names\s*=\s*(?:COLD_NARROW_REQUIRED_CAPTURES|REQUIRED_CAPTURES)\.duplicate\(\)")

    def test_death_recovery_visual_captures_are_required(self):
        captures = {"death", "death_1024x768", "death_resize_800x600"}
        expected_images = {f"{name}.png" for name in captures}
        self.assertTrue(expected_images.issubset(set(run_qa.VISUAL_IMAGES)))

        runner_path = MODULE_PATH.parents[1] / "tests" / "VisualReviewRunner.gd"
        runner_source = runner_path.read_text(encoding="utf-8")
        required_list = re.search(r"const REQUIRED_CAPTURES := \[(.*?)\n\]", runner_source, re.S)
        self.assertIsNotNone(required_list)
        registered_captures = re.findall(r'"([^"\n]+)"', required_list.group(1))
        self.assertTrue(captures.issubset(set(registered_captures)))
        self.assertEqual(registered_captures.count("death_1024x768"), 1)

    def test_hub_and_pause_feedback_visual_captures_are_registered(self):
        captures = {
            "pause_resize_800x600",
            "quest_progress_1024x768",
            "contract", "contract_1024x768",
            "contract_resize_800x600", "contract_open_800x600", "contract_resize_960x600",
            "workshop", "workshop_1024x768",
            "terminal", "terminal_1024x768",
            "pause_save_success", "pause_save_success_1024x768",
            "pause_save_failure", "pause_save_failure_1024x768",
            "pause_load_pending_presentation", "pause_load_pending_presentation_1024x768",
            "pause_load_failure", "pause_load_failure_1024x768",
        }
        expected_images = {f"{name}.png" for name in captures}
        self.assertTrue(expected_images.issubset(set(run_qa.VISUAL_IMAGES)))

        runner_path = MODULE_PATH.parents[1] / "tests" / "VisualReviewRunner.gd"
        runner_source = runner_path.read_text(encoding="utf-8")
        required_list = re.search(r"const REQUIRED_CAPTURES := \[(.*?)\n\]", runner_source, re.S)
        self.assertIsNotNone(required_list)
        registered_captures = set(re.findall(r'"([^"\n]+)"', required_list.group(1)))
        self.assertTrue(captures.issubset(registered_captures))

    def test_draft_and_campaign_choice_visual_captures_are_required(self):
        captures = {
            "expedition_draft", "expedition_draft_960x768",
            "campaign_choice", "campaign_choice_960x768",
        }
        expected_images = {f"{name}.png" for name in captures}
        self.assertTrue(expected_images.issubset(set(run_qa.VISUAL_IMAGES)))

        runner_path = MODULE_PATH.parents[1] / "tests" / "VisualReviewRunner.gd"
        runner_source = runner_path.read_text(encoding="utf-8")
        required_list = re.search(r"const REQUIRED_CAPTURES := \[(.*?)\n\]", runner_source, re.S)
        self.assertIsNotNone(required_list)
        registered_captures = set(re.findall(r'"([^"\n]+)"', required_list.group(1)))
        self.assertTrue(captures.issubset(registered_captures))

    def test_expansion_runners_use_scene_wrappers(self):
        root = MODULE_PATH.parents[2]
        self.assertEqual(len(run_qa.EXPANSION_RUNNERS), 4)
        for _, scene_name, _ in run_qa.EXPANSION_RUNNERS:
            self.assertTrue((root / "scenes/tests" / (scene_name + ".tscn")).is_file())

    def test_regression_report_requires_executed_passing_checks(self):
        report = {"status": "passed", "checks": [{"name": "real check", "passed": True}], "failures": []}
        self.assertTrue(run_qa.regression_report_passed(report))
        for change in ({"checks": []}, {"checks": [{"passed": False}]}, {"failures": ["failure"]}, {"status": "failed"}):
            self.assertFalse(run_qa.regression_report_passed({**report, **change}))

    def test_terminating_a_timed_out_process_cleans_up_its_tracked_process(self):
        process = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(60)"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
            start_new_session=os.name != "nt",
        )
        try:
            run_qa._terminate_process_tree(process)
            self.assertIsNotNone(process.wait(timeout=5))
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
