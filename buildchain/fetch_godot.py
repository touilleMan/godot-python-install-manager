import os
import sys
import platform
import re
from pathlib import Path
from io import BytesIO
from zipfile import ZipFile
from urllib.request import urlopen
from doit import get_var
from doit.tools import run_once, config_changed

from .config import BUILD_DIR, DEFAULT_GODOT_BINARY_VERSION


def resolve_godot_download_url(major, minor, patch, extra, platform):
    version = f"{major}.{minor}.{patch}" if patch != "0" else f"{major}.{minor}"
    if extra == "stable":
        return f"https://downloads.tuxfamily.org/godotengine/{version}/Godot_v{version}-{extra}_{platform}.zip"
    else:
        return f"https://downloads.tuxfamily.org/godotengine/{version}/{extra}/Godot_v{version}-{extra}_{platform}.zip"


def resolve_godot_binary_name(major, minor, patch, extra, platform):
    version = f"{major}.{minor}.{patch}" if patch != "0" else f"{major}.{minor}"
    return f"Godot_v{version}-{extra}_{platform}"


def get_godot_platform() -> str:
    is_64bits = sys.maxsize > 2**32
    try:
        godot_platform = {
            ("Linux", False): "x11.32",
            ("Linux", True): "x11.64",
            ("Windows", False): "win32.exe",
            ("Windows", True): "win64.exe",
            ("Darwin", True): "osx.64",
        }[(platform.system(), is_64bits)]
    except KeyError:
        raise RuntimeError("Cannot determine what version of Godot to download for your architecture ;'(")
    return godot_platform


def task_fetch_godot():
    godot_binary = get_var("godot_binary", default=DEFAULT_GODOT_BINARY_VERSION)

    match = re.match(r"^(?P<major>[0-9]+).(?P<minor>[0-9]+)(.(?P<patch>[0-9]+))?(-(?P<extra>[^_]))?(_(?P<platform>.*))?$", godot_binary)
    if match:
        specs = match.groupdict()
        specs["platform"] = specs["platform"] or get_godot_platform()
        specs["extra"] = specs["extra"] or "stable"
        godot_download_url = resolve_godot_download_url(**specs)
        godot_binary_name = resolve_godot_binary_name(**specs)
        godot_binary_path = BUILD_DIR / godot_binary_name

        def _download_and_extract():
            with urlopen(godot_download_url) as rep:
                zipfile = ZipFile(BytesIO(rep.read()))
            if specs["platform"] == "osx.64":
                godot_binary_zip_path = "Godot.app/Contents/MacOS/Godot"
            else:
                godot_binary_zip_path = godot_binary_name
            if godot_binary_zip_path not in zipfile.namelist():
                raise RuntimeError(f"Archive doesn't contain {godot_binary_zip_path}")
            dst = str(godot_binary_path.absolute())
            with open(dst, "wb") as fd:
                fd.write(zipfile.open(godot_binary_zip_path).read())
            if os.name == "posix":
                os.chmod(dst, 0o755)

            return {"path": str(godot_binary_path)}

        def _uptodate():
            # Don't re-download if we switch back to an existing binary
            return config_changed(godot_binary) and godot_binary_path.exists()

        return {
            "title": lambda task: f"fetching {godot_binary_name}",
            "actions": [_download_and_extract],
            "targets": [godot_binary_path],
            "uptodate": [_uptodate],
            # Don't clean to save some bandwidth
        }

    else:
        # Consider we got passed a path to the godot binary
        godot_binary_path = Path(godot_binary)
        godot_binary_name = godot_binary_path.name
        def _check_existance():
            if not godot_binary_path.is_file():
                raise RuntimeError(
                    "Invalid `godot_binary` option, should be a path or a version (e.g. `3.2`, `3.1.1-beta3`, `3.1.3-stable_x11.32`)"
                )
            return {"path": str(godot_binary_path)}

        return {
            "title": lambda task: f"using {godot_binary_path}",
            "actions": [_check_existance],
            "targets": [godot_binary_path],
        }
