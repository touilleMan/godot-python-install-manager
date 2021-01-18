.. image:: https://img.shields.io/badge/code%20style-black-000000.svg
   :target: https://github.com/ambv/black
   :alt: Code style: black

============================
Godot Python Install Manager
============================

.. image:: https://github.com/touilleMan/godot-python/raw/master/misc/godot_python.svg
   :width: 200px
   :align: right
   :target: https://github.com/touilleMan/godot-python/

This project aims at providing a better way to install
`Godot Python <https://github.com/touilleMan/godot-python/>`.

Usage
-----

First install Godot Python Install Manager from the `Godot asset library <https://godotengine.org/asset-library/asset>` (TODO: this project is WIP and so not available yet on the asset library ^^).

The resulting `addons/godot-python-install-manager` folder is quite small (it only contains a couple of GDScript files), so you can commit it into your project.

Each time the Godot editor is started, Godot Python Install Manager checks if Godot Python is installed
and prompt you to download it if it's not the case.

Given Godot Python Install Manager only install a Godot Python distribution for your current platform, the download is fast (only nood to fetch&unzip a ~30mo zip archive).

You shouldn't commit the resulting `addons/godot-python` folder into your project: it won't work if you share it with people using different OS, and it is redundant given you already have Godot Python Install Manager to fetch the stuff for you \o/.

Bonus
-----

Godot Python Install Manager comes with a CLI for more advanced use-cases (like installing a specific version of Godot Python):

```shell
$ cd ~/my/godot/project
$ godot --script res://addons/pythonscript_install_manager/cli.gd
[...]
Usage: godot [--path <project_path>] [--no-window] --script res://addons/pythonscript_install_manager/cli.gd [options]
info: Display installed versions info
self_upgrade [<VERSION>]: Upgrade the install manager (this tool)
install [<VERSION>]: Ensure Godot Python addon is installed
upgrade [<VERSION>]: Upgrade the installed version of Godot Python addon
list_versions: List Godot Python addon versions compatible with your OS/Godot version
self_list_versions: List install manager versions compatible with your OS/Godot version
```

Typically for installing Godot Python in version `0.60.0`:
```shell
$ godot --path ~/my/godot/project --no-window --script res://addons/pythonscript_install_manager/cli.gd install 0.60.0
```

Or for upgrading an existing installation of Godot Python to the latest version:
```shell
$ godot --path ~/my/godot/project --no-window --script res://addons/pythonscript_install_manager/cli.gd upgrade
```
