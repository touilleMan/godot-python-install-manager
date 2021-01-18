tool
extends Object


const Utils = preload("utils.gd")


# e.g. `foo-1.0.0-godot3.2-Linux-x86_64.zip` or `bar-1.0.0-godot4.tar.bz2`
const PACKAGE_PATTERN_TEMPLATE = (
	"^%s-(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)" +
	"-godot(?<godot_version_major>[0-9]+)(\\.(?<godot_version_minor>[0-9]+))?" +
	"(-(?<feature_tags>[a-zA-Z0-9_\\-]+))?" +
	"\\.zip$"
)


var plugin_name: String
var display_name: String
var _package_regex: RegEx
var _release_url: String
var _upgrade_info: Array
var _release_pattern: String


func _init(plugin_name: String, display_name: String, release_url: String):
	self.plugin_name = plugin_name
	self.display_name = display_name
	_release_url = release_url
	_release_pattern = PACKAGE_PATTERN_TEMPLATE % plugin_name
	_package_regex = RegEx.new()
	_package_regex.compile(_release_pattern)


func upgrade_to_version(version: String):
	yield(Utils.noop_yield(), "completed")  # Ensure we return a coroutine no matter what

	# 0) Retrieve version info
	var info = null
	if version == "latest":
		if _upgrade_info.empty():
			return [FAILED, "No upgrade info available"]
		info = _upgrade_info[0]
	else:
		for item in _upgrade_info:
			if item["str_version"] == version:
				info = item
				break
		if info == null:
			return [FAILED, "Cannot retreive version %s" % version]

	var root_path = ProjectSettings.globalize_path("res://")
	var addons_path = ProjectSettings.globalize_path("res://addons")
	var target_path = "%s/%s" % [addons_path, plugin_name]
	var archive_path = "%s/%s" % [addons_path, info["archive_name"]]
	var old_data_tmp_path = "%s/%s-%s.tmp" % [addons_path, plugin_name, get_current_version(true)]

	# 1) Download new version archive
	print("Downloading %s" % info["url"])
	var download_res = yield(Utils.download(info["url"], archive_path), "completed")
	if download_res[0] != OK:
		var msg = "Cannot download upgrade: %s" % download_res[1]
		return [FAILED, msg]

	# 2) Move current version with a temporary name
	# This may fail on Windows if some files are already in use
	print("Move %s -> %s" % [target_path, old_data_tmp_path])
	if Utils.mv(target_path, old_data_tmp_path) != 0:
		var msg = "Cannot remove %s, is it in use ?" % target_path
		return [FAILED, msg]

	# 3) Extract new version, it becomes the current version
	print("Extracting %s" % archive_path)
	if Utils.unzip(archive_path, root_path, "^(%s\\.gdnlib$|addons/%s/)" % [plugin_name, plugin_name]) != OK:
		var msg = "Cannot extract %s" % archive_path
		# Try to reinstall the old version...
		Utils.rmdir(target_path)
		Utils.mv(old_data_tmp_path, target_path)
		return [FAILED, msg]

	# 4) Remove old version and new version archive
	print("Removing %s" % old_data_tmp_path)
	Utils.rmdir(old_data_tmp_path)
	print("Removing %s" % archive_path)
	Utils.rm(archive_path)

	return [OK, ""]


func fetch_upgrade_info(force: bool=false):
	yield(Utils.noop_yield(), "completed")  # Ensure we return a coroutine no matter what

	if _upgrade_info and not force:
		return [OK, _upgrade_info]
	_upgrade_info.clear()

	var download_res = yield(Utils.download(_release_url), "completed")
	if download_res[0] != OK:
		var msg = "Error while fetching %s upgrade info: %s" % [display_name, download_res[1]]
		return [FAILED, msg]

	# ...then JSON parsing
	var json_result = JSON.parse(download_res[1].get_string_from_utf8())
	if json_result.error != OK or typeof(json_result.result) != TYPE_ARRAY:
		var msg = "Error while fetching %s upgrade info: invalid JSON data" % [
			display_name
		]
		return [FAILED, msg]
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
				var has_unsupported_feature = false
				for required_feature in regex_result.get_string("feature_tags").split("-"):
					if required_feature == "":
						continue
					if not OS.has_feature(required_feature):
						has_unsupported_feature = true
						break
				if has_unsupported_feature:
					continue
				# This version is compatible !
				var str_version = regex_result.get_string("version")
				var version = []
				for x in str_version.split('.'):
					version.append(int(x))
				_upgrade_info.push_back({
					"str_version": str_version,
					"version": version,
					"archive_name": asset["name"],
					"url": asset["browser_download_url"]
				})

	if not _upgrade_info.empty():
		return [OK, _upgrade_info]
	else:
		return [FAILED, "No compatible version found"]


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
			print("Invalid version `%s` (expect X.Y.Z SemVer format) found in config %s" % [str_version, config_path])
			return null
		else:
			if as_string:
				return str_version
			var version = []
			for x in splitted:
				version.append(int(x))
			return version


func get_latest_version(as_string=false):
	if _upgrade_info.empty():
		return null
	if as_string:
		return _upgrade_info[0]["str_version"]
	else:
		return _upgrade_info[0]["version"]


func upgrade_needed() -> bool:
	var current_version = get_current_version()
	var latest_version = get_latest_version()
	if current_version == null or latest_version == null:
		return false
	return Utils.is_more_recent_version(current_version, latest_version)
