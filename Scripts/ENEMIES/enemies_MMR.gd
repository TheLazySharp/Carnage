class_name EnemiesMultiMeshRenderer
extends Node2D

@onready var car: Node2D = get_node_or_null("/root/World/Car")
## Horde mass post-process. Null = enemies are always rendered individually.
@export var horde_outline: HordeOutline = null
var pools: Dictionary = {} #key = EnemyData, Value = EnemyTypePool
var corpse_pools: Dictionary = {} #key = EnemyData, Value = CorpsePool
var sprite_sheet_shader: Shader = null
## Max distinct state atlases per enemy type (size of the shader uniform array)
const MAX_STATE_LAYERS: int = 16

# ---------------------- PERFS ----------------
var render_skip_timer: float = 0.0
var render_skip_steps: float = 0.033

func _ready() -> void:
	position = Vector2.ZERO
	sprite_sheet_shader = create_sprite_sheet_shader()
	SignalManager.next_day.connect(clear_all_corpses)

func get_pool(enemy_data: EnemyData) -> EnemyTypePool:
	if pools.has(enemy_data):
		return pools[enemy_data]

	# Living pool first: it builds the state atlas array shared with the corpse pool
	var new_pool: EnemyTypePool = EnemyTypePool.new()
	new_pool.setup(enemy_data, sprite_sheet_shader, car)

	var new_corpse_pool: CorpsePool = CorpsePool.new()
	new_corpse_pool.setup(enemy_data, sprite_sheet_shader, new_pool.atlas_array, new_pool.layer_frame_uv_sizes)
	add_child(new_corpse_pool)
	corpse_pools[enemy_data] = new_corpse_pool

	new_pool.corpse_pool = new_corpse_pool
	add_child(new_pool)
	if horde_outline != null:
		horde_outline.register_sprite_size(Vector2(enemy_data.frame_size) * enemy_data.scale_mod)
		new_pool.create_mass_twin(horde_outline.pools_root)
	pools[enemy_data] = new_pool
	return new_pool

func _process(delta: float) -> void:
	render_skip_timer += delta
	if render_skip_timer >= render_skip_steps:
		var step: float = render_skip_timer
		render_skip_timer = 0.0

		# Horde mass membership: pass 1 counts candidates per cell, pass 2 (in update_instances) resolves
		var outline_active: bool = horde_outline != null and horde_outline.enabled and horde_outline.begin_step()
		var active_outline: HordeOutline = horde_outline if outline_active else null
		if outline_active:
			for pool: EnemyTypePool in pools.values():
				pool.count_into_mass(horde_outline)

		for pool: EnemyTypePool in pools.values():
			pool.update_instances(step, active_outline)

	for corpse_pool: CorpsePool in corpse_pools.values():
		corpse_pool.flush()

func clear_all_corpses() -> void:
	for corpse_pool: CorpsePool in corpse_pools.values():
		corpse_pool.clear_all()

