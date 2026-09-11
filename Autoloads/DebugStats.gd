extends CanvasLayer
## Debug overlay: scene / GPU object counters, refreshed twice per second.
## Register as autoload "DebugStats". F3 toggles the overlay, F4 prints a node census.
## During a run, look for a counter that only ever goes UP and never comes back down.

const REFRESH_INTERVAL : float = 0.5
const CENSUS_TOP : int = 15

var _label : Label
var _accumulator : float = 0.0
var _stats_visible : bool = true
var _worst_delta : float = 0.0

func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Vector2(8.0, 8.0)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color.YELLOW)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


#func _process(delta : float) -> void:
	#_worst_delta = maxf(_worst_delta, delta)
	#_accumulator += delta
	#if _accumulator < REFRESH_INTERVAL or not _stats_visible:
		#return
	#_accumulator = 0.0
	#var text : String = "FPS %d   worst frame %.1f ms\n" % [
		#Performance.get_monitor(Performance.TIME_FPS), _worst_delta * 1000.0]
	#text += "Process %.1f ms   Physics %.1f ms\n" % [
		#Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		#Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]
	#text += "Nodes %d   Orphans %d   Resources %d\n" % [
		#Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		#Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		#Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)]
	#text += "Objects drawn %d   Draw calls %d\n" % [
		#Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		#Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	#text += "Video %.1f MB   Texture %.1f MB   Buffer %.1f MB" % [
		#Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		#Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		#Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0]
	#_label.text = text
	#_worst_delta = 0.0


#func _unhandled_input(event : InputEvent) -> void:
	#if not (event is InputEventKey) or not event.pressed or event.echo:
		#return
	#if event.keycode == KEY_F3:
		#_stats_visible = not _stats_visible
		#_label.visible = _stats_visible
	#elif event.keycode == KEY_F4:
		#_print_node_census()
	#elif event.keycode == KEY_F9:
		#_print_particles_census()


## F5: where do the GPUParticles2D come from? Groups them by owning scene file
## and by parent node, and sums the particle buffers they hold.
func _print_particles_census() -> void:
	var by_scene : Dictionary = {}
	var by_parent : Dictionary = {}
	var total : int = 0
	var emitting : int = 0
	var amount_total : int = 0
	var stack : Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node : Node = stack.pop_back()
		if node is GPUParticles2D:
			var particles : GPUParticles2D = node as GPUParticles2D
			total += 1
			if particles.emitting:
				emitting += 1
			amount_total += particles.amount
			var scene_key : String = "(no owner)"
			if particles.owner != null and particles.owner.scene_file_path != "":
				scene_key = particles.owner.scene_file_path.get_file()
			by_scene[scene_key] = int(by_scene.get(scene_key, 0)) + 1
			var parent : Node = particles.get_parent()
			var parent_key : String = "(root)"
			if parent != null:
				parent_key = parent.get_class() + " '" + parent.name + "'"
				var parent_script : Script = parent.get_script() as Script
				if parent_script != null:
					parent_key += " (" + parent_script.resource_path.get_file() + ")"
			by_parent[parent_key] = int(by_parent.get(parent_key, 0)) + 1
		for child : Node in node.get_children(true):
			stack.push_back(child)
	print("=== GPUParticles2D: %d nodes, %d emitting, %d particle slots allocated ===" % [total, emitting, amount_total])
	print("-- by scene file --")
	for key : String in by_scene:
		print("%6d  %s" % [by_scene[key], key])
	print("-- by parent --")
	for key : String in by_parent:
		print("%6d  %s" % [by_parent[key], key])


## Counts every node in the tree by engine class (+ script name), prints the most numerous.
func _print_node_census() -> void:
	var counts : Dictionary = {}
	var stack : Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node : Node = stack.pop_back()
		var key : String = node.get_class()
		var script : Script = node.get_script() as Script
		if script != null:
			key += " (" + script.resource_path.get_file() + ")"
		counts[key] = int(counts.get(key, 0)) + 1
		for child : Node in node.get_children(true):
			stack.push_back(child)
	var keys : Array = counts.keys()
	keys.sort_custom(func(a : String, b : String) -> bool: return counts[a] > counts[b])
	print("=== Node census: %d nodes, %d orphans ===" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	for i : int in mini(CENSUS_TOP, keys.size()):
		print("%6d  %s" % [counts[keys[i]], keys[i]])
