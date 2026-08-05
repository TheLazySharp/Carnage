class_name EnemiesMultiMeshRenderer
extends Node2D

@onready var car: Node2D = get_node_or_null("/root/World/Car")

var pools: Dictionary = {} #key = EnemyData, Value = EnemyTypePool
var corpse_pools: Dictionary = {} #key = EnemyData, Value = CorpsePool
var sprite_sheet_shader: Shader = null

# ---------------------- PERFS ----------------
var render_skip_timer: float = 0.0
var render_skip_steps: float = 0.033

func _ready() -> void:
	position = Vector2.ZERO
	sprite_sheet_shader = create_sprite_sheet_shader()

func get_pool(enemy_data: EnemyData) -> EnemyTypePool:
	if pools.has(enemy_data):
		return pools[enemy_data]

	var new_corpse_pool: CorpsePool = CorpsePool.new()
	new_corpse_pool.setup(enemy_data, sprite_sheet_shader)
	add_child(new_corpse_pool)
	corpse_pools[enemy_data] = new_corpse_pool

	var new_pool: EnemyTypePool = EnemyTypePool.new()
	new_pool.setup(enemy_data, sprite_sheet_shader, car)
	new_pool.corpse_pool = new_corpse_pool
	add_child(new_pool)
	pools[enemy_data] = new_pool
	return new_pool


func _process(delta: float) -> void:
	render_skip_timer += delta
	if render_skip_timer >= render_skip_steps:
		var step: float = render_skip_timer
		render_skip_timer = 0.0
		for pool: EnemyTypePool in pools.values():
			pool.update_instances(step)

	for corpse_pool: CorpsePool in corpse_pools.values():
		corpse_pool.flush()

func clear_all_corpses() -> void:
	for corpse_pool: CorpsePool in corpse_pools.values():
		corpse_pool.clear_all()

func create_sprite_sheet_shader() -> Shader:
	## Shader partagé par tous les pools.
	## custom_data.x = colonne de frame (normalisée 0..1)
	## custom_data.y = ligne d'état (normalisée 0..1)
	## custom_data.z = largeur d'une frame normalisée
	## custom_data.w = hauteur d'une frame normalisée

	var shader: Shader = Shader.new()
	shader.code = """

shader_type canvas_item;

varying float flash;
varying vec2 uv_scale;

void vertex() {
    vec4 cd = INSTANCE_CUSTOM;
    UV = cd.xy + UV * cd.zw;
    flash = COLOR.a;
    uv_scale = cd.zw;
}

void fragment() {
    vec4 col = texture(TEXTURE, UV);

    if (flash > 0.5) {
        vec2 texel = uv_scale / vec2(textureSize(TEXTURE, 0));
        float a_right = texture(TEXTURE, UV + vec2(texel.x, 0.0)).a;
        float a_left  = texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a;
        float a_up    = texture(TEXTURE, UV + vec2(0.0, -texel.y)).a;
        float a_down  = texture(TEXTURE, UV + vec2(0.0, texel.y)).a;
        float outline = clamp(a_right + a_left + a_up + a_down, 0.0, 1.0);

        if (col.a < 0.01) {
            COLOR = vec4(1.0, 0.0, 0.0, outline);
        } else {
            COLOR = vec4(1.0, 1.0, 1.0, col.a);
        }
    } else {
        if (col.a < 0.01) discard;
        COLOR = vec4(col.rgb, col.a);
    }
}
"""
	return shader


# ================================================================================
#------------------- EnemyTypePool — MultiMeshInstance2D per enemy type
#------------------- Enemies reach it from their mm_pool + mm_index 
# ================================================================================

