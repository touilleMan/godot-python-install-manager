tool
extends WindowDialog


const INSTALL_MANAGER_REALEASES_URL = "https://api.github.com/repos/touilleMan/godot-python-install-manager/releases"
const PYTHONSCRIPT_REALEASES_URL = "https://api.github.com/repos/touilleMan/godot-python/releases"
const INSTALL_MANAGER_RELEASE_FILE_PATTERN = "^pythonscript-install-manager-(?<version>[0-9]+.[0-9]+.[0-9]+).tar.bz2$"
const PYTHONSCRIPT_RELEASE_FILE_PATTERN = "^pythonscript-(?<version>[0-9]+.[0-9]+.[0-9]+)-godot(?<godot_version>[0-9]+.[0-9]+)-(?<feature_tags>[a-zA-Z0-9_-]+).tar.bz2$"
const SETTINGS_LOOK_FOR_UPDATE_ON_STARTUP = "pythonscript_installer/look_for_update_on_startup"


onready var _install_manager_current_version = _get_plugin_version("pythonscript_install_manager")
var _install_manager_update_info = null
onready var _pythonscript_current_version = _get_plugin_version("pythonscript")
var _pythonscript_update_info = null
var _retreive_latest_versions_task = null


func _parse_version_string(version_string: String):
    var version = version_string.split(".")
    if len(version) != 3:  # We always do semvers
        return null
    else:
        return version


func _get_plugin_version(plugin_name: String):
    var config = ConfigFile.new()
    var err = config.load("res://addons/%s/plugin.cfg" % plugin_name)
    if err != OK:
        return null
    else:
        return _parse_version_string(config.get_value("plugin", "version", ""))


func _update_version_label(node: Label, current_version, latest_version):
    if current_version:
        if latest_version and latest_version > current_version:
            node.text = "%s.%s.%s (verson %s.%s.%s available)" % Array(current_version + latest_version)
            node.set("custom_colors/font_color", Color.yellow)
        else:
            if latest_version:
                node.text = "%s.%s.%s (latest version)" % Array(current_version)
            else:
                node.text = "%s.%s.%s" % Array(current_version)
            node.set("custom_colors/font_color", Color.green)
    else:
        node.text = "Not installed !"
        node.set("custom_colors/font_color", Color.red)


func _update_version_labels():
    _update_version_label(
        $container/install_manager_version/value,
        _install_manager_current_version,
        _install_manager_update_info["version"] if _install_manager_update_info else null
    )
    _update_version_label(
        $container/pythonscript_version/value,
        _pythonscript_current_version,
        _pythonscript_update_info["version"] if _pythonscript_update_info else null
    )

func _log_status(msg):
    $container/display_error_label.text += msg + "\n"
    $container/display_error_label.show()
    
func _log_error(msg):
    $container/display_error_label.text += "Error: %s\n" % msg
    $container/display_error_label.show()


func _clear_logs():
    $container/display_error_label.text = ""
    $container/display_error_label.hide()


func _retreive_latest_versions():
    # Ensure no concurrent operation could occurs
    if not _retreive_latest_versions_task:
        _retreive_latest_versions_task = _do_retreive_latest_versions()
    return yield(_retreive_latest_versions_task, "completed")


func _fetch_latest_version_info(http_request: HTTPRequest, url: String, release_file_pattern: String):
    # First HTTP request...
    var error = http_request.request(url)
    if error != OK:
        return [FAILED, "Cannot start HTTP request (error: %s)" % error]
    var vars = yield(http_request, "request_completed")
    var http_result = vars[0]
    var status_code = vars[1]
    var body = vars[3]
    if http_result == HTTPRequest.RESULT_CANT_CONNECT or http_result == HTTPRequest.RESULT_CANT_RESOLVE:
        return [FAILED, "Cannot reach %s (error: %s)" % [url, error]]
    elif http_result != OK or status_code != 200:
        return [FAILED, "Bad response from %s (status code: %s)" % [url, status_code]]

    # ...then JSON parsing
    var json_result = JSON.parse(body.get_string_from_utf8())
    if json_result.error != OK or typeof(json_result.result) != TYPE_ARRAY:
        return [FAILED, "Cannot retrieve release info: invalid JSON data"]
    var godot_version = "%s.%s" % [Engine.get_version_info()["major"], Engine.get_version_info()["minor"]]
    var regex = RegEx.new()
    regex.compile(release_file_pattern)
    # Consider the release are returned sorted with latest first
    for release in json_result.result:
        if release["prerelease"]:
            continue
        for asset in release["assets"]:
            pass
            var regex_result = regex.search(asset["name"])
            if regex_result:
                var required_godot_version = regex_result.get_string("version")
                if required_godot_version != godot_version:
                    continue
                for required_feature in regex_result.get_string("feature_tags").split("-"):
                    if not OS.has_feature(required_feature):
                        continue
                # This version is compatible !
                var str_version = regex_result.get_string("version")
                var version = []
                for x in str_version.split('.'):
                    version.append(int(x))
                var info = {
                    "str_version": str_version,
                    "version": version,
                    "archive_name": asset["name"],
                    "url": asset["browser_download_url"]
                }
                return [OK, info]

    return [FAILED, "Not compatible version found (you should upgrade Godot !)"]


