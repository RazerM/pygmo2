"""Repair a Windows wheel with delvewheel, pointing it at vcpkg's DLLs.

The x64-windows triplet builds the dependencies as DLLs into the build
directory's vcpkg_installed tree, which delvewheel does not search by itself.
The build directory is keyed by wheel tag (build-dir in pyproject.toml), so
recover the tag from the wheel's filename.
"""

import subprocess
import sys
from pathlib import Path

wheel, dest_dir = sys.argv[1:]
tag = "-".join(Path(wheel).stem.split("-")[-3:])
project = Path(__file__).resolve().parent.parent
bin_dir = project / "build" / tag / "vcpkg_installed" / "x64-windows" / "bin"
if not bin_dir.is_dir():
    sys.exit(f"{bin_dir} does not exist")

subprocess.run(
    [sys.executable, "-m", "delvewheel", "repair", "--add-path", str(bin_dir),
     "-w", dest_dir, "-v", wheel],
    check=True,
)