class EnemyTypePool extends MultiMeshInstance2D:

	# ---------- BUFFER --------------------
	## Buffer plat envoyé au GPU en un seul appel.
	## 16 floats par instance : 8 transform (avec padding) + 4 color + 4 custom_data
	const FLOATS_PER_INSTANCE: int = 16
	const OFFSET_TRANSFORM: int = 0
	const OFFSET_COLOR: int = 8
	const OFFSET_CUSTOM: int = 12

	var enemy_data: EnemyData = null
	var car: Node2D = null
	var sprite_angle_offset_radians: float = 0.0

	# --------------ANIMATION STATES -----------------------
	var state_variants: Dictionary = {}#key = state_name, Value = Array[EnemySpriteState]
	var default_state_variants: Array[EnemySpriteState] = []

	# --------- SPRITE SHEET -------------------
	var max_instances: int = 0
	var frame_uv_width: float = 0.0
	var frame_uv_height: float = 0.0

	# ----------- INSTANCES ---------------------
	var free_instance_indices: Array[int] = []
	var active_instance_indices: Array[int] = []

	var corpse_pool: CorpsePool = null
	var finished_deaths: Array[int] = []

	var instance_enemies: Array[Enemy] = []
	var instance_states: Array[EnemySpriteState] = []
	var instance_frames: PackedInt32Array
	var instance_timers: PackedFloat32Array
	var instance_rotations: PackedFloat32Array    # rotation courante (radians) vers la voiture
	var instance_rows: PackedInt32Array           # ligne courante = sheet_row de l'état courant
	var instance_scales: Array[Vector2] = []
	var instance_last_positions: Array[Vector2] = []

	var buffer: PackedFloat32Array
	var buffer_is_dirty: bool = false

	func setup(data: EnemyData, sprite_sheet_shader: Shader, car_node: Node2D) -> void:
		enemy_data = data
		car = car_node
		sprite_angle_offset_radians = deg_to_rad(data.sprite_angle_offset)
		max_instances = data.max_rendered_instances
		name = "Pool_" + data.name

		if data.spritesheet == null:
			push_error("EnemyTypePool : spritesheet manquante pour " + data.name)
			return
		if data.sprite_states.is_empty():
			push_error("EnemyTypePool : aucun EnemySpriteState défini pour " + data.name)
			return

		for sprite_state: EnemySpriteState in data.sprite_states:
			var key: String = sprite_state.state_name.to_lower()
			if !state_variants.has(key):
				var variants: Array[EnemySpriteState] = []
				state_variants[key] = variants
			state_variants[key].append(sprite_state)

		if state_variants.has("walk"):
			default_state_variants = state_variants["walk"]
		else:
			default_state_variants = state_variants[data.sprite_states[0].state_name.to_lower()]

		frame_uv_width = float(data.frame_size.x) / float(data.spritesheet.get_width())
		frame_uv_height = float(data.frame_size.y) / float(data.spritesheet.get_height())

		instance_enemies.resize(max_instances)
		instance_states.resize(max_instances)
		instance_frames.resize(max_instances)
		instance_timers.resize(max_instances)
		instance_rotations.resize(max_instances)
		instance_rows.resize(max_instances)
		instance_scales.resize(max_instances)
		instance_last_positions.resize(max_instances)
		instance_scales.fill(Vector2.ONE)

		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(data.frame_size)

		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = quad
		mm.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
		mm.instance_count = max_instances
		mm.visible_instance_count = -1
		multimesh = mm
		texture = data.spritesheet

		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = sprite_sheet_shader
		material = shader_material

		# Initialiser le buffer plat : hors écran + blanc + UV frame 0
		buffer = PackedFloat32Array()
		buffer.resize(max_instances * FLOATS_PER_INSTANCE)
		buffer.fill(0.0)

		for i: int in range(max_instances):
			var base: int = i * FLOATS_PER_INSTANCE
			# Transform : tout à zéro (déjà fait par fill), instance invisible
			# Color : blanc opaque, alpha 0 = pas de flash
			buffer[base + 8]  = 1.0
			buffer[base + 9]  = 1.0
			buffer[base + 10] = 1.0
			buffer[base + 11] = 0.0
			# Custom data : UV frame 0
			buffer[base + 12] = 0.0
			buffer[base + 13] = 0.0
			buffer[base + 14] = frame_uv_width
			buffer[base + 15] = frame_uv_height

		RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)

		# Pré-remplir les indices libres
		free_instance_indices.resize(max_instances)
		for i: int in range(max_instances):
			free_instance_indices[i] = max_instances - 1 - i


	# ─────────────────────────────────────────────
	#  public API called by enemies
	# ─────────────────────────────────────────────

	func register_enemy(enemy: Enemy) -> int:
		if free_instance_indices.is_empty():
			push_warning("EnemyTypePool (" + enemy_data.name + ") : max_rendered_instances atteint !")
			return -1

		var idx: int = free_instance_indices.pop_back()
		active_instance_indices.append(idx)

		var base: int = idx * FLOATS_PER_INSTANCE + OFFSET_COLOR
		buffer[base + 0] = 1.0
		buffer[base + 1] = 1.0
		buffer[base + 2] = 1.0
		buffer[base + 3] = 0.0

		var initial_rotation: float = angle_to_car(enemy.global_position)
		var initial_state: EnemySpriteState = default_state_variants.pick_random()

		instance_enemies[idx] = enemy
		instance_states[idx] = initial_state
		instance_frames[idx] = 0
		instance_timers[idx] = 0.0
		instance_rotations[idx] = initial_rotation
		instance_rows[idx] = initial_state.sheet_row
		instance_scales[idx] = enemy_data.scale_mod
		instance_last_positions[idx] = Vector2.INF

		write_transform(idx, enemy.global_position, initial_rotation, false, enemy_data.scale_mod)
		write_uv(idx, 0, initial_state.sheet_row)
		return idx


	func unregister_enemy(instance_index: int) -> void:
		if instance_index < 0:
			return

		var base: int = instance_index * FLOATS_PER_INSTANCE
		for offset: int in range(8):
			buffer[base + offset] = 0.0
		buffer_is_dirty = true

		instance_enemies[instance_index] = null
		active_instance_indices.erase(instance_index)
		free_instance_indices.push_back(instance_index)


	func set_enemy_state(instance_index: int, new_state_name: String) -> void:
		if instance_index < 0 or instance_enemies[instance_index] == null:
			return
		var key: String = new_state_name.to_lower()
		if !state_variants.has(key):
			push_warning("EnemyTypePool (" + enemy_data.name + ") : unknown state : " + new_state_name)
			return
		# Déjà dans cet état (quel que soit le variant) -> on ne reroll pas.
		var current_state: EnemySpriteState = instance_states[instance_index]
		if current_state != null and current_state.state_name.to_lower() == key:
			return
		var new_state: EnemySpriteState = state_variants[key].pick_random()
		instance_states[instance_index] = new_state
		instance_frames[instance_index] = 0
		instance_timers[instance_index] = 0.0
		instance_rows[instance_index] = new_state.sheet_row
		write_uv(instance_index, 0, new_state.sheet_row)


	func set_enemy_color(instance_index: int, color: Color) -> void:
		if instance_index < 0:
			return
		var base: int = instance_index * FLOATS_PER_INSTANCE + OFFSET_COLOR
		buffer[base + 0] = color.r
		buffer[base + 1] = color.g
		buffer[base + 2] = color.b
		buffer[base + 3] = color.a
		buffer_is_dirty = true


	func set_enemy_flash(instance_index: int, flashing: bool) -> void:
		if instance_index < 0:
			return
		var base: int = instance_index * FLOATS_PER_INSTANCE + OFFSET_COLOR
		buffer[base + 3] = 1.0 if flashing else 0.0
		buffer_is_dirty = true


	func set_enemy_scale(instance_index: int, new_scale: Vector2) -> void:
		if instance_index < 0:
			return
		instance_scales[instance_index] = new_scale
		instance_last_positions[instance_index] = Vector2.INF


	# ─────────────────────────────────────────────
	#  UPDATE — called by parent renderer
	# ─────────────────────────────────────────────

	func update_instances(step: float) -> void:
		if multimesh == null:
			return

		for k: int in range(active_instance_indices.size() - 1, -1, -1):
			var idx: int = active_instance_indices[k]
			var enemy: Enemy = instance_enemies[idx]
			if !is_instance_valid(enemy):
				continue

			# ── Transform ──
			var pos: Vector2 = enemy.global_position
			var rot: float = instance_rotations[idx]
			if !enemy.is_dead:
				var state_name: String = ""
				var state_machine: Node = enemy.state_machine
				if state_machine != null and state_machine.current_state != null:
					state_name = String(state_machine.current_state.name).to_lower()
				if state_name == "chase" or state_name == "attack":
					rot = angle_to_car(pos)
				elif enemy.velocity.length_squared() > 0.01:
					rot = enemy.velocity.angle() + sprite_angle_offset_radians
			if pos != instance_last_positions[idx] or rot != instance_rotations[idx]:
				instance_last_positions[idx] = pos
				instance_rotations[idx] = rot
				write_transform(idx, pos, rot, false, instance_scales[idx])

			# ── Animation ──
			var sprite_state: EnemySpriteState = instance_states[idx]
			if sprite_state == null:
				continue
			instance_timers[idx] += step
			var frame_duration: float = 1.0 / sprite_state.fps
			if instance_timers[idx] < frame_duration:
				continue
			instance_timers[idx] -= frame_duration

			var last_frame: int = sprite_state.frame_count - 1
			var next_frame: int
			if sprite_state.loop:
				next_frame = (instance_frames[idx] + 1) % sprite_state.frame_count
			else:
				next_frame = mini(instance_frames[idx] + 1, last_frame)

			if next_frame != instance_frames[idx]:
				instance_frames[idx] = next_frame
				write_uv(idx, next_frame, instance_rows[idx])

			if sprite_state.is_death_state and instance_frames[idx] >= last_frame:
				finished_deaths.append(idx)

		# ── Transferts living -> corpses (out of loop)
		for dead_idx: int in finished_deaths:
			finalize_death(dead_idx)
		finished_deaths.clear()

		if buffer_is_dirty:
			RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)
			buffer_is_dirty = false


	## drop corpse on final position, free index.
	func finalize_death(instance_index: int) -> void:
		var enemy: Enemy = instance_enemies[instance_index]
		if enemy == null:
			return

		var final_position: Vector2 = enemy.global_position if is_instance_valid(enemy) else instance_last_positions[instance_index]

		if corpse_pool != null:
			corpse_pool.add_corpse(
				final_position,
				instance_rotations[instance_index],
				instance_scales[instance_index],
				instance_frames[instance_index],
				instance_rows[instance_index]
			)

		unregister_enemy(instance_index)

		if is_instance_valid(enemy):
			enemy.on_death_finished()

	# ─────────────────────────────────────────────
	#  INTERNES
	# ─────────────────────────────────────────────

	func angle_to_car(pos: Vector2) -> float:
		if car == null:
			return 0.0
		return (car.global_position - pos).angle() + sprite_angle_offset_radians


	func write_transform(idx: int, pos: Vector2, rot: float, flip_h: bool, new_scale: Vector2 = Vector2.ONE) -> void:
		var scale_x: float = -new_scale.x if flip_h else new_scale.x
		var scale_y: float = new_scale.y
		var xf: Transform2D = Transform2D(rot, pos)
		xf.x *= scale_x   # axe X mis à l'échelle (et inversé si flip)
		xf.y *= scale_y   # axe Y mis à l'échelle
		var base: int = idx * FLOATS_PER_INSTANCE + OFFSET_TRANSFORM
		buffer[base + 0] = xf.x.x     # x.x
		buffer[base + 1] = xf.y.x     # y.x
		buffer[base + 2] = 0.0        # padding
		buffer[base + 3] = xf.origin.x
		buffer[base + 4] = xf.x.y     # x.y
		buffer[base + 5] = xf.y.y     # y.y
		buffer[base + 6] = 0.0        # padding
		buffer[base + 7] = xf.origin.y
		buffer_is_dirty = true


	func write_uv(idx: int, frame_col: int, frame_row: int) -> void:
		var base: int = idx * FLOATS_PER_INSTANCE + OFFSET_CUSTOM
		buffer[base + 0] = frame_col * frame_uv_width   # u_offset
		buffer[base + 1] = frame_row * frame_uv_height  # v_offset
		buffer[base + 2] = frame_uv_width
		buffer[base + 3] = frame_uv_height
		buffer_is_dirty = true


