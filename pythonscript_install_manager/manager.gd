tool
extends WindowDialog

const SETTINGS_LOOK_FOR_UPDATE_ON_STARTUP = "pythonscript_install_manager/look_for_update_on_startup"

var Addon = preload("addon.gd")
onready var pythonscript_addon = Addon.new("pythonscript", "Pythonscript", "https://api.github.com/repos/touilleMan/godot-python/releases")
onready var install_manager_addon = Addon.new("pythonscript_install_manager", "Install Manager", "https://api.github.com/repos/touilleMan/godot-python-install-manager/releases")
onready var addons = [install_manager_addon, pythonscript_addon]
var _retreive_latest_versions_task = null
var _upgrade_thread = null


func _ready():
	# Initialize plugin settings
#    ProjectSettings.add_property_info({
#        "name": SETTINGS_PIN_VERSION,
#        "type": TYPE_STRING,
#        "hint": PROPERTY_HINT_NONE,
#        "hint_string": (
#            "Force the python install manager to download a specific version" +
#            " of Pythonscript instead the lastest available.\n" +
#            "Possibles values: `latest`, `0.42.3`, `1.2`, `1`"
#        )
#    })
	if not ProjectSettings.has_setting(SETTINGS_LOOK_FOR_UPDATE_ON_STARTUP):
		ProjectSettings.set_setting(SETTINGS_LOOK_FOR_UPDATE_ON_STARTUP, true)
	ProjectSettings.add_property_info({
		"name": SETTINGS_LOOK_FOR_UPDATE_ON_STARTUP,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "Check for pythonscript and install manager updates on startup"
	})

	if ProjectSettings.get_setting(SETTINGS_LOOK_FOR_UPDATE_ON_STARTUP):
		yield(_retreive_latest_versions(), "completed")
		if install_manager_addon.upgrade_needed() or pythonscript_addon.upgrade_needed():
			$".".popup_centered()
	$".".popup_centered()


func _do_retreive_latest_versions_and_update_addon_tree():
	yield(_retreive_latest_versions(), "completed")
	_refresh_addons_tree()


func _on_manage_about_to_show():
	_refresh_addons_tree()
	# Don't block the callback by waiting for the yielded function
	call_deferred("_do_retreive_latest_versions_and_update_addon_tree")


func _refresh_addons_tree():
	var tree = $container/addons_tree
	tree.clear()
	tree.set_column_title(0, "Addon")
	tree.set_column_title(1, "Current Version")
	tree.set_column_title(2, "Latest Version")
	tree.set_column_titles_visible(true)
	var root = tree.create_item()
	for addon in addons:
		var item = tree.create_item(root)
		item.set_text(0, addon.display_name)
		for i in range(3):
			item.set_text_align(i, TreeItem.ALIGN_CENTER)
		var current_version = addon.get_current_version()
		if current_version:
			item.set_text(1, "%s.%s.%s" % current_version)
			item.set_custom_color(1, Color.white)
		else:
			item.set_text(1, "Not installed")
			item.set_custom_color(1, Color.red)
		var latest_version = addon.get_latest_version()
		if latest_version:
			if Addon.is_more_recent_version(current_version, latest_version):
				item.set_text(2, "%s.%s.%s" % latest_version)
				item.set_custom_color(2, Color.green)
				item.set_tooltip(2, "A new version is available")
			else:
				item.set_text(2, "%s.%s.%s" % latest_version)
				item.set_custom_color(2, Color.white)
				item.set_tooltip(2, "Latest version is already installed")
		else:
			item.set_text(2, "Not found")
			item.set_tooltip(2, addon.get_fetch_error())
			item.set_custom_color(2, Color.red)


func _format_tooltip(pattern: String, args) -> String:
	var txt = pattern % args
	var out = ""
	var line_len = 0
	for word in txt.split(" "):
		line_len += len(word)
		out += word
		if line_len > 80:
			out += "\n"
			line_len = 0
	return out


func _on_upgrade_button_pressed():
	$container/upgrade_button.disabled = true
	# Run the upgrade in a thread given we use blocking `OS.execute`
	if _upgrade_thread:
		return
	_upgrade_thread = Thread.new()
	if _upgrade_thread.start(self, "_do_upgrade_from_thread") != OK:
		print("Error: cannot start upgrade thread")
		$container/upgrade_button.disabled = false


func _cleanup_upgrade_thread_var():
	if _upgrade_thread:
		_upgrade_thread.wait_to_finish()
		_upgrade_thread = null


func _do_upgrade_from_thread(args):
	# Use deferred call to modify the nodes here given we are in a thread
	$container/upgrade_task_container.call_deferred("show")
	var label = $container/upgrade_task_container/label
	var progress_bar = $container/upgrade_task_container/progress_bar

	for i in range(0, len(addons)):
		var addon = addons[i]
		progress_bar.call_deferred("value", (i + 1) * 100 / (len(addons) + 1))
		label.call_deferred("text", "Upgrading: %s" % addon.display_name)
		var ret = yield(addon.upgrade_to_latest_version(), "completed")
		if ret[0] != OK:
			print("Error while upgrading %s: %s" % [addon.display_name, ret[1]])

	$container/upgrade_task_container.call_deferred("hide")
	$container/upgrade_button.call_deferred("set", "disabled", not _upgrade_needed())
	call_deferred("_cleanup_upgrade_thread_var")


func _upgrade_needed() -> bool:
	for addon in addons:
		if addon.upgrade_needed():
			return true
	return false


func _retreive_latest_versions():
	# Ensure no concurrent operation could occurs
	if not _retreive_latest_versions_task:
		_retreive_latest_versions_task = _do_retreive_latest_versions()
	return yield(_retreive_latest_versions_task, "completed")


func _do_retreive_latest_versions():
	$container/upgrade_button.disabled = true
	$container/retreive_latests_version_task_container.show()
	var label = $container/retreive_latests_version_task_container/label
	var progress_bar = $container/retreive_latests_version_task_container/progress_bar
	progress_bar.value = 1

	var http_request = HTTPRequest.new()
	http_request.use_threads = true
	http_request.timeout = 30
	add_child(http_request)

	for i in range(0, len(addons)):
		var addon = addons[i]
		progress_bar.value = (i + 1) * 100 / (len(addons) + 1)
		label.text = "Fetching update info: %s" % addon.display_name
		var ret = yield(addon.fetch_latest_version_info(http_request), "completed")
		if ret[0] != OK:
			print("Error while fetching %s update info: %s" % [addon.display_name, ret[1]])

	# Teardown stuff, must stay last !
	remove_child(http_request)
	_retreive_latest_versions_task = null
	$container/retreive_latests_version_task_container.hide()
	$container/upgrade_button.disabled = not _upgrade_needed()
