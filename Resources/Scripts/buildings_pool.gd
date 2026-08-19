class_name BuildingPool
extends Resource
## Pool of building assets, queried by the placement passes.
## One .tres per biome; the placement code stays identical across biomes.
## Entries whose biome differs from this pool's are ignored.

@export var biome : GameMaster.BIOMES = GameMaster.BIOMES.CITY

@export var interiors : Array[BuildingData] = []
@export var peripherals : Array[BuildingData] = []
## Belt corners: sidewalks on TWO adjacent faces. Authored for the TOP-LEFT
## corner (sidewalks facing down and right), rotated a quarter turn per corner.
@export var corners : Array[BuildingData] = []
## 1 to 3 cells wide solid pieces, used to pave the belt exactly when no
## building fits the remaining gap (fence, bins, low wall, alley...)
@export var fillers : Array[BuildingData] = []
## District buildings (bank, gunshop, car dealer...). Exactly one is placed
## when the current district type matches. They may also live in `interiors`:
## district_type is what makes them mandatory, this array is just the shortlist.
@export var district_buildings : Array[BuildingData] = []


## The mandatory building of the current district, or {} when this district
## needs none. Place it FIRST, before filling the blocks.
func pick_district_building(district_type : DistrictsData.types, rng : RandomNumberGenerator) -> Dictionary:
	if district_type == DistrictsData.types.N_A:
		return {}
	var candidates : Array[Dictionary] = []
	for data : BuildingData in district_buildings:
		if not _is_usable(data):
			continue
		if data.district_type == district_type:
			candidates.append({"data": data, "quarter_turns": 0})
	if candidates.is_empty():
		return {}
	return _weighted_pick(candidates, rng)


## Largest-first pick: returns the biggest generic building fitting max_size,
## weighted among the ex aequo. Returns {} when nothing fits.
func pick_interior(max_size : Vector2i, rng : RandomNumberGenerator, allow_turns : bool = true) -> Dictionary:
	var candidates : Array[Dictionary] = []
	var best_area : int = 0

	for data : BuildingData in interiors:
		if not _is_usable(data) or data.is_district_specific():
			continue
		var turns_pool : Array[int] = [0]
		if allow_turns and data.allow_quarter_turns and data.footprint_32.x != data.footprint_32.y:
			turns_pool.append(1)
		for turns : int in turns_pool:
			var size : Vector2i = BuildingData.rotated_size(data.footprint_32, turns)
			if size.x > max_size.x or size.y > max_size.y:
				continue
			var area : int = size.x * size.y
			if area > best_area:
				best_area = area
				candidates.clear()
			if area == best_area:
				candidates.append({"data": data, "quarter_turns": turns})

	if candidates.is_empty():
		return {}
	return _weighted_pick(candidates, rng)


## Belt pick: widest building fitting max_width, whose depth fits max_depth
func pick_peripheral(max_width : int, max_depth : int, rng : RandomNumberGenerator) -> Dictionary:
	return _pick_by_width(peripherals, max_width, max_depth, rng)


## Gap filler: same rule, on the small pieces
func pick_filler(max_width : int, max_depth : int, rng : RandomNumberGenerator) -> Dictionary:
	return _pick_by_width(fillers, max_width, max_depth, rng)


## Belt corner pick. The placement pass applies the rotation matching the corner.
func pick_corner(max_size : Vector2i, rng : RandomNumberGenerator) -> Dictionary:
	var candidates : Array[Dictionary] = []
	for data : BuildingData in corners:
		if not _is_usable(data):
			continue
		if data.footprint_32.x > max_size.x or data.footprint_32.y > max_size.y:
			continue
		candidates.append({"data": data, "quarter_turns": 0})
	if candidates.is_empty():
		return {}
	return _weighted_pick(candidates, rng)


func _pick_by_width(pool : Array[BuildingData], max_width : int, max_depth : int, rng : RandomNumberGenerator) -> Dictionary:
	var candidates : Array[Dictionary] = []
	var best_width : int = 0
	for data : BuildingData in pool:
		if not _is_usable(data):
			continue
		if data.footprint_32.x > max_width or data.footprint_32.y > max_depth:
			continue
		if data.footprint_32.x > best_width:
			best_width = data.footprint_32.x
			candidates.clear()
		if data.footprint_32.x == best_width:
			candidates.append({"data": data, "quarter_turns": 0})
	if candidates.is_empty():
		return {}
	return _weighted_pick(candidates, rng)


func _is_usable(data : BuildingData) -> bool:
	return data != null and data.building_scene != null and data.biome == biome


func _weighted_pick(candidates : Array[Dictionary], rng : RandomNumberGenerator) -> Dictionary:
	var total : float = 0.0
	for entry : Dictionary in candidates:
		total += maxf((entry["data"] as BuildingData).weight, 0.0)
	if total <= 0.0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll : float = rng.randf() * total
	for entry : Dictionary in candidates:
		roll -= maxf((entry["data"] as BuildingData).weight, 0.0)
		if roll <= 0.0:
			return entry
	return candidates[candidates.size() - 1]


## Smallest widths available in the belt pools: lets the paving algorithm know
## the granularity it can reach before falling back on fillers.
func min_peripheral_width() -> int:
	return _min_width(peripherals)


func min_filler_width() -> int:
	return _min_width(fillers)


func _min_width(pool : Array[BuildingData]) -> int:
	var result : int = 1 << 30
	for data : BuildingData in pool:
		if _is_usable(data):
			result = mini(result, data.footprint_32.x)
	return result if result < (1 << 30) else 0


## Editor helper: call it once after filling the arrays to catch typos early
func validate() -> PackedStringArray:
	var issues : PackedStringArray = PackedStringArray()
	if interiors.is_empty():
		issues.append("interiors is empty")
	if peripherals.is_empty():
		issues.append("peripherals is empty")
	if corners.is_empty():
		issues.append("corners is empty: belt corners will fall back on peripherals")
	if min_filler_width() != 1:
		issues.append("no 1-cell filler: the belt cannot be paved exactly on every length")

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

	for data : BuildingData in district_buildings:
		if data != null and not data.is_district_specific():
			issues.append("district_buildings contains '%s' with district_type N_A" % data.name)
	return issues
