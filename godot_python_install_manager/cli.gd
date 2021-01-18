tool
extends SceneTree


const Utils = preload("utils.gd")
const Addons = preload("addons.gd")


func _extract_script_args() -> Array:
	# Keep parsing simple: we consider the script must be started by doing:
	# godot <godot options> --script <script_path> <script options>
	# This way we can simply look for the --script option as a delimiter
	var args: Array = OS.get_cmdline_args()
	var delimiter = max(args.find_last("--script"), args.find_last("-s"))
	return args.slice(delimiter+2, len(args))


func _print_usage():
	print("""Usage: godot [--path <project_path>] [--no-window] --script res://addons/godot_python_install_manager/cli.gd [options]
info: Display installed versions info
self_upgrade [<VERSION>]: Upgrade the install manager (this tool)
install [<VERSION>]: Ensure Godot Python addon is installed
upgrade [<VERSION>]: Upgrade the installed version of Godot Python addon
list_versions: List Godot Python addon versions compatible with your OS/Godot version
self_list_versions: List install manager versions compatible with your OS/Godot version
""")


func _parse_args(args: Array):
	var raw_version = args.pop_front()
	if args:
		print("Too many arguments")
		return null
	if raw_version == null or raw_version == "latest":
		return "latest"
	if Utils.parse_version(raw_version):
		return raw_version
	else:
		print("Invalid version: must specify a SemVer value (e.g. `0.1.2`) or `latest`")
		return null


func _cmd_info() -> int:
	for addon in [Addons.new_godot_python_addon(), Addons.new_install_manager_addon()]:
		var version = addon.get_current_version(true)
		if version == null:
			version = "Not installed"
		print("%s: %s" % [addon.display_name, version])
		addon.free()
	return 0


func _cmd_self_upgrade(args: Array) -> int:
	yield(Utils.noop_yield(), "completed")  # Ensure we return a coroutine no matter what

	var version = _parse_args(args)
	if not version:
		return 1
	var addon = Addons.new_install_manager_addon()
	var ret = yield(_upgrade_addon(addon, version), "completed")
	addon.free()
	return ret


func _cmd_upgrade(args: Array) -> int:
	yield(Utils.noop_yield(), "completed")  # Ensure we return a coroutine no matter what

	var version = _parse_args(args)
	if not version:
		return 1
	var addon = Addons.new_godot_python_addon()
	var ret = yield(_upgrade_addon(addon, version), "completed")
	addon.free()
	return ret


func _cmd_install(args: Array) -> int:
	yield(Utils.noop_yield(), "completed")  # Ensure we return a coroutine no matter what

	var version = _parse_args(args)
	if not version:
		return 1
	var addon = Addons.new_godot_python_addon()
	var current_version = addon.get_current_version(true)
	if current_version != null:
		print("%s is already installed in version %s" % [addon.display_name, addon.get_current_version(true)])
		addon.free()
		return 0

	else:
		var ret = yield(_upgrade_addon(addon, version), "completed")
		addon.free()
		return ret


func _upgrade_addon(addon, version) -> int:
	print("Fetching upgrade info...")
	var ret
	ret = yield(addon.fetch_upgrade_info(), "completed")
	if ret[0] != OK:
		print("Error: %s" % ret[1])
		return 1

	if version == "latest" and not addon.upgrade_needed():
		print("Version %s is already the latest version" % addon.get_current_version(true))
		return 0

	else:
		if version == "latest":
			version = addon.get_latest_version(true)
		print("Upgrading %s to version %s" % [addon.display_name, addon.get_latest_version(true)])
		ret = yield(addon.upgrade_to_version(version), "completed")
		if ret[0] != OK:
			print("Error: %s" % ret[1])
			return 1

	return 0


func _list_addon_versions(addon) -> int:
	yield(Utils.noop_yield(), "completed")  # Ensure we return a coroutine no matter what
	print("Fetching update info...")
	var ret
	ret = yield(addon.fetch_upgrade_info(), "completed")
	if ret[0] != OK:
		print("Error: %s" % ret[1])
		return 1
	print("Available versions:")
	for item in ret[1]:
		print("%s (%s)" % [item["str_version"], item["archive_name"]])
	return 0

func _init():
	var args: Array = _extract_script_args()
	if args.empty():
		_print_usage()
		OS.exit_code = 0
	else:
		var cmd = args.pop_front()
		if cmd == "info":
			OS.exit_code = _cmd_info()
		elif cmd == "self_upgrade":
			OS.exit_code = yield(_cmd_self_upgrade(args), "completed")
		elif cmd == "install":
			OS.exit_code = yield(_cmd_install(args), "completed")
		elif cmd == "upgrade":
			OS.exit_code = yield(_cmd_upgrade(args), "completed")
		elif cmd == "list_versions":
			var addon = Addons.new_godot_python_addon()
			OS.exit_code = yield(_list_addon_versions(addon), "completed")
			addon.free()
		elif cmd == "self_list_versions":
			var addon = Addons.new_install_manager_addon()
			OS.exit_code = yield(_list_addon_versions(addon), "completed")
			addon.free()
		else:
			print("Unknown command `%s`" % cmd)
			_print_usage()
			OS.exit_code = 1
	quit()
