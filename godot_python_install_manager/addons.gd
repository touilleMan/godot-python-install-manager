tool
extends Object


const Addon = preload("addon.gd")


static func new_godot_python_addon() -> Addon:
	return Addon.new(
		"godot_python",
		"Godot Python",
		"https://api.github.com/repos/touilleMan/godot-python/releases"
	)


static func new_install_manager_addon() -> Addon:
	return Addon.new(
		"godot_python_install_manager",
		"Install Manager",
		"https://api.github.com/repos/touilleMan/godot-python-install-manager/releases"
	)
