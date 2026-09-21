shader_type canvas_item;

// Builds the mass footprint from the source render: opaque pixels, plus transparent pixels enclosed
// by opaque pixels (an opaque pixel found within hole_max_size texels in all 8 directions).
// Concavities of the outer contour always have an open direction, so sprite shapes are untouched.
uniform int hole_max_size : hint_range(0, 32) = 12;

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
		vec2 t = TEXTURE_PIXEL_SIZE;
		// && stops at the first open direction: pixels outside the mass exit early
		bool enclosed = ray_hits_opaque(TEXTURE, UV, vec2(t.x, 0.0), hole_max_size)
			&& ray_hits_opaque(TEXTURE, UV, vec2(-t.x, 0.0), hole_max_size)
			&& ray_hits_opaque(TEXTURE, UV, vec2(0.0, t.y), hole_max_size)
			&& ray_hits_opaque(TEXTURE, UV, vec2(0.0, -t.y), hole_max_size)
			&& ray_hits_opaque(TEXTURE, UV, vec2(t.x, t.y), hole_max_size)
			&& ray_hits_opaque(TEXTURE, UV, vec2(-t.x, -t.y), hole_max_size)
			&& ray_hits_opaque(TEXTURE, UV, vec2(t.x, -t.y), hole_max_size)
			&& ray_hits_opaque(TEXTURE, UV, vec2(-t.x, t.y), hole_max_size);
		inside = enclosed ? 1.0 : 0.0;
	}
	COLOR = vec4(inside, 0.0, 0.0, 1.0);
}