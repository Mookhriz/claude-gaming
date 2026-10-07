extends Node
## Loads every script under res://scripts with the autoloads in place and reports any that fail to compile.


func _ready() -> void:
	var failed: int = 0
	var paths: Array[String] = []
	_collect("res://scripts", paths)
	for path: String in paths:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("FAILED ", path)
			failed += 1
	print("compile_check: %d scripts, %d failed" % [paths.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	for dir: String in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(dir), out)