# ================================================================================
#------------------- CorpsePool — MultiMeshInstance2D of static corpses
#------------------- no animation, one draw call.
# ================================================================================

class CorpsePool extends MultiMeshInstance2D:

	const FLOATS_PER_INSTANCE: int = 16
	const OFFSET_TRANSFORM: int = 0
	const OFFSET_COLOR: int = 8
	const OFFSET_CUSTOM: int = 12

	var max_corpses: int = 500
	var write_cursor: int = 0
	var frame_uv_width: float = 0.0
	var frame_uv_height: float = 0.0

	var buffer: PackedFloat32Array
	var buffer_is_dirty: bool = false


	func setup(data: EnemyData, sprite_sheet_shader: Shader) -> void:
		name = "Corpses_" + data.name
		max_corpses = maxi(1, data.max_corpses)
		z_index = data.corpse_z_index

		frame_uv_width = float(data.frame_size.x) / float(data.spritesheet.get_width())
		frame_uv_height = float(data.frame_size.y) / float(data.spritesheet.get_height())

		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(data.frame_size)

		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = quad
		mm.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
		mm.instance_count = max_corpses
		mm.visible_instance_count = -1
		multimesh = mm
		texture = data.spritesheet

		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = sprite_sheet_shader
		material = shader_material

		buffer = PackedFloat32Array()
		buffer.resize(max_corpses * FLOATS_PER_INSTANCE)
		buffer.fill(0.0)
		for i: int in range(max_corpses):
			var base: int = i * FLOATS_PER_INSTANCE
			buffer[base + 8]  = 1.0
			buffer[base + 9]  = 1.0
			buffer[base + 10] = 1.0
			buffer[base + 11] = 0.0   # pas de flash
			buffer[base + 14] = frame_uv_width
			buffer[base + 15] = frame_uv_height

		RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)


	## drop a corpses. if buffer is full, recycle the older one.
	func add_corpse(pos: Vector2, rot: float, corpse_scale: Vector2, frame_col: int, frame_row: int) -> void:
		var idx: int = write_cursor
		write_cursor = (write_cursor + 1) % max_corpses

		var xf: Transform2D = Transform2D(rot, pos)
		xf.x *= corpse_scale.x
		xf.y *= corpse_scale.y

		var base: int = idx * FLOATS_PER_INSTANCE
		buffer[base + 0] = xf.x.x
		buffer[base + 1] = xf.y.x
		buffer[base + 2] = 0.0
		buffer[base + 3] = xf.origin.x
		buffer[base + 4] = xf.x.y
		buffer[base + 5] = xf.y.y
		buffer[base + 6] = 0.0
		buffer[base + 7] = xf.origin.y

		buffer[base + OFFSET_COLOR + 0] = 1.0
		buffer[base + OFFSET_COLOR + 1] = 1.0
		buffer[base + OFFSET_COLOR + 2] = 1.0
		buffer[base + OFFSET_COLOR + 3] = 0.0

		buffer[base + OFFSET_CUSTOM + 0] = frame_col * frame_uv_width
		buffer[base + OFFSET_CUSTOM + 1] = frame_row * frame_uv_height
		buffer[base + OFFSET_CUSTOM + 2] = frame_uv_width
		buffer[base + OFFSET_CUSTOM + 3] = frame_uv_height

		buffer_is_dirty = true


	func flush() -> void:
		if !buffer_is_dirty:
			return
		RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)
		buffer_is_dirty = false


	func clear_all() -> void:
		buffer.fill(0.0)
		write_cursor = 0
		buffer_is_dirty = true
