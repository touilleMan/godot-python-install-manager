tool
extends SceneTree


const Utils = preload("utils.gd")
const Addon = preload("addon.gd")


func _extract_script_args() -> Array:
	# Keep parsing simple: we consider the script must be started by doing:
	# godot <godot options> --script <script_path> <script options>
	# This way we can simply look for the --script option as a delimiter
	var args: Array = OS.get_cmdline_args()
	var delimiter = max(args.find_last("--script"), args.find_last("-s"))
	return args.slice(delimiter+1, len(args))


func _print_usage():
	var install_manager_addon = Utils.get_install_manager_addon()
	print("""Godot-Python install manager version %s
Usage: godot [--path <project_path>] [--no-window] --script res://addons/pythonscript_install_manager/cli.gd [options]
self_upgrade [--version <VERSION>]: Upgrade the install manager
install [--version <VERSION>]: Ensure Pythonscript is installed
upgrade [--version <VERSION>]: Upgrade the installed version of Pythonscript
""" % install_manager_addon.get_current_version(true))


func _parse_args(args: Array):
	var version = "latest"
	while args:
		var arg = args.pop_front()
		if arg == "--version":
			version = args.pop_front()
			if not version:
				print("Argument --version must specify a SemVer value (e.g. `0.1.2`) or `latest`")
				return null
		else:
			print("Unknown argument `%s`" % arg)
			return null
	return version


func _cmd_self_upgrade(args: Array) -> int:
	var version = _parse_args(args)
	if not version:
		return 1
	var addon = Utils.get_install_manager_addon()
	addon.upgrade_to_version(version)
	return 0


func _cmd_install(args: Array) -> int:
	var version = _parse_args(args)
	if not version:
		return 1
	var addon = Utils.get_pythonscript_addon()
	var current_version = addon.get_current_version(true)
	if current_version:
		print("%s is already installed in version %s" % [addon.display_name, current_version])
		return 0
	else:
		addon.upgrade_to_version("latest")
		return 0


func _cmd_upgrade(args: Array) -> int:
	var version = _parse_args(args)
	if not version:
		return 1
	var addon = Utils.get_pythonscript_addon()
	addon.upgrade_to_version(version)
	return 0


func _init():
	var args: Array = _extract_script_args()
	if not args or "--help" in args or "-h" or args:
		_print_usage()
		OS.exit_code = 0
	else:
		var cmd = args.pop_front()
		if cmd == "self_upgrade":
			OS.exit_code = _cmd_self_upgrade(args)
		elif cmd == "install":
			OS.exit_code = _cmd_install(args)
		elif cmd == "upgrade":
			OS.exit_code = _cmd_upgrade(args)
		else:
			print("Unknown command `%s`" % cmd)
			_print_usage()
			OS.exit_code = 1
	quit()
