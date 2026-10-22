"""Pure unit checks for QA path and command safety helpers."""

import importlib.util
import os
import subprocess
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("run_qa.py")
SPEC = importlib.util.spec_from_file_location("run_qa_under_test", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
run_qa = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(run_qa)


class QaHelperTests(unittest.TestCase):
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
