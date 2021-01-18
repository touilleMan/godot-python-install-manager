import os
import re
import sys
import shutil
from datetime import datetime
from io import BytesIO
from zipfile import ZipFile
from urllib.request import urlopen, HTTPError
from SCons.Platform.virtualenv import ImportVirtualenv
from SCons.Errors import UserError


EnsurePythonVersion(3, 7)
EnsureSConsVersion(3, 0)


def extract_version():
    src = open("pythonscript_install_manager/plugin.cfg").read()
    return re.search(r"version=\"(.*)\"", src).group(1)


def godot_binary_converter(val, env):
    file = File(val)
    if file.exists():
        # Note here `env["godot_binary_download_version"]` is not defined, this is ok given
        # this variable shouldn't be needed if Godot doesn't have to be downloaded
        return file
    # Provided value is version information with format <major>.<minor>.<patch>[-<extra>]
    match = re.match(r"^([0-9]+)\.([0-9]+)\.([0-9]+)(?:-(\w+))?$", val)
    if match:
        major, minor, patch, extra = match.groups()
    else:
        raise UserError(
            f"`{val}` is neither an existing file nor a valid <major>.<minor>.<patch>[-<extra>] Godot version format"
        )
    env["godot_binary_download_version"] = (major, minor, patch, extra or "stable")
    # `godot_binary` is set to None to indicate it should be downloaded
    return None


vars = Variables("custom.py")
vars.Add(
    "godot_args", "Additional arguments passed to godot binary when running tests&examples", ""
)
vars.Add("release_suffix", "Suffix to add to the release archive", extract_version())
vars.Add(
    "godot_binary",
    "Path to Godot binary or version of Godot to use",
    default="3.2.2",
    converter=godot_binary_converter,
)


env = Environment(variables=vars, tools=["default", "symlink"], ENV=os.environ)


Help(vars.GenerateHelpText(env))


env["DIST_ROOT"] = Dir(f"build/dist")
env["DIST_ADDON"] = Dir(f"{env['DIST_ROOT']}/addons/pythonscript_install_manager")


### Godot binary (to run tests) ###


def resolve_godot_download_url(major, minor, patch, extra, platform):
    version = f"{major}.{minor}.{patch}" if patch != 0 else f"{major}.{minor}"
    if extra == "stable":
        return f"https://downloads.tuxfamily.org/godotengine/{version}/Godot_v{version}-{extra}_{platform}.zip"
    else:
        return f"https://downloads.tuxfamily.org/godotengine/{version}/{extra}/Godot_v{version}-{extra}_{platform}.zip"


def resolve_godot_binary_name(major, minor, patch, extra, platform):
    version = f"{major}.{minor}.{patch}" if patch != 0 else f"{major}.{minor}"
    return f"Godot_v{version}-{extra}_{platform}"


if not env["godot_binary"]:
    platform = sys.platform
    is_64bits = sys.maxsize > 2 ** 32
    try:
        godot_binary_download_platform = {
            ("linux", True): "x11.64",
            ("linux", False): "x11.32",
            ("win32", True): "win64.exe",
            ("win32", False): "win32.exe",
            ("darwin", True): "osx.64",
        }[platform, is_64bits]
    except KeyError:
        raise UserError("Don't know what what version of Godot should be downloaded :(")
    godot_download_url = resolve_godot_download_url(
        *env["godot_binary_download_version"], godot_binary_download_platform
    )
    godot_binary_name = resolve_godot_binary_name(
        *env["godot_binary_download_version"], godot_binary_download_platform
    )
    env["godot_binary"] = File(f"build/{godot_binary_name}")
    if platform == "osx.64":
        godot_binary_zip_path = "Godot.app/Contents/MacOS/Godot"
    else:
        godot_binary_zip_path = godot_binary_name

    def download_and_extract(target, source, env):
        try:
            with urlopen(godot_download_url) as rep:
                zipfile = ZipFile(BytesIO(rep.read()))
        except HTTPError as exc:
            # It seems SCons swallows HTTPError, so we have to wrap it
            raise UserError(exc) from exc
        if godot_binary_zip_path not in zipfile.namelist():
            raise UserError(f"Archive doesn't contain {godot_binary_zip_path}")
        with open(target[0].abspath, "wb") as fd:
            fd.write(zipfile.open(godot_binary_zip_path).read())
        if env["HOST_OS"] != "win32":
            os.chmod(target[0].abspath, 0o755)

    env.Command(
        env["godot_binary"],
        None,
        Action(download_and_extract, f"Download&extract {godot_download_url}"),
    )
    env.NoClean(env["godot_binary"])


### Load sub scons scripts ###


Export(env=env)
SConscript("tests/SConscript")


### Define default target ###


env.Default(env["DIST_ROOT"])
env.Alias("build", env["DIST_ROOT"])


### Build dist ###


env.Install(env["DIST_ADDON"], env.Glob("pythonscript_install_manager/*"))
env.Install(env["DIST_ADDON"], "LICENSE")
env.Install(env["DIST_ROOT"], "README.rst")


### Release archive ###


def generate_release(target, source, env):
    for suffix, format in [(".zip", "zip"), (".tar.bz2", "bztar")]:
        if target[0].name.endswith(suffix):
            base_name = target[0].abspath[: -len(suffix)]
            break
    shutil.make_archive(base_name, format, root_dir=source[0].abspath)


release = env.Command(
    target="build/godot_python_install_manager-${release_suffix}-godot3.zip",
    source=env["DIST_ROOT"],
    action=generate_release,
)
env.Alias("release", release)
env.AlwaysBuild("release")