func create_sprite_sheet_shader() -> Shader:
	## Shader shared by every pool.
	## custom_data.x = frame column offset (normalized UV)
	## custom_data.y = variant row offset (normalized UV)
	## custom_data.z = layer index in atlas_array (one layer per state atlas)
	## custom_data.w = mass flag: -1 = instance inside a horde mass, +1 = outside
	## layer_frame_uv_sizes : normalized cell size of each layer (cells can differ between atlases)
	## mass_filter : 0 = draw all (corpses / no mass), 1 = only instances outside a mass, 2 = only instances inside a mass

	var code: String = """

shader_type canvas_item;

uniform int mass_filter = 0;
uniform sampler2DArray atlas_array : filter_nearest, repeat_disable;
uniform vec2 layer_frame_uv_sizes[__MAX_LAYERS__];

varying float flash;
varying flat float atlas_layer;
varying flat vec2 frame_uv_size;

void vertex() {
    vec4 cd = INSTANCE_CUSTOM;
    bool in_mass = cd.w < 0.0;
    frame_uv_size = layer_frame_uv_sizes[int(cd.z)];
    UV = cd.xy + UV * frame_uv_size;
    atlas_layer = cd.z;
    flash = COLOR.a;
    if ((mass_filter == 1 && in_mass) || (mass_filter == 2 && !in_mass)) {
        VERTEX = vec2(0.0);   // collapse the quad: nothing rasterized
    }
}

void fragment() {
    vec4 col = texture(atlas_array, vec3(UV, atlas_layer));

    if (flash > 0.5) {
        vec2 texel = frame_uv_size / vec2(textureSize(atlas_array, 0).xy);
        float a_right = texture(atlas_array, vec3(UV + vec2(texel.x, 0.0), atlas_layer)).a;
        float a_left  = texture(atlas_array, vec3(UV + vec2(-texel.x, 0.0), atlas_layer)).a;
        float a_up    = texture(atlas_array, vec3(UV + vec2(0.0, -texel.y), atlas_layer)).a;
        float a_down  = texture(atlas_array, vec3(UV + vec2(0.0, texel.y), atlas_layer)).a;
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
	var shader: Shader = Shader.new()
	shader.code = code.replace("__MAX_LAYERS__", str(MAX_STATE_LAYERS))
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
	var rotation_snap_step: float = 0.0
	
	# --------------ANIMATION STATES -----------------------
	var state_variants: Dictionary = {}#key = state_name, Value = Array[EnemySpriteState]
	var default_state_variants: Array[EnemySpriteState] = []

	# --------- SPRITE SHEET -------------------
	var max_instances: int = 0
	
	# --------- STATE ATLASES (one Texture2DArray layer per state atlas) ---------
	var atlas_array: Texture2DArray = null
	var state_layers: Dictionary = {} # key = EnemySpriteState, Value = int (layer in atlas_array)
	var layer_variant_counts: PackedInt32Array # variants (rows) available in each layer
	var layer_row_frame_counts: Array[PackedInt32Array] = [] # [layer][row] = frames detected in that variant row
	var layer_frame_uv_sizes: PackedVector2Array # normalized cell size per layer (sized to MAX_STATE_LAYERS for the shader)
	var layer_quad_scales: PackedVector2Array    # layer cell size / EnemyData.frame_size, applied on the transform
	
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
	var instance_air_scales: PackedFloat32Array   # last drawn fake-flight scale (1 = ground)
	var instance_air_spins: PackedFloat32Array    # last drawn flight spin (rad)
	var instance_layers: PackedInt32Array         # current layer = atlas of the current state
	var instance_in_mass: PackedByteArray   # 1 = rendered in the horde mass viewport
	var instance_frame_counts: PackedInt32Array   # frame count of the current variant row
	var mass_twin: MultiMeshInstance2D = null   # shares this pool's MultiMesh, lives in HordeOutline/SourceViewport
	var buffer: PackedFloat32Array
	var buffer_is_dirty: bool = false

	func setup(data: EnemyData, sprite_sheet_shader: Shader, car_node: Node2D) -> void:
		enemy_data = data
		car = car_node
		sprite_angle_offset_radians = deg_to_rad(data.sprite_angle_offset)
		rotation_snap_step = EnemyManager.get_rotation_snap_step()
		max_instances = data.max_rendered_instances
		name = "Pool_" + data.name

		if data.sprite_states.is_empty():
			push_error("EnemyTypePool : no EnemySpriteState defined for " + data.name)
			return

		for sprite_state: EnemySpriteState in data.sprite_states:
			# Death states are keyed by their Death_Types: no typo possible with WeaponData
			var key: String = EnemyManager.get_death_state_name(sprite_state.death_type) if sprite_state.is_death_state else sprite_state.state_name.to_lower()
			if !state_variants.has(key):
				var variants: Array[EnemySpriteState] = []
				state_variants[key] = variants
			state_variants[key].append(sprite_state)

		if state_variants.has("walk"):
			default_state_variants = state_variants["walk"]
		else:
			default_state_variants = state_variants[data.sprite_states[0].state_name.to_lower()]

		if !build_atlas_array(data):
			return

		instance_enemies.resize(max_instances)
		instance_states.resize(max_instances)
		instance_frames.resize(max_instances)
		instance_timers.resize(max_instances)
		instance_rotations.resize(max_instances)
		instance_rows.resize(max_instances)
		instance_layers.resize(max_instances)
		instance_layers.fill(0)
		instance_frame_counts.resize(max_instances)
		instance_frame_counts.fill(1)
		instance_scales.resize(max_instances)
		instance_last_positions.resize(max_instances)
		instance_scales.fill(Vector2.ONE)

		instance_in_mass.resize(max_instances)
		instance_in_mass.fill(0)

		instance_air_scales.resize(max_instances)
		instance_air_scales.fill(1.0)
		instance_air_spins.resize(max_instances)
		instance_air_spins.fill(0.0)

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

		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = sprite_sheet_shader
		shader_material.set_shader_parameter("mass_filter", 0)
		shader_material.set_shader_parameter("atlas_array", atlas_array)
		shader_material.set_shader_parameter("layer_frame_uv_sizes", layer_frame_uv_sizes)
		material = shader_material

		# Flat buffer init: off-screen + white + frame 0 of layer 0, outside mass
		buffer = PackedFloat32Array()
		buffer.resize(max_instances * FLOATS_PER_INSTANCE)
		buffer.fill(0.0)

		for i: int in range(max_instances):
			var base: int = i * FLOATS_PER_INSTANCE
			# Color: white, alpha 0 = no flash
			buffer[base + 8]  = 1.0
			buffer[base + 9]  = 1.0
			buffer[base + 10] = 1.0
			buffer[base + 11] = 0.0
			# Custom data: u = 0, v = 0, layer = 0 (fill), mass flag = +1
			buffer[base + 15] = 1.0

		RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)

		# Pre-fill free indices
		free_instance_indices.resize(max_instances)
		for i: int in range(max_instances):
			free_instance_indices[i] = max_instances - 1 - i

	## Packs every state atlas into one Texture2DArray (one layer per distinct texture).
	## Smaller atlases are padded top-left so all layers share the same texture size.
	## Each layer keeps its own cell size. Runs once per enemy type.
	func build_atlas_array(data: EnemyData) -> bool:
		var images: Array[Image] = []
		var layer_frame_sizes: Array[Vector2i] = []
		var texture_layers: Dictionary = {} # key = Texture2D, Value = int layer
		var max_width: int = 0
		var max_height: int = 0
		layer_variant_counts.clear()
		layer_row_frame_counts.clear()
		layer_quad_scales.clear()
		layer_frame_uv_sizes.clear()

		for sprite_state: EnemySpriteState in data.sprite_states:
			var state_texture: Texture2D = sprite_state.spritesheet
			if state_texture == null:
				push_error("EnemyTypePool (" + data.name + ") : missing spritesheet for state " + sprite_state.state_name)
				return false
			# Several EnemySpriteState can share the same atlas: one layer only
			if texture_layers.has(state_texture):
				state_layers[sprite_state] = texture_layers[state_texture]
				continue
			if images.size() >= EnemiesMultiMeshRenderer.MAX_STATE_LAYERS:
				push_error("EnemyTypePool (" + data.name + ") : too many state atlases (max " + str(EnemiesMultiMeshRenderer.MAX_STATE_LAYERS) + ")")
				return false

			var state_frame_size: Vector2i = sprite_state.frame_size if sprite_state.frame_size != Vector2i.ZERO else data.frame_size

			var image: Image = state_texture.get_image()
			if image.is_compressed():
				image.decompress()
			image.clear_mipmaps()
			image.convert(Image.FORMAT_RGBA8)

			var layer: int = images.size()
			texture_layers[state_texture] = layer
			state_layers[sprite_state] = layer
			var variant_count: int = maxi(1, floori(float(image.get_height()) / float(state_frame_size.y)))
			layer_variant_counts.append(variant_count)
			layer_row_frame_counts.append(detect_row_frame_counts(image, state_frame_size, variant_count))
			layer_quad_scales.append(Vector2(state_frame_size) / Vector2(data.frame_size))
			layer_frame_sizes.append(state_frame_size)
			images.append(image)
			max_width = maxi(max_width, image.get_width())
			max_height = maxi(max_height, image.get_height())

		# Texture2DArray requires identical layer sizes
		for i: int in range(images.size()):
			var image: Image = images[i]
			if image.get_width() == max_width and image.get_height() == max_height:
				continue
			var padded: Image = Image.create_empty(max_width, max_height, false, Image.FORMAT_RGBA8)
			padded.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
			images[i] = padded

		atlas_array = Texture2DArray.new()
		if atlas_array.create_from_images(images) != OK:
			push_error("EnemyTypePool (" + data.name + ") : Texture2DArray creation failed")
			atlas_array = null
			return false

		# Cell UV size per layer, relative to the padded texture size
		layer_frame_uv_sizes.resize(EnemiesMultiMeshRenderer.MAX_STATE_LAYERS)
		for layer: int in range(layer_frame_sizes.size()):
			layer_frame_uv_sizes[layer] = Vector2(
				float(layer_frame_sizes[layer].x) / float(max_width),
				float(layer_frame_sizes[layer].y) / float(max_height))
		return true
		
	## Frames per variant row = last non-transparent frame + 1 (scanned right to left).
	## Empty frames inside a row are kept, trailing empty frames are cut. Build time only.
	static func detect_row_frame_counts(image: Image, frame_size: Vector2i, variant_count: int) -> PackedInt32Array:
		var counts: PackedInt32Array
		counts.resize(variant_count)
		var column_count: int = floori(float(image.get_width()) / float(frame_size.x))
		for row: int in range(variant_count):
			var frames: int = 1
			for col: int in range(column_count - 1, -1, -1):
				var frame_rect: Rect2i = Rect2i(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
				if !image.get_region(frame_rect).is_invisible():
					frames = col + 1
					break
			counts[row] = frames
		return counts

	func has_state(state_name: String) -> bool:
		return state_variants.has(state_name.to_lower())

	# ─────────────────────────────────────────────
	#  public API called by enemies
	# ─────────────────────────────────────────────

	func register_enemy(enemy: Enemy) -> int:
		if free_instance_indices.is_empty():
			push_warning("EnemyTypePool (" + enemy_data.name + ") : max_rendered_instances reached !")
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
		var initial_layer: int = state_layers[initial_state]
		var initial_row: int = randi() % layer_variant_counts[initial_layer]

		instance_enemies[idx] = enemy
		instance_states[idx] = initial_state
		instance_frames[idx] = 0
		instance_timers[idx] = 0.0
		instance_rotations[idx] = initial_rotation
		instance_rows[idx] = initial_row
		instance_layers[idx] = initial_layer
		instance_frame_counts[idx] = layer_row_frame_counts[initial_layer][initial_row]
		instance_scales[idx] = enemy_data.scale_mod
		instance_last_positions[idx] = Vector2.INF
		instance_in_mass[idx] = 0
		instance_air_scales[idx] = 1.0
		instance_air_spins[idx] = 0.0

		write_transform(idx, enemy.global_position, initial_rotation, false, enemy_data.scale_mod)
		write_uv(idx, 0, initial_row)
		return idx


	func unregister_enemy(instance_index: int) -> void:
		if instance_index < 0:
			return

		var base: int = instance_index * FLOATS_PER_INSTANCE
		for offset: int in range(8):
			buffer[base + offset] = 0.0
		buffer_is_dirty = true

		instance_enemies[instance_index] = null
		instance_in_mass[instance_index] = 0
		active_instance_indices.erase(instance_index)
		free_instance_indices.push_back(instance_index)


	func set_enemy_state(instance_index: int, new_state_name: String) -> void:
		if instance_index < 0 or instance_enemies[instance_index] == null:
			return
		var key: String = new_state_name.to_lower()
		if !state_variants.has(key):
			push_warning("EnemyTypePool (" + enemy_data.name + ") : unknown state : " + new_state_name)
			return
		# Already in this state (any variant) -> no reroll
		var current_state: EnemySpriteState = instance_states[instance_index]
		if current_state != null and state_variants[key].has(current_state):
			return
		var new_state: EnemySpriteState = state_variants[key].pick_random()
		var new_layer: int = state_layers[new_state]
		var new_row: int = randi() % layer_variant_counts[new_layer]
		instance_states[instance_index] = new_state
		instance_frames[instance_index] = 0
		instance_timers[instance_index] = 0.0
		instance_rows[instance_index] = new_row
		instance_layers[instance_index] = new_layer
		instance_frame_counts[instance_index] = layer_row_frame_counts[new_layer][new_row]
		instance_last_positions[instance_index] = Vector2.INF   # force transform rewrite: quad scale depends on the layer
		write_uv(instance_index, 0, new_row)


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

	## Second MultiMeshInstance2D sharing this pool's MultiMesh, rendered inside the horde mass viewport.
	## Same buffer, same upload; the shader picks which instances each node draws.
	func create_mass_twin(parent: Node) -> void:
		mass_twin = MultiMeshInstance2D.new()
		mass_twin.name = "MassTwin_" + enemy_data.name
		mass_twin.multimesh = multimesh
		var twin_material: ShaderMaterial = (material as ShaderMaterial).duplicate() as ShaderMaterial
		twin_material.set_shader_parameter("mass_filter", 2)
		mass_twin.material = twin_material
		parent.add_child(mass_twin)
		(material as ShaderMaterial).set_shader_parameter("mass_filter", 1)


	## Alive and not being knocked back: a knocked enemy bursts out of the mass.
	func is_mass_candidate(enemy: Enemy, outline: HordeOutline) -> bool:
		if enemy.is_dead or enemy.air_duration > 0.0:
			return false
		return enemy.knockback_velocity.length_squared() < outline.knockback_exclusion_speed_squared


	## Pass 1 of the horde mass: count candidates in the grid.
	func count_into_mass(outline: HordeOutline) -> void:
		for idx: int in active_instance_indices:
			var enemy: Enemy = instance_enemies[idx]
			if !is_instance_valid(enemy) or !is_mass_candidate(enemy, outline):
				continue
			outline.add_count(enemy.global_position)


	## custom_data.w sign = mass membership (negative = drawn by the mass twin, positive = drawn in the world).
	func write_mass_flag(idx: int) -> void:
		var base: int = idx * FLOATS_PER_INSTANCE + OFFSET_CUSTOM
		buffer[base + 3] = -1.0 if instance_in_mass[idx] == 1 else 1.0
		buffer_is_dirty = true

	# ─────────────────────────────────────────────
	#  UPDATE — called by parent renderer
	# ─────────────────────────────────────────────

	func update_instances(step: float, outline: HordeOutline) -> void:
		if multimesh == null:
			return

		for k: int in range(active_instance_indices.size() - 1, -1, -1):
			var idx: int = active_instance_indices[k]
			var enemy: Enemy = instance_enemies[idx]
			if !is_instance_valid(enemy):
				continue

			var pos: Vector2 = enemy.global_position

			# ── Horde mass membership ──
			var in_mass: bool = false
			if outline != null and is_mass_candidate(enemy, outline):
				in_mass = outline.resolve(pos, instance_in_mass[idx] == 1)
			if in_mass != (instance_in_mass[idx] == 1):
				instance_in_mass[idx] = 1 if in_mass else 0
				write_mass_flag(idx)

			# ── Transform ──
			var rot: float = instance_rotations[idx]
			if !enemy.is_dead:
				rotation_snap_step = EnemyManager.get_rotation_snap_step()
				var state_name: String = ""
				var state_machine: Node = enemy.state_machine
				if state_machine != null and state_machine.current_state != null:
					state_name = String(state_machine.current_state.name).to_lower()
				if state_name == "chase" or state_name == "attack":
					rot = angle_to_car(pos)
				elif enemy.velocity.length_squared() > 0.01:
					rot = direction_to_rotation(enemy.velocity.angle())
			# Fake flight (JuiceSettings air throw): scale arc + spin on top of the base transform
			var air_scale: float = enemy.air_scale
			var air_spin: float = enemy.air_spin_angle
			if pos != instance_last_positions[idx] or rot != instance_rotations[idx] \
					or air_scale != instance_air_scales[idx] or air_spin != instance_air_spins[idx]:
				instance_last_positions[idx] = pos
				instance_rotations[idx] = rot
				instance_air_scales[idx] = air_scale
				instance_air_spins[idx] = air_spin
				write_transform(idx, pos, rot + air_spin, false, instance_scales[idx] * air_scale)

			# ── Animation ──
			var sprite_state: EnemySpriteState = instance_states[idx]
			if sprite_state == null:
				continue
			instance_timers[idx] += step
			var frame_duration: float = 1.0 / sprite_state.fps
			if instance_timers[idx] < frame_duration:
				continue
			instance_timers[idx] -= frame_duration

			var frame_count: int = instance_frame_counts[idx]
			var last_frame: int = frame_count - 1
			var next_frame: int
			if sprite_state.loop:
				next_frame = (instance_frames[idx] + 1) % frame_count
			else:
				next_frame = mini(instance_frames[idx] + 1, last_frame)

			if next_frame != instance_frames[idx]:
				instance_frames[idx] = next_frame
				write_uv(idx, next_frame, instance_rows[idx])

			# Corpse drops once the death anim is over AND the body landed and stopped sliding
			if sprite_state.is_death_state and instance_frames[idx] >= last_frame \
					and enemy.air_duration <= 0.0 \
					and enemy.knockback_velocity.length_squared() <= 1.0:
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
				instance_rotations[instance_index] + instance_air_spins[instance_index],
				instance_scales[instance_index] * layer_quad_scales[instance_layers[instance_index]],
				instance_frames[instance_index],
				instance_rows[instance_index],
				instance_layers[instance_index]
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
		return direction_to_rotation((car.global_position - pos).angle())

	func direction_to_rotation(direction_angle: float) -> float:
		if rotation_snap_step > 0.0:
			direction_angle = snappedf(direction_angle, rotation_snap_step)
		return direction_angle + sprite_angle_offset_radians
		
		
	func write_transform(idx: int, pos: Vector2, rot: float, flip_h: bool, new_scale: Vector2 = Vector2.ONE) -> void:
		var layer_scale: Vector2 = layer_quad_scales[instance_layers[idx]]   # state cells bigger/smaller than the base quad
		var scale_x: float = new_scale.x * layer_scale.x
		if flip_h:
			scale_x = -scale_x
		var scale_y: float = new_scale.y * layer_scale.y
		var xf: Transform2D = Transform2D(rot, pos)
		xf.x *= scale_x
		xf.y *= scale_y
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
		var layer: int = instance_layers[idx]
		var frame_uv_size: Vector2 = layer_frame_uv_sizes[layer]
		var base: int = idx * FLOATS_PER_INSTANCE + OFFSET_CUSTOM
		buffer[base + 0] = frame_col * frame_uv_size.x   # u_offset
		buffer[base + 1] = frame_row * frame_uv_size.y   # v_offset (variant row)
		buffer[base + 2] = float(layer)                  # layer = state atlas
		buffer[base + 3] = -1.0 if instance_in_mass[idx] == 1 else 1.0   # sign = mass flag
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
	var layer_frame_uv_sizes: PackedVector2Array   # shared with the living pool

	var buffer: PackedFloat32Array
	var buffer_is_dirty: bool = false


	func setup(data: EnemyData, sprite_sheet_shader: Shader, shared_atlas_array: Texture2DArray, shared_frame_uv_sizes: PackedVector2Array) -> void:
		name = "Corpses_" + data.name
		max_corpses = maxi(1, data.max_corpses)
		z_index = data.corpse_z_index

		if shared_atlas_array == null:
			push_error("CorpsePool (" + data.name + ") : no atlas array")
			return

		layer_frame_uv_sizes = shared_frame_uv_sizes

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

		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = sprite_sheet_shader
		shader_material.set_shader_parameter("mass_filter", 0)
		shader_material.set_shader_parameter("atlas_array", shared_atlas_array)
		shader_material.set_shader_parameter("layer_frame_uv_sizes", layer_frame_uv_sizes)
		material = shader_material

		buffer = PackedFloat32Array()
		buffer.resize(max_corpses * FLOATS_PER_INSTANCE)
		buffer.fill(0.0)
		for i: int in range(max_corpses):
			var base: int = i * FLOATS_PER_INSTANCE
			buffer[base + 8]  = 1.0
			buffer[base + 9]  = 1.0
			buffer[base + 10] = 1.0
			buffer[base + 11] = 0.0   # no flash
			buffer[base + 15] = 1.0   # outside mass

		RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)

	## drop a corpse. if buffer is full, recycle the oldest one.
	func add_corpse(pos: Vector2, rot: float, corpse_scale: Vector2, frame_col: int, frame_row: int, layer: int) -> void:
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

		var frame_uv_size: Vector2 = layer_frame_uv_sizes[layer]
		buffer[base + OFFSET_CUSTOM + 0] = frame_col * frame_uv_size.x
		buffer[base + OFFSET_CUSTOM + 1] = frame_row * frame_uv_size.y
		buffer[base + OFFSET_CUSTOM + 2] = float(layer)
		buffer[base + OFFSET_CUSTOM + 3] = 1.0

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
