tool
extends Object


# e.g. `foo-1.0.0-godot3.2-Linux-x86_64.tar.bz2` or `bar-1.0.0-godot4.tar.bz2`
const PACKAGE_PATTERN_TEMPLATE = (
    "^%s-(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)" +
    "-godot(?<godot_version_major>[0-9]+)(\\.(?<godot_version_minor>[0-9]+))?" +
    "(-(?<feature_tags>[a-zA-Z0-9_\\-]+))?" +
    "\\.tar\\.gz$"
)


# Use _noop_yield() at the begining of a function so caller have the
# guarantee it will always be a coroutine function
signal _noop_yield_signal
func _noop_yield():
    call_deferred("emit_signal", "_noop_yield_signal")
    yield(self, "_noop_yield_signal")


var plugin_name: String
var display_name: String
var _package_regex: RegEx
var _release_url: String
var _release_pattern: String
var _latest_version_info: Dictionary
var _fetch_error_msg: String
var _upgrade_error_msg: String


static func is_more_recent_version(old: Array, new: Array) -> bool:
    for item in range(3):
        var old_item = old[item]
        var new_item = new[item]
        if old_item == new_item:
            continue
        else:
            return old_item < new_item
    return false  # old and new are the same version


func _init(plugin_name: String, display_name: String, release_url: String):
    self.plugin_name = plugin_name
    self.display_name = display_name
    _release_url = release_url
    _release_pattern = PACKAGE_PATTERN_TEMPLATE % plugin_name
    _package_regex = RegEx.new()
    _package_regex.compile(_release_pattern)


static func rmdir(path: String) -> int:
    if OS.has_feature("Windows"):
        path = path.replace("/", "\\")
        return OS.execute("cmd.exe", ["/C", 'if exist "%s" ( del /Q /S /F "%s/*.*" && rmdir /Q /S "%s" )' % [path, path, path]])
    else:
        return OS.execute("sh", ["-c", "test -e '%s' && rm -rf '%s'" % [path, path]])


static func rm(path: String) -> int:
    if OS.has_feature("Windows"):
        path = path.replace("/", "\\")
        return OS.execute("cmd.exe", ["/C", 'if exist "%s" ( del "%s" )' % [path, path]])
    else:
        return OS.execute("sh", ["-c", "test -e '%s' && rm '%s'" % [path, path]])


static func mv(old_path: String, new_path: String) -> int:
    if OS.has_feature("Windows"):
        old_path = old_path.replace("/", "\\")
        new_path = new_path.replace("/", "\\")
        return OS.execute("cmd.exe", ["/C", 'move "%s" "%s"' % [old_path, new_path]])
    else:
        return OS.execute("sh", ["-c", "mv '%s' '%s'" % [old_path, new_path]])


func upgrade_to_latest_version():
    yield(_noop_yield(), "completed")  # Ensure we return a coroutine no matter what

    _upgrade_error_msg = ""
    if not upgrade_needed():
        return [OK, ""]

    var addons_path = ProjectSettings.globalize_path("res://addons")

    var target_path = "%s/%s" % [addons_path, plugin_name]
    var archive_path = "%s/%s" % [addons_path, _latest_version_info["archive_name"]]
    var old_data_tmp_path = "%s/%s-%s.tmp" % [addons_path, plugin_name, get_current_version(true)]

    # 1) Download new version
    # TODO: would be better to use HTTPClient to avoid blocking and display progress
    print("Downloading %s" % _latest_version_info["url"])
    if OS.execute("curl", ["-L", _latest_version_info["url"], "--output", archive_path, "--silent"]) != 0:
        _upgrade_error_msg = "Cannot download %s" % _latest_version_info["url"]
        return [FAILED, _upgrade_error_msg]

    # 2) Move current version with a temporary name
    # This may fail on Windows if some files are already in use
    print("Move %s -> %s" % [target_path, old_data_tmp_path])
    if mv(target_path, old_data_tmp_path) != 0:
        _upgrade_error_msg = "Cannot remove %s, is it in use ?" % target_path
        return [FAILED, _upgrade_error_msg]

    # 3) Extract new version, it becomes the current version
    # Filter the tar extraction so only the plugin folder get extracted
    print("Extract %s -> %s" % [archive_path, target_path])
    var tar_filter = "%s/" % plugin_name
    if OS.execute("tar", ["-xv", "-C", addons_path, "-f", archive_path, tar_filter]) != 0:
        _upgrade_error_msg = "Cannot extract %s" % archive_path
        # Try to reinstall the old version...
        rmdir(target_path)
        mv(old_data_tmp_path, target_path)
        return [FAILED, _upgrade_error_msg]

    # 5) Remove old version and new version archive
    print("Removing %s" % old_data_tmp_path)
    rmdir(old_data_tmp_path)
    print("Removing %s" % archive_path)
    rm(archive_path)

    return [OK, ""]


