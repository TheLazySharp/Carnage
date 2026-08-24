class_name BuildingPool
extends Resource
## Pool of building assets, queried by the placement passes.
## One .tres per biome; the placement code stays identical across biomes.
## Entries whose biome differs from this pool's are ignored.
## Nothing is ever rotated: a query only returns assets already drawn with the
## footprint the placement needs.

@export var biome : GameMaster.BIOMES = GameMaster.BIOMES.CITY

@export var interiors : Array[BuildingData] = []
## Belt pieces. Horizontal ones (width x depth) feed the TOP / BOTTOM belts,
## vertical ones (depth x height) feed LEFT / RIGHT.
@export var peripherals : Array[BuildingData] = []
@export var corners : Array[BuildingData] = []
## Narrow solid pieces used to pave the belt exactly (fence, bins, alley...)
@export var fillers : Array[BuildingData] = []
## District buildings (bank, gunshop, car dealer...). Exactly one is placed
## when the current district type matches. district_type is what makes them
## mandatory; this array is just the shortlist.
@export var district_buildings : Array[BuildingData] = []

@export_group("Tuning")
## How much bigger buildings are favoured inside a block.
## 0 = pure weight, size ignored. 1 = probability proportional to the area.
## Negative values favour small buildings.
@export_range(-1.0, 2.0, 0.05) var size_preference : float = 0.5


## The mandatory building of the current district, or {} when this district
## needs none. Place it FIRST, before filling the blocks.
func pick_district_building(district_type : DistrictsData.types, rng : RandomNumberGenerator) -> Dictionary:
	if district_type == DistrictsData.types.N_A:
		return {}
	var candidates : Array[Dictionary] = []
	for data : BuildingData in district_buildings:
		if _is_usable(data) and data.district_type == district_type:
			candidates.append({"data": data, "bias": 1.0})
	return _weighted_pick(candidates, rng)


## Every generic building fitting max_size competes, biased by size_preference:
## big footprints stay likely without starving the small ones.
func pick_interior(max_size : Vector2i, rng : RandomNumberGenerator) -> Dictionary:
	var candidates : Array[Dictionary] = []
	for data : BuildingData in interiors:
		if not _is_usable(data) or data.is_district_specific():
			continue
		var size : Vector2i = data.footprint_32
		if size.x > max_size.x or size.y > max_size.y:
			continue
		candidates.append({
			"data": data,
			"bias": pow(float(size.x * size.y), size_preference),
		})
	return _weighted_pick(candidates, rng)


## Belt piece for a run of `max_length` cells along the side.
## horizontal = TOP / BOTTOM belt (footprint is length x depth),
## otherwise LEFT / RIGHT belt (footprint is depth x length).
func pick_peripheral(max_length : int, depth : int, horizontal : bool, rng : RandomNumberGenerator) -> Dictionary:
	return _pick_belt_piece(peripherals, max_length, depth, horizontal, rng)


func pick_filler(max_length : int, depth : int, horizontal : bool, rng : RandomNumberGenerator) -> Dictionary:
	return _pick_belt_piece(fillers, max_length, depth, horizontal, rng)


## Belt corner fitting max_size
func pick_corner(max_size : Vector2i, rng : RandomNumberGenerator) -> Dictionary:
	var candidates : Array[Dictionary] = []
	for data : BuildingData in corners:
		if not _is_usable(data):
			continue
		if data.footprint_32.x > max_size.x or data.footprint_32.y > max_size.y:
			continue
		candidates.append({"data": data, "bias": 1.0})
	return _weighted_pick(candidates, rng)


func _pick_belt_piece(pool : Array[BuildingData], max_length : int, depth : int, horizontal : bool, rng : RandomNumberGenerator) -> Dictionary:
	# Longest-first: the belt is paved with the widest piece that fits, so the
	# leftovers shrink as fast as possible.
	var candidates : Array[Dictionary] = []
	var best_length : int = 0
	for data : BuildingData in pool:
		if not _is_usable(data):
			continue
		var size : Vector2i = data.footprint_32
		var piece_length : int = size.x if horizontal else size.y
		var piece_depth : int = size.y if horizontal else size.x
		if piece_depth != depth or piece_length > max_length:
			continue
		if piece_length > best_length:
			best_length = piece_length
			candidates.clear()
		if piece_length == best_length:
			candidates.append({"data": data, "bias": 1.0})
	return _weighted_pick(candidates, rng)


func _is_usable(data : BuildingData) -> bool:
	return data != null and data.building_scene != null and data.biome == biome


func _weighted_pick(candidates : Array[Dictionary], rng : RandomNumberGenerator) -> Dictionary:
	if candidates.is_empty():
		return {}
	var total : float = 0.0
	for entry : Dictionary in candidates:
		total += _entry_weight(entry)
	if total <= 0.0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll : float = rng.randf() * total
	for entry : Dictionary in candidates:
		roll -= _entry_weight(entry)
		if roll <= 0.0:
			return entry
	return candidates[candidates.size() - 1]


func _entry_weight(entry : Dictionary) -> float:
	return maxf((entry["data"] as BuildingData).weight, 0.0) * float(entry.get("bias", 1.0))


## Shortest belt piece available: below that length, a gap cannot be closed
func min_belt_length(horizontal : bool) -> int:
	var result : int = 1 << 30
	for pool : Array[BuildingData] in [peripherals, fillers]:
		for data : BuildingData in pool:
			if _is_usable(data):
				result = mini(result, data.footprint_32.x if horizontal else data.footprint_32.y)
	return result if result < (1 << 30) else 0


## Editor helper: call it once after filling the arrays to catch typos early
func validate() -> PackedStringArray:
	var issues : PackedStringArray = PackedStringArray()
	if interiors.is_empty():
		issues.append("interiors is empty")
	if peripherals.is_empty():
		issues.append("peripherals is empty")
	if corners.is_empty():
		issues.append("corners is empty")
	if min_belt_length(true) > 1:
		issues.append("no 1-cell horizontal piece: some top/bottom belt gaps will stay open")
	if min_belt_length(false) > 1:
		issues.append("no 1-cell vertical piece: some left/right belt gaps will stay open")

	for pool_name : String in ["interiors", "peripherals", "corners", "fillers", "district_buildings"]:
		var pool : Array[BuildingData] = get(pool_name)
		for i : int in pool.size():
			var data : BuildingData = pool[i]
			if data == null:
				issues.append("%s[%d] is null" % [pool_name, i])
			elif data.building_scene == null:
				issues.append("%s[%d] (%s) has no scene" % [pool_name, i, data.name])
			elif data.footprint_32.x <= 0 or data.footprint_32.y <= 0:
				issues.append("%s[%d] (%s) has an invalid footprint" % [pool_name, i, data.name])
			elif data.biome != biome:
				issues.append("%s[%d] (%s) belongs to another biome: ignored" % [pool_name, i, data.name])
	return issues