func _do_retreive_latest_versions():
    $container/upgrade_button.visible = false
    $container/retreive_latests_version_task_container/progress_bar.value = 1
    $container/retreive_latests_version_task_container.show()
    var http_request = HTTPRequest.new()
    http_request.use_threads = true
    http_request.timeout = 30
    add_child(http_request)
    var ret

    # Retreive install manager
    ret = yield(
        _fetch_latest_version_info(http_request, INSTALL_MANAGER_REALEASES_URL, INSTALL_MANAGER_RELEASE_FILE_PATTERN),
        "completed"
    )
    if ret[0] == OK:
        _install_manager_update_info = ret[1]
    else:
        _log_error("Error while looking for install manager updates:\n%s" % ret[1])
    $container/retreive_latests_version_task_container/progress_bar.value = 50

    # Retreive pythonscript
    ret = yield(
        _fetch_latest_version_info(http_request, PYTHONSCRIPT_REALEASES_URL, PYTHONSCRIPT_RELEASE_FILE_PATTERN),
        "completed"
    )
    if ret[0] == OK:
        _install_manager_update_info = ret[1]
    else:
        _log_error("Error while looking for pythonscript updates:\n%s" % ret[1])
    $container/retreive_latests_version_task_container/progress_bar.value = 100

    # Teardown stuff, must stay last !
    remove_child(http_request)
    _retreive_latest_versions_task = null
    $container/retreive_latests_version_task_container.hide()
    $container/upgrade_button.visible = _upgrade_needed()


func _pythonscript_upgrade_needed() -> bool:
    return (
        _pythonscript_update_info and
        (
            _pythonscript_current_version == null or
            _pythonscript_current_version < _pythonscript_update_info["vesrion"]
        )
    )


func _install_manager_upgrade_needed() -> bool:
    return (
        _install_manager_update_info and
        (
            _install_manager_current_version == null or
            _install_manager_current_version < _install_manager_update_info["vesrion"]
        )
    )


func _upgrade_needed() -> bool:
    return _install_manager_upgrade_needed() or _pythonscript_upgrade_needed()


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
        if _upgrade_needed():
            $".".popup_centered()


func _on_manage_about_to_show():
    _clear_logs()
    yield(_retreive_latest_versions(), "completed")


func _upgrade_install_manager():
    if _install_manager_upgrade_needed():
        return
    $container/upgrade_task_container/label.text = "Downloading install manager version %s" % _install_manager_update_info["version_str"]
    var target_path = ProjectSettings.globalize_path("res://addons/pythonscript_install_manager")
    var archive_path = ProjectSettings.globalize_path("res://addons/%s" % _install_manager_update_info["archive_name"])
    # TODO: would be better to use HTTPClient to avoid blocking and display progress
    if OS.execute("curl", ["-L", _install_manager_update_info["url"], "--output", archive_path, "--silent"]) != 0:
        _log_error("Cannot download %s" % _install_manager_update_info["url"])
        return
    if OS.execute("tar", ["-xf", archive_path, "-C", target_path]) != 0:
        _log_error("Cannot extract %s in %s (do you have `tar` command ?)" % [archive_path, target_path])
        return
    # Finally change pythonscript.gdnlib to point on the new version


func _upgrade_pythonscript():
    yield()


func _on_upgrade_button_pressed():
    $container/upgrade_button.hide()
    $container/upgrade_task_container.show()

    yield(_upgrade_install_manager(), "completed")
    yield(_upgrade_pythonscript(), "completed")

    $container/upgrade_task_container.hide()
