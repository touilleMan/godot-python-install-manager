extends SceneTree

# Run the gui
# godot --path <your project> --no-window --script res://addons/pythonscript_install_manager/cli.gd

# var Optparse = load('res://addons/gut/optparse.gd')
# var Gut = load('res://addons/gut/gut.gd')

func _init():
	print("hello, world !", OS.get_cmdline_args())
	# if(!_utils.is_version_ok()):
	# 	print("\n\n", _utils.get_version_text())
	# 	push_error(_utils.get_bad_version_text())
	# 	OS.exit_code = 1
	# 	quit()
	OS.exit_code = 1
	quit()
	# else:
	# 	_run_gut()
