extends Object


const GDUnzip = preload("gdunzip.gd")


# Stolen from GUT (MIT license Copyright (c) 2018 Tom "Butch" Wesley)
static func get_root_node() -> Node:
	var to_return = null
	var main_loop = Engine.get_main_loop()
	if(main_loop != null):
		return main_loop.root
	else:
		push_error('No Main Loop Yet')
		return null


# Use noop_yield() at the begining of a function so caller have the
# guarantee it will always be a coroutine function
static func noop_yield():
	yield(get_root_node().get_tree().create_timer(0), "timeout")


static func http_request_factory() -> HTTPRequest:
	var root = get_root_node()
	var http_request = HTTPRequest.new()
	http_request.use_threads = true
	http_request.timeout = 30
	root.add_child(http_request)
	return http_request


static func http_request_destructor(http_request: HTTPRequest):
	var root = get_root_node()
	root.remove_child(http_request)
	http_request.queue_free()


static func parse_version(str_version: String):
	var version = []
	for x in str_version.split('.'):
		if x.is_valid_integer():
			version.append(int(x))
		else:
			return null
	if len(version) != 3:
		return version
	else:
		return null


static func is_more_recent_version(old: Array, new: Array) -> bool:
	for item in range(3):
		var old_item = old[item]
		var new_item = new[item]
		if old_item == new_item:
			continue
		else:
			return old_item < new_item
	return false  # old and new are the same version


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


static func unzip(zip_path: String, target_path: String, filter: String = "") -> int:
	var gdunzip = GDUnzip.new()
	var loaded = gdunzip.load(zip_path)
	if loaded != true:
		push_error("Cannot load zip file %s" % zip_path)
		return FAILED

	var filenames
	if filter == "":
		filenames = gdunzip.files.keys()
	else:
		var filter_regex = RegEx.new()
		filter_regex.compile(filter)
		filenames = []
		for f in gdunzip.files:
			var file_name = f["file_name"]
			if filter_regex.search(file_name):
				filenames.push_back(file_name)

	# First create all needed directories
	var directories = {}
	for file_name in filenames:
		var dir_path = "%s/%s" % [target_path, file_name.get_base_dir()]
		directories[dir_path] = null
	var dir = Directory.new()
	for dir_path in directories.keys():
		var make_dir_res = dir.make_dir_recursive(dir_path)
		if make_dir_res != OK:
			push_error("Cannot create directory `%s` from zip %s" % [dir_path, zip_path])
			return FAILED

	# Then extract all files
	for file_name in filenames:
		var uncompressed = gdunzip.uncompress(file_name)
		if uncompressed == false:
			push_error("Cannot uncompresse `%s` from zip %s" % [file_name, zip_path])
			return FAILED
		var file = File.new()
		var file_path = "%s/%s" % [target_path, file_name]
		var file_open_res = file.open(file_path, File.WRITE)
		if file_open_res != OK:
			push_error("Cannot create file %s: error %s" % [file_path, file_open_res])
			return FAILED
		file.store_buffer(uncompressed)
		file.close()

	return OK


static func download(url: String, target_path: String = ""):
	yield(noop_yield(), "completed")  # Ensure we return a coroutine no matter what

	var http_request = http_request_factory()  # Don't forget to call destructor !
	var error = http_request.request(url)
	if error != OK:
		var msg = "Cannot initiate HTTP request %s (error %s)" % [
			url,
			error
		]
		http_request_destructor(http_request)
		return [FAILED, msg]

	var vars = yield(http_request, "request_completed")
	http_request_destructor(http_request)
	var http_result = vars[0]
	var status_code = vars[1]
	var body = vars[3]

	if http_result == HTTPRequest.RESULT_CANT_CONNECT:
		var msg = "Cannot reach %s (error RESULT_CANT_CONNECT)" % url
		return [FAILED, msg]
	elif http_result == HTTPRequest.RESULT_CANT_RESOLVE:
		var msg = "Cannot reach %s (error RESULT_CANT_RESOLVE)" % url
		return [FAILED, msg]
	elif http_result != OK:
		var msg = "Bad response from %s (error %s)" % [url, http_result]
		return [FAILED, msg]
	elif status_code != 200:
		var msg = "Bad response from %s (status code: %s)\n%s" % [
			url,
			error,
			body.get_string_from_utf8()
		]
		return [FAILED, msg]

	if target_path:
		var file = File.new()
		var file_open_res = file.open(target_path, File.WRITE)
		if file_open_res != OK:
			var msg = "Cannot create file %s: error %s" % [target_path, file_open_res]
			return [FAILED, msg]
		file.store_buffer(body)
		file.close()

	return [OK, body]
