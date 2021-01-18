import shutil
import subprocess
from functools import partial
from pathlib import Path
from traceback import print_exc
from contextlib import contextmanager

from buildchain.config import BUILD_DIR


TESTS_DIR = BUILD_DIR / "tests"
SAMPLE_PROJECT_DIR = Path(__file__).parent / "test_project"


def run_cmd(cmd):
    if isinstance(cmd, str):
        cmd = cmd.split()
    print(" ".join(cmd))
    try:
        out = subprocess.run(cmd, check=True, capture_output=True)
    except subprocess.CalledProcessError as exc:
        print(f"Error !!! Non-zero return code: {exc.returncode}")
        print()
        print(f"stdout: {exc.stdout.decode()}")
        print()
        print(f"stderr: {exc.stderr.decode()}")
        raise RuntimeError(f"Test has failed (returncode: {exc.returncode})") from exc
    # See https://github.com/godotengine/godot/issues/30207
    if "SCRIPT ERROR:" in out.stdout.decode():
        print(f"Godot error detected !!!")
        print()
        print(f"stdout: {out.stdout.decode()}")
        print()
        print(f"stderr: {out.stderr.decode()}")
        raise RuntimeError(f"Test has failed (Godot error)")

    @contextmanager
    def _error_context():
        try:
            yield
        except Exception as exc:
            print(f"Test failure !!!")
            print()
            print_exc()
            print()
            print(f"stdout: {out.stdout.decode()}")
            print()
            print(f"stderr: {out.stderr.decode()}")
            raise RuntimeError(f"Test has failed {exc}") from exc

    out.error_context = _error_context

    return out


def run_cli(project_path, cmd):
    return run_cmd(
        f"{env['godot_binary']} --path {project_path} --script res://addons/pythonscript_install_manager/cli.gd {cmd}"
    )


def test(action):
    test_name = action.__name__

    def task_generator():
        project_path = TESTS_DIR / test_name

        def _clean():
            try:
                shutil.rmtree(str(project_path))
            except FileNotFoundError:
                pass

        def _build_test_project():
            _clean()
            # Copy base project
            shutil.copytree(str(SAMPLE_PROJECT_DIR), str(project_path))
            # Add install manager addon to project
            shutil.copytree(str(BUILD_DIR / "dist"), str(project_path / "addons"))

        yield {
            "name": f"_bootstrap_{test_name}",
            "actions": [_build_test_project],
            "uptodate": [False],
            "task_dep": ["build_dist"],
        }

        yield {
            "name": test_name,
            "actions": [partial(action, project_path=project_path)],
            "uptodate": [False],
            "task_dep": [f"tests:_bootstrap_{test_name}"],
            "getargs": {"godot_binary": ("fetch_godot", "path")},
            "clean": [_clean],
        }

    task_generator.__name__ = f"task_{test_name}"
    return task_generator


@test
def test_cli_no_arguments(godot_binary, project_path):
    cmd = f"{godot_binary} --path {project_path} --script res://addons/pythonscript_install_manager/cli.gd"
    out = run_cmd(cmd)
    with out.error_context():
        stdout = out.stdout.decode()
        assert (
            "Usage: godot [--path <project_path>] [--no-window] --script res://addons/pythonscript_install_manager/cli.gd [options]"
            in stdout
        )


def task_tests():
    for test in [test_cli_no_arguments]:
        yield from test()


TASKS = {fn.__name__: fn for fn in [task_tests]}
