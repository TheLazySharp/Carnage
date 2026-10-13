shader_type canvas_item;

// Builds the mass footprint from the source render: opaque pixels, plus transparent pixels enclosed by opaque
// pixels. A transparent pixel is filled when at most hole_max_escapes of the 16 rays travel hole_max_size texels
// without hitting an opaque pixel. Allowing one escape fills pockets that keep a narrow channel to the outside
// (they flicker as sprites move); concavities of the outer contour have several open directions and stay intact.
uniform int hole_max_size : hint_range(0, 32) = 16;
uniform int hole_max_escapes : hint_range(0, 4) = 1;

// 16 directions, ordered so that consecutive rays point to opposite sides: open areas exit early
const vec2 RAY_DIRECTIONS[16] = vec2[16](
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.70711, 0.70711), vec2(-0.70711, -0.70711), vec2(-0.70711, 0.70711), vec2(0.70711, -0.70711),
	vec2(0.92388, 0.38268), vec2(-0.92388, -0.38268), vec2(0.38268, 0.92388), vec2(-0.38268, -0.92388),
	vec2(-0.38268, 0.92388), vec2(0.38268, -0.92388), vec2(-0.92388, 0.38268), vec2(0.92388, -0.38268)
);

bool ray_hits_opaque(sampler2D source, vec2 uv, vec2 step_uv, int max_steps) {
	for (int i = 1; i <= max_steps; i++) {
		if (texture(source, uv + step_uv * float(i)).a >= 0.5) {
			return true;
		}
	}
	return false;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float inside = 0.0;
	if (original.a >= 0.5) {
		inside = 1.0;
	} else if (hole_max_size > 0) {
		vec2 texel = TEXTURE_PIXEL_SIZE;
		int escapes = 0;
		for (int ray = 0; ray < 16; ray++) {
			if (!ray_hits_opaque(TEXTURE, UV, RAY_DIRECTIONS[ray] * texel, hole_max_size)) {
				escapes++;
				if (escapes > hole_max_escapes) {
					break;   // open area: outside the mass
				}
			}
		}
		inside = escapes <= hole_max_escapes ? 1.0 : 0.0;
	}
	COLOR = vec4(inside, 0.0, 0.0, 1.0);
}