import re
from doit.tools import run_once, result_dep

from .config import ROOT_DIR, BUILD_DIR
from .tools import mkdir_task, cp_task, make_archive_task


DIST_DIR = BUILD_DIR / "dist"

SRCS_DIR = ROOT_DIR / "pythonscript_install_manager"
SRCS = [
    "addon.gd",
    "addons.gd",
    "cli.gd",
    "gdunzip.gd",
    "manager.gd",
    "manager.tscn",
    "plugin.cfg",
    "plugin.gd",
    "utils.gd",
]


_version: str
def extract_version():
    global _version
    try:
        return _version
    except NameError:
        src = (SRCS_DIR / "plugin.cfg").read_text()
        _version = re.search(r"version=\"(.*)\"", src).group(1)
        return _version


def task_build_dist():
    # Create dirs
    yield mkdir_task(DIST_DIR, name=DIST_DIR.relative_to(ROOT_DIR))
    plugin_dir = DIST_DIR / "pythonscript_install_manager"
    yield mkdir_task(plugin_dir, name=plugin_dir.relative_to(ROOT_DIR))

    # Copy source files
    for name in SRCS:
        src = SRCS_DIR / name
        dst = plugin_dir / name
        yield cp_task(src=src, dst=dst, name=dst.relative_to(ROOT_DIR))

    # Copy readme & license
    for item in ["LICENSE", "README.rst"]:
        src = ROOT_DIR / item
        dst = plugin_dir / item
        yield cp_task(src=src, dst=dst, name=dst.relative_to(ROOT_DIR))


def task_make_dist_archive():
    version = extract_version()
    return make_archive_task(
        src=DIST_DIR,
        dst=BUILD_DIR / f"godot-python-install-manager-{version}.zip",
        # Must be explicit about the build deps and rebuild condition given
        # we depend on a directory
        setup=["build_dist"],
        uptodate=[result_dep("build_dist")],
    )
