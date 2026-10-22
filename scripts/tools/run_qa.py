#!/usr/bin/env python3
"""Run the project's QA suite in an isolated mirror and preserve its reports."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


PROJECT_ROOT = Path(__file__).resolve().parents[2]
GODOT_ERROR_RE = re.compile(
    r"(?:^|\b)(?:ERROR:|SCRIPT ERROR:|Parse Error|Parser Error|Failed to load resource)",
    re.IGNORECASE,
)
IGNORED_DIRS = {
    ".git",
    ".godot",
    ".qa-venv",
    ".venv",
    ".cache",
    "venv",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    "node_modules",
    "build",
    "dist",
    "target",
}
IGNORED_FILES = {
    "docs/automated_playtest_report.json",
    "docs/performance_report.json",
    "docs/visual_review_report.json",
    "docs/GameplayRegressionRunner.json",
    "docs/gameplay_regression_report.json",
}
VISUAL_IMAGES = (
    "main_title.png",
    "intro.png",
    "inventory.png",
    "tutorial.png",
    "full_map.png",
    "dialogue.png",
    "pause.png",
    "death.png",
    "village_hud.png",
    "guild_hud.png",
    "player_walk.png",
    "player_slash.png",
    "player_shoot.png",
    "route_crystal_scar.png",
    "route_scrap_highway.png",
    "route_toxic_marsh.png",
    "route_old_factory.png",
    "boss.png",
    "main_title_1024x768.png",
    "intro_1024x768.png",
    "inventory_1024x768.png",
    "dialogue_1024x768.png",
    "full_map_1024x768.png",
    "continue_load_failure.png",
    "quest_progress.png",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def resolve_output_root(raw_path: str | None, project_root: Path = PROJECT_ROOT) -> Path:
    root = project_root.resolve()
    if raw_path:
        output = Path(raw_path).expanduser().resolve()
    else:
        output = (Path(tempfile.gettempdir()) / "first-game-qa").resolve()
    if is_within(output, root):
        raise ValueError(f"QA output must be outside the project directory: {output}")
    return output


def choose_python(explicit: str | None, project_root: Path = PROJECT_ROOT) -> str:
    if explicit:
        return explicit
    candidates = [
        project_root / ".godot" / "qa-venv" / "Scripts" / "python.exe",
        project_root / ".godot" / "qa-venv" / "bin" / "python",
    ]
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    return sys.executable


def resolve_godot(explicit: str | None, environ: dict[str, str] | None = None) -> str | None:
    env = environ if environ is not None else os.environ
    candidates = [explicit, env.get("GODOT_BIN")]
    for candidate in candidates:
        if candidate:
            found = shutil.which(candidate)
            path = Path(candidate)
            if found:
                return found
            if path.is_file():
                return str(path.resolve())
            raise ValueError(f"Godot executable does not exist or is not on PATH: {candidate}")
    for name in ("godot", "godot4", "godot.exe", "godot4.exe"):
        found = shutil.which(name)
        if found:
            return found
    return None


def patch_project_user_dir(project_file: Path, run_id: str) -> None:
    text = project_file.read_text(encoding="utf-8")
    project_file.write_text(render_user_dir_config(text, run_id), encoding="utf-8")


def render_user_dir_config(text: str, run_id: str) -> str:
    lines = text.splitlines()
    section_header = "[application]"
    try:
        section_start = lines.index(section_header)
    except ValueError:
        lines.extend(["", section_header])
        section_start = len(lines) - 1
    section_end = section_start + 1
    while section_end < len(lines) and not lines[section_end].strip().startswith("["):
        section_end += 1
    settings = {
        "config/use_custom_user_dir": "true",
        "config/custom_user_dir_name": json.dumps(f"FirstGame-QA-{run_id}"),
    }
    for key, value in settings.items():
        match_index = next(
            (index for index in range(section_start + 1, section_end) if lines[index].split("=", 1)[0].strip() == key),
            None,
        )
        setting_line = f"{key}={value}"
        if match_index is None:
            lines.insert(section_end, setting_line)
            section_end += 1
        else:
            lines[match_index] = setting_line
    return "\n".join(lines) + "\n"


def ignore_copy(directory: str, names: list[str]) -> set[str]:
    current = Path(directory)
    ignored = {name for name in names if name in IGNORED_DIRS}
    for name in names:
        entry = current / name
        try:
            relative = entry.relative_to(PROJECT_ROOT).as_posix()
        except ValueError:
            relative = name
        if relative in IGNORED_FILES:
            ignored.add(name)
        if relative.startswith("docs/") and name.startswith("visual_review_") and name.lower().endswith(".png"):
            ignored.add(name)
        if name.endswith(".pyc") or name.endswith(".pyo"):
            ignored.add(name)
    return ignored


def build_godot_command(godot: str, project: Path, scene: str | None = None, *, headless: bool = True,
                        quit_after: int | None = None, user_args: Iterable[str] = (),
                        extra_args: Iterable[str] = ()) -> list[str]:
    command = [godot]
    if headless:
        command.append("--headless")
    command.extend(extra_args)
    command.extend(["--path", str(project)])
    if scene:
        command.extend(["--scene", scene])
    if quit_after is not None:
        command.extend(["--quit-after", str(quit_after)])
    extra = list(user_args)
    if extra:
        command.append("--")
        command.extend(extra)
    return command


def extract_godot_errors(stdout: str, stderr: str) -> list[str]:
    matches: list[str] = []
    for line in (stdout + "\n" + stderr).splitlines():
        if GODOT_ERROR_RE.search(line):
            matches.append(line.strip())
    return matches


def supports_godot_version(version: str) -> bool:
    return re.match(r"^4\.6\.3\.stable(?:\.|$)", version.strip()) is not None


def _terminate_process_tree(process: subprocess.Popen[Any]) -> None:
    if process.poll() is not None:
        return
    if os.name == "nt":
        taskkill = shutil.which("taskkill")
        if taskkill:
            try:
                subprocess.run(
                    [taskkill, "/PID", str(process.pid), "/T", "/F"],
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    timeout=15,
                    check=False,
                )
            except (OSError, subprocess.TimeoutExpired):
                pass
        if process.poll() is None:
            process.kill()
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass


class QaRun:
    def __init__(self, run_dir: Path, timeout: int, python: str, godot: str | None):
        self.run_dir = run_dir
        self.timeout = timeout
        self.python = python
        self.godot = godot
        self.steps: list[dict[str, Any]] = []
        self.sequence = 0

    def run(self, name: str, command: list[str], cwd: Path, *, godot_command: bool = False) -> dict[str, Any]:
        self.sequence += 1
        stem = f"{self.sequence:02d}-{safe_name(name)}"
        stdout_path = self.run_dir / f"{stem}.stdout.txt"
        stderr_path = self.run_dir / f"{stem}.stderr.txt"
        started_at = utc_now()
        started = time.monotonic()
        environment = os.environ.copy()
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        record: dict[str, Any] = {
            "name": name,
            "command": command,
            "cwd": str(cwd),
            "started_at": started_at,
            "status": "failed",
            "exit_code": None,
            "timed_out": False,
            "duration_seconds": None,
            "stdout_log": str(stdout_path),
            "stderr_log": str(stderr_path),
            "godot_errors": [],
        }
        stdout = ""
        stderr = ""
        process: subprocess.Popen[str] | None = None
        try:
            process = subprocess.Popen(
                command,
                cwd=str(cwd),
                env=environment,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
                start_new_session=os.name != "nt",
            )
            stdout, stderr = process.communicate(timeout=self.timeout)
            record["exit_code"] = process.returncode
        except subprocess.TimeoutExpired as error:
            record["timed_out"] = True
            if process is not None:
                _terminate_process_tree(process)
                try:
                    stdout, stderr = process.communicate(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    stdout, stderr = process.communicate()
                record["exit_code"] = process.returncode
            else:
                stdout = _decode_output(error.stdout)
                stderr = _decode_output(error.stderr)
        except OSError as error:
            stderr = f"Could not start command: {error}"
        stdout_path.write_text(stdout, encoding="utf-8")
        stderr_path.write_text(stderr, encoding="utf-8")
        if godot_command:
            record["godot_errors"] = extract_godot_errors(stdout, stderr)
        record["duration_seconds"] = round(time.monotonic() - started, 3)
        record["finished_at"] = utc_now()
        if record["exit_code"] == 0 and not record["timed_out"] and not record["godot_errors"]:
            record["status"] = "passed"
        if record["status"] != "passed" and not record["godot_errors"]:
            record["failure"] = "timed out" if record["timed_out"] else f"exit code {record['exit_code']}"
        self.steps.append(record)
        print(f"[{record['status'].upper()}] {name} ({record['duration_seconds']}s)")
        return record

    def check(self, name: str, passed: bool, details: str) -> dict[str, Any]:
        self.sequence += 1
        record = {
            "name": name,
            "status": "passed" if passed else "failed",
            "details": details,
            "finished_at": utc_now(),
        }
        self.steps.append(record)
        print(f"[{record['status'].upper()}] {name}: {details}")
        return record

    def read_json_report(self, step_name: str, candidates: Iterable[Path]) -> tuple[dict[str, Any] | None, Path | None]:
        report_path = next((candidate for candidate in candidates if candidate.is_file()), None)
        if report_path is None:
            self.check(step_name, False, "expected runner report was not written")
            return None, None
        try:
            report = json.loads(report_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            self.check(step_name, False, f"report could not be parsed: {error}")
            return None, report_path
        return report, report_path


def safe_name(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_.-]+", "-", value).strip("-").lower() or "step"


def _decode_output(value: str | bytes | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        description="Run project data, asset, gameplay, visual, and performance QA in an isolated copy."
    )
    result.add_argument("--profile", choices=("core", "visual", "performance", "all", "docs"), default="core")
    result.add_argument("--godot", help="Godot executable; defaults to GODOT_BIN or an executable on PATH.")
    result.add_argument("--python", help="Python executable with requirements-qa.txt installed; defaults to this QA venv if present.")
    result.add_argument("--output", help="External output root. Defaults to the system temporary directory.")
    result.add_argument("--timeout", type=int, default=240, help="Per-command timeout in seconds (default: 240).")
    return result


def create_run_directory(output_root: Path) -> tuple[str, Path]:
    output_root.mkdir(parents=True, exist_ok=True)
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
    run_dir = output_root / run_id
    run_dir.mkdir()
    return run_id, run_dir


def mirror_project(destination: Path, run_id: str) -> str:
    shutil.copytree(PROJECT_ROOT, destination, ignore=ignore_copy)
    source_tree_sha256 = hash_project_tree(destination)
    patch_project_user_dir(destination / "project.godot", run_id)
    return source_tree_sha256


def hash_project_tree(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        relative = path.relative_to(root).as_posix()
        encoded_path = relative.encode("utf-8")
        digest.update(len(encoded_path).to_bytes(8, "big"))
        digest.update(encoded_path)
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
    return digest.hexdigest()


def git_provenance(root: Path) -> dict[str, Any]:
    git = shutil.which("git")
    if git is None:
        return {"head": None, "dirty_paths": None, "dirty_path_count": None}
    try:
        revision = subprocess.run([git, "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True, check=True).stdout.strip()
        status = subprocess.run([git, "status", "--short", "--untracked-files=all"], cwd=root, capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return {"head": None, "dirty_paths": None, "dirty_path_count": None}
    dirty_paths = [line[3:] for line in status.splitlines() if len(line) >= 4]
    return {"head": revision, "dirty_paths": dirty_paths, "dirty_path_count": len(dirty_paths)}


def add_report_check(run: QaRun, name: str, report: dict[str, Any] | None, predicate: bool, details: str) -> None:
    if report is None:
        return
    run.check(name, predicate, details)


def run_python_step(run: QaRun, name: str, script: Path, mirror: Path, extra_args: Iterable[str] = ()) -> dict[str, Any]:
    command = [run.python, "-B", str(script), *list(extra_args)]
    return run.run(name, command, mirror)


def run_project_unittests(run: QaRun, project_copy: Path) -> None:
    for relative_dir in (Path("scripts/tools"), Path("scripts/tests")):
        test_dir = project_copy / relative_dir
        if not test_dir.is_dir() or not any(test_dir.glob("test_*.py")):
            continue
        run.run(
            f"Python unit tests: {relative_dir.as_posix()}",
            [run.python, "-B", "-m", "unittest", "discover", "-s", relative_dir.as_posix(), "-p", "test_*.py"],
            project_copy,
        )


def run_godot_step(run: QaRun, name: str, project: Path, scene: str | None = None, *,
                   headless: bool = True, quit_after: int | None = None,
                   user_args: Iterable[str] = (), extra_args: Iterable[str] = ()) -> dict[str, Any] | None:
    if run.godot is None:
        run.check("Godot executable", False, "provide --godot, set GODOT_BIN, or install Godot on PATH")
        return None
    command = build_godot_command(run.godot, project, scene, headless=headless,
                                  quit_after=quit_after, user_args=user_args,
                                  extra_args=extra_args)
    return run.run(name, command, project, godot_command=True)


def run_profile(args: argparse.Namespace) -> int:
    try:
        output_root = resolve_output_root(args.output)
        godot = None if args.profile == "docs" else resolve_godot(args.godot)
    except ValueError as error:
        print(f"QA setup failed: {error}", file=sys.stderr)
        return 2
    if args.timeout < 1:
        print("QA setup failed: --timeout must be at least 1 second.", file=sys.stderr)
        return 2

    run_id, run_dir = create_run_directory(output_root)
    project_copy = run_dir / "project"
    artifact_dir = run_dir / "artifacts"
    save_dir = run_dir / "userdata"
    artifact_dir.mkdir()
    save_dir.mkdir()
    python = choose_python(args.python)
    qa = QaRun(run_dir, args.timeout, python, godot)
    report: dict[str, Any] = {
        "schema_version": 1,
        "run_id": run_id,
        "profile": args.profile,
        "started_at": utc_now(),
        "project_root": str(PROJECT_ROOT),
        "output_directory": str(run_dir),
        "mirror_directory": str(project_copy),
        "python_executable": python,
        "godot_executable": godot,
        "godot_version": None,
        "source_git": git_provenance(PROJECT_ROOT),
        "source_tree_sha256": None,
        "isolated_user_dir_name": f"FirstGame-QA-{run_id}",
        "steps": qa.steps,
    }

    try:
        report["source_tree_sha256"] = mirror_project(project_copy, run_id)
        run_project_unittests(qa, project_copy)
    except Exception as error:  # Keep a run report for setup failures.
        qa.check("isolated project setup", False, str(error))
        report.update({"finished_at": utc_now(), "success": False})
        write_final_report(run_dir, report)
        return 1

    selected_profiles = {
        "core": {"core"},
        "visual": {"core", "visual"},
        "performance": {"core", "performance"},
        "docs": {"docs"},
        "all": {"core", "docs", "visual", "performance"},
    }[args.profile]
    if "docs" in selected_profiles:
        run_python_step(qa, "documentation and skill frontmatter", project_copy / "scripts" / "tools" / "validate_project_data.py", project_copy, ["--skills-only"])

    if "core" in selected_profiles:
        run_python_step(qa, "project data and cross references", project_copy / "scripts" / "tools" / "validate_project_data.py", project_copy)
        run_python_step(qa, "visual asset integrity", project_copy / "scripts" / "tools" / "verify_visual_assets.py", project_copy)

        engine_compatible = False
        if godot is not None:
            version = qa.run("Godot version", [godot, "--version"], project_copy, godot_command=True)
            if version["status"] == "passed":
                version_text = (Path(version["stdout_log"]).read_text(encoding="utf-8") + " " + Path(version["stderr_log"]).read_text(encoding="utf-8")).strip()
                report["godot_version"] = version_text
                engine_compatible = supports_godot_version(version_text)
                if not engine_compatible:
                    qa.check("Godot version compatibility", False, f"expected Godot 4.6.3 stable, received {version_text!r}; Godot runners were not executed")
                else:
                    qa.check("Godot version compatibility", True, version_text)
            else:
                qa.check("Godot version compatibility", False, "Godot version command failed; Godot runners were not executed")

        if engine_compatible:
            qa.run("fresh headless import", [godot, "--headless", "--path", str(project_copy), "--import"], project_copy, godot_command=True)
            startup = run_godot_step(qa, "headless main scene startup", project_copy, headless=True, quit_after=3)
            validation = run_godot_step(qa, "vertical slice validation", project_copy, "res://scenes/tests/ValidationRunner.tscn", user_args=["--qa-save-path", str(save_dir / "validation_save.json")])
            if validation is not None:
                output = Path(validation["stdout_log"]).read_text(encoding="utf-8") + Path(validation["stderr_log"]).read_text(encoding="utf-8")
                passed_marker = "[VERIFY] All vertical slice checks passed" in output
                failed_marker = "[VERIFY] Failed checks:" in output
                qa.check("vertical slice result marker", passed_marker and not failed_marker, "runner completion marker")

            playtest = run_godot_step(qa, "automated gameplay playtest", project_copy, "res://scenes/tests/AutomatedPlaytestRunner.tscn", user_args=["--qa-save-path", str(save_dir / "playtest_save.json"), "--qa-output", str(artifact_dir)])
            if playtest is not None:
                play_report, play_path = qa.read_json_report("automated playtest report", [artifact_dir / "automated_playtest_report.json"])
                if play_report is not None:
                    add_report_check(qa, "automated playtest report status", play_report, play_report.get("passed") is True, str(play_path))

            gameplay = run_godot_step(qa, "gameplay regression runner", project_copy, "res://scenes/tests/GameplayRegressionRunner.tscn", user_args=["--qa-save-path", str(save_dir / "gameplay_save.json"), "--qa-output", str(artifact_dir)])
            if gameplay is not None:
                gameplay_report, gameplay_path = qa.read_json_report("gameplay regression report", [artifact_dir / "GameplayRegressionRunner.json", artifact_dir / "gameplay_regression_report.json"])
                if gameplay_report is not None:
                    add_report_check(qa, "gameplay regression report status", gameplay_report, gameplay_report.get("status") == "passed", str(gameplay_path))

            collision = run_godot_step(qa, "collision regression runner", project_copy, "res://scenes/tests/CollisionRegressionRunner.tscn", user_args=["--qa-output", str(artifact_dir)])
            if collision is not None:
                collision_report, collision_path = qa.read_json_report("collision regression report", [artifact_dir / "collision_regression_report.json"])
                if collision_report is not None:
                    add_report_check(
                        qa,
                        "collision regression report status",
                        collision_report,
                        collision_report.get("success") is True
                        and int(collision_report.get("failure_count", 0)) == 0,
                        str(collision_path),
                    )
        elif godot is None:
            qa.check("Godot runner suite", False, "Godot executable not found; no test runner was skipped silently")
        else:
            qa.check("Godot runner suite", False, "not run because the engine version is incompatible")

    if "visual" in selected_profiles:
        visual_dir = artifact_dir / "visual"
        visual_dir.mkdir()
        visual_run = run_godot_step(qa, "rendered visual review", project_copy, "res://scenes/tests/VisualReviewRunner.tscn", headless=False, user_args=["--qa-output", str(visual_dir)]) if supports_godot_version(str(report.get("godot_version", ""))) else None
        if visual_run is None:
            qa.check("rendered visual review", False, "not run because the exact Godot 4.6.3 stable engine is unavailable")
            qa.check("visual capture coverage", False, "not run; visual captures were not silently skipped")
        if visual_run is not None:
            visual_report, visual_path = qa.read_json_report("visual review report", [visual_dir / "visual_review_report.json"])
            if visual_report is not None:
                add_report_check(qa, "visual review report status", visual_report,
                                 visual_report.get("success") is True
                                 and int(visual_report.get("failure_count", 0)) == 0
                                 and int(visual_report.get("error_count", 0)) == 0
                                 and int(visual_report.get("runtime_check_failure_count", 0)) == 0,
                                 str(visual_path))
            missing_images = [name for name in VISUAL_IMAGES if not (visual_dir / name).is_file()]
            qa.check("visual capture coverage", not missing_images, "all expected screenshots present" if not missing_images else "missing: " + ", ".join(missing_images))

    if "performance" in selected_profiles:
        performance = run_godot_step(
            qa,
            "representative rendered performance sample",
            project_copy,
            "res://scenes/tests/PerformanceRunner.tscn",
            headless=False,
            user_args=["--qa-output", str(artifact_dir)],
            extra_args=["--audio-driver", "Dummy"],
        ) if supports_godot_version(str(report.get("godot_version", ""))) else None
        if performance is None:
            qa.check("representative rendered performance sample", False, "not run because the exact Godot 4.6.3 stable engine is unavailable")
        if performance is not None:
            perf_report, perf_path = qa.read_json_report("performance report", [artifact_dir / "performance_report.json"])
            if perf_report is not None:
                add_report_check(qa, "performance report status", perf_report, perf_report.get("status") == "passed", str(perf_path))
                sample = perf_report.get("sample", {})
                environment = sample.get("environment", {}) if isinstance(sample, dict) else {}
                render_work = sample.get("render_work_per_frame", {}) if isinstance(sample, dict) else {}
                render_metrics_present = all(
                    isinstance(render_work.get(key), dict) and int(render_work[key].get("count", 0)) > 0
                    for key in ("draw_calls", "rendered_objects", "primitives")
                ) if isinstance(render_work, dict) else False
                qa.check(
                    "rendered performance metrics present",
                    environment.get("rendered") is True and render_metrics_present,
                    "native display server and per-frame draw-call/object/primitive distributions" if environment.get("rendered") is True and render_metrics_present else "rendered metrics missing or display server is headless",
                )

    report["finished_at"] = utc_now()
    report["steps"] = qa.steps
    report["success"] = all(step.get("status") == "passed" for step in qa.steps)
    write_final_report(run_dir, report)
    print(f"QA {'PASSED' if report['success'] else 'FAILED'}; report: {run_dir / 'qa-report.json'}")
    return 0 if report["success"] else 1


def write_final_report(run_dir: Path, report: dict[str, Any]) -> None:
    path = run_dir / "qa-report.json"
    path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    return run_profile(args)


if __name__ == "__main__":
    raise SystemExit(main())
