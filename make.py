#! /usr/bin/env python3

from doit import run
import buildchain
import tests


if __name__ == "__main__":
    run({
        **buildchain.TASKS,
        **tests.TASKS,
        "DOIT_CONFIG": {'default_tasks': ['build_dist']},
    })
