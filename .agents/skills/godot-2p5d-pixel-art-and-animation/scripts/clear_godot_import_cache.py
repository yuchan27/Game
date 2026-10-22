from __future__ import annotations

"""
Reusable utility to purge stale Godot 4 `.godot/imported/` texture/audio cache files
and trigger a clean headless re-import so updated assets appear immediately in-game.
"""

import argparse
import subprocess
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Clear Godot .godot/imported cache and re-import assets.")
    parser.add_argument("--project", default=str(Path(__file__).resolve().parents[4]), help="Godot project root")
    parser.add_argument("--godot", default=r"C:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe", help="Path to Godot console binary")
    parser.add_argument("--skip-import", action="store_true", help="Only delete cache files without running Godot --import")
    args = parser.parse_args()

    project_root = Path(args.project).resolve()
    imported_dir = project_root / ".godot" / "imported"
    removed = 0
    if imported_dir.exists():
        for f in imported_dir.glob("*"):
            if f.is_file():
                try:
                    f.unlink()
                    removed += 1
                except OSError:
                    pass
    print(f"[CACHE] Removed {removed} cached file(s) from {imported_dir}")

    if not args.skip_import and Path(args.godot).exists():
        cmd = [args.godot, "--headless", "--path", str(project_root), "--import"]
        print(f"[CACHE] Running: {' '.join(cmd)}")
        proc = subprocess.run(cmd, cwd=str(project_root), check=False)
        return proc.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
