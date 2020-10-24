extends Object


const Addon = preload("addon.gd")


static func get_install_manager_addon() -> Addon:
	return Addon.new(
		"pythonscript",
		"Pythonscript",
		"https://api.github.com/repos/touilleMan/godot-python/releases"
	)


static func get_pythonscript_addon() -> Addon:
	return Addon.new(
		"pythonscript_install_manager",
		"Install Manager",
		"https://api.github.com/repos/touilleMan/godot-python-install-manager/releases"
	)


static func get_addons() -> Array:
	return [get_install_manager_addon(), get_pythonscript_addon()]
