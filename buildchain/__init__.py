from . import build
from . import fetch_godot


TASKS = {
    fn.__name__: fn
    for fn in [
        build.task_build_dist,
        build.task_make_dist_archive,
        fetch_godot.task_fetch_godot,
    ]
}


# # Expose the tasks
# from .tools import tasks, task, load_file

# load_file()

# Given buildchain is always loaded from ./make.py, we know project root
# is part of sys.path, hence we can load from here
# from tests import *
