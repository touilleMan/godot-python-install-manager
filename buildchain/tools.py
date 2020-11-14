from typing import Dict, Any
import shutil
from functools import partial
from pathlib import Path
from urllib.request import urlopen, HTTPError
from doit.tools import run_once


def load_tasks_from_file(path: Path) -> Dict[str, Any]:
    abspath = str(path.absolute())
    sub_globals = {'__file__': abspath}
    tasks = {}
    exec(compile(path.read_bytes(), abspath, 'exec'), sub_globals)
    for name, value in sub_globals.items():
        if name.startswith('task_') or hasattr(value, 'create_doit_tasks'):
            tasks[name] = value
    return tasks


def mkdir_task(target: Path, **kwargs):
    def _do_mkdir():
        target.mkdir(exist_ok=True)

    return {
        'actions': [_do_mkdir],
        "uptodate": [target.exists],
        "targets": [target],
        "clean": True,
        **kwargs,
    }


def cp_task(src: Path, dst: Path, **kwargs):
    def _do_copy():
        shutil.copy(str(src.absolute()), str(dst.absolute()))

    return {
        "file_dep": [src],
        "actions": [_do_copy],
        "targets": [dst],
        "clean": True,
        **kwargs,
    }


def make_archive_task(src: Path, dst: Path, **kwargs):
    def _do_archive():
        for suffix, format in [(".zip", "zip"), (".tar.bz2", "bztar")]:
            if dst.name.endswith(suffix):
                base_name_with_path = str(dst.absolute())[: -len(suffix)]
                break
        else:
            raise RuntimeError("Unknown archive format !")
        shutil.make_archive(base_name_with_path, format, root_dir=src.absolute())

    return {
        "actions": [_do_archive],
        "targets": [dst],
        "clean": True,
        **kwargs,
    }


def dowload_task(url: str, dst: Path, **kwargs):
    def _do_download():
        with urlopen(url) as rep:
            dst.write_text(rep.read())

    return {
        "actions": [_do_download],
        "targets": [dst],
        "clean": False,
        "uptodate": [run_once],
        **kwargs,
    }