func fetch_latest_version_info(http_request: HTTPRequest, force: bool=false):
    yield(_noop_yield(), "completed")  # Ensure we return a coroutine no matter what

    _fetch_error_msg = ""
    if _latest_version_info and not force:
        return [OK, _latest_version_info]

    # First HTTP request...
    var error = http_request.request(_release_url)
    if error != OK:
        _fetch_error_msg = "Cannot start HTTP request (error: %s)" % error
        return [FAILED, _fetch_error_msg]
    var vars = yield(http_request, "request_completed")
    var http_result = vars[0]
    var status_code = vars[1]
    var body = vars[3]
    if http_result == HTTPRequest.RESULT_CANT_CONNECT or http_result == HTTPRequest.RESULT_CANT_RESOLVE:
        _fetch_error_msg = "Cannot reach %s (error: %s)" % [_release_url, error]
        return [FAILED, _fetch_error_msg]
    elif http_result != OK or status_code != 200:
        _fetch_error_msg = "Bad response from %s (status code: %s)\n%s)" % [_release_url, status_code, body.get_string_from_utf8()]
        return [FAILED, _fetch_error_msg]

    # ...then JSON parsing
    var json_result = JSON.parse(body.get_string_from_utf8())
    if json_result.error != OK or typeof(json_result.result) != TYPE_ARRAY:
        _fetch_error_msg = "Cannot retrieve release info: invalid JSON data"
        return [FAILED, _fetch_error_msg]
    var godot_version_major = Engine.get_version_info()["major"]
    var godot_version_minor = Engine.get_version_info()["minor"]
    # Consider the release are returned sorted with latest first
    for release in json_result.result:
        if release["prerelease"]:
            continue
        for asset in release["assets"]:
            var regex_result = _package_regex.search(asset["name"])
            if regex_result:
                var required_godot_version_major = regex_result.get_string("godot_version_major")
                if required_godot_version_major and int(required_godot_version_major) != godot_version_major:
                    continue
                var required_godot_version_minor = regex_result.get_string("godot_version_minor")
                if required_godot_version_minor and int(required_godot_version_minor) != godot_version_minor:
                    continue
                for required_feature in regex_result.get_string("feature_tags").split("-"):
                    if not OS.has_feature(required_feature):
                        continue
                # This version is compatible !
                var str_version = regex_result.get_string("version")
                var version = []
                for x in str_version.split('.'):
                    version.append(int(x))
                _latest_version_info = {
                    "str_version": str_version,
                    "version": version,
                    "archive_name": asset["name"],
                    "url": asset["browser_download_url"]
                }
                return [OK, _latest_version_info]

    _fetch_error_msg = "No compatible version found"
    return [FAILED, _fetch_error_msg]


func get_current_version(as_string=false):
    var config_path = "res://addons/%s/plugin.cfg" % plugin_name
    var config = ConfigFile.new()
    var err = config.load(config_path)
    if err != OK:
        return null
    else:
        var str_version = config.get_value("plugin", "version", "")
        var splitted = str_version.split(".")
        if len(splitted) != 3:  # We always do semver
            print("Invalid version `%s` (expect SemVer format) found in config %s" % [str_version, config_path])
            return null
        else:
            if as_string:
                return str_version
            var version = []
            for x in splitted:
                version.append(int(x))
            return version


func get_latest_version():
    if not _latest_version_info:
        return null
    return _latest_version_info["version"]


func get_fetch_error() -> String:
    return _fetch_error_msg


func upgrade_needed() -> bool:
    var current_version = get_current_version()
    if not _latest_version_info or not current_version:
        return false
    return is_more_recent_version(current_version, _latest_version_info["version"])
