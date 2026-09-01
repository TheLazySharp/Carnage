extends CanvasLayer
## Reusable full-screen loading overlay, registered as the LoadingScreen autoload.
##
## Lives above every scene and survives scene changes, so it can stay visible
## across a change_scene_to_packed() — which a separate loading SCENE cannot do.
##
##
## Typical use:
##   await LoadingScreen.open("city generation…")
##   ... heavy work, calling set_progress() along the way ...
##   await LoadingScreen.close()

signal opened
signal closed

@export var fade_time : float = 0.25
## Messages picked at random when open() is called without one
@export var idle_messages : PackedStringArray = PackedStringArray()

var root : Control = null
var message : Label = null
var loading_bar : ProgressBar = null
var tween : Tween = null
var _is_open : bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = get_node_or_null("Root") as Control
	message = find_child("Message", true, false) as Label
	loading_bar = find_child("LoadingBar", true, false) as ProgressBar
	if root != null:
		root.modulate.a = 0.0
		root.visible = false
		root.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks while loading


## Fades the overlay in. Awaits until it is actually ON SCREEN, so the caller
## may start blocking work right after without the screen never appearing.
func open(p_message : String = "", fade_override : float = -1.0) -> void:
	set_message(p_message if !p_message.is_empty() else _random_message())
	set_progress(-1.0)
	if _is_open:
		return
	_is_open = true
	if root == null:
		return

	var duration : float = fade_time if fade_override < 0.0 else fade_override
	root.visible = true
	if duration <= 0.0:
		root.modulate.a = 1.0
	else:
		if tween != null:
			tween.kill()
		tween = create_tween()
		tween.tween_property(root, "modulate:a", 1.0, duration)
		await tween.finished
	# One rendered frame guarantees the overlay is visible before heavy work
	await RenderingServer.frame_post_draw
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	if root == null:
		closed.emit()
		return

	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, fade_time)
	await tween.finished
	root.visible = false
	closed.emit()


func set_message(text : String) -> void:
	if message != null:
		message.text = text


## ratio < 0 hides the bar (indeterminate work)
func set_progress(ratio : float) -> void:
	if loading_bar == null:
		return
	if ratio < 0.0:
		loading_bar.visible = false
		return
	loading_bar.visible = true
	loading_bar.value = clampf(ratio, 0.0, 1.0) * loading_bar.max_value


## Convenience for a pass-by-pass pipeline
func set_step(current : int, total : int, text : String = "") -> void:
	if not text.is_empty():
		set_message(text)
	set_progress(float(current) / float(maxi(total, 1)))


func is_open() -> bool:
	return _is_open


func _random_message() -> String:
	if idle_messages.is_empty():
		return "Loading…"
	return idle_messages[randi() % idle_messages.size()]
