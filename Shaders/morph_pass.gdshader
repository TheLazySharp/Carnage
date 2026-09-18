shader_type canvas_item;

// Exact Euclidean disc closing in 4 separable passes:
//   0: horizontal distance to the nearest enemy pixel (source render, alpha >= 0.5)
//   1: vertical disc test -> dilated mask (1 = within radius of an enemy pixel)
//   2: horizontal distance to the nearest EMPTY pixel of the dilated mask
//   3: vertical disc test, inverted -> closed mask (1 = no empty pixel within radius)
uniform int pass_type : hint_range(0, 3) = 0;
uniform int radius : hint_range(1, 32) = 8;

float is_seed(sampler2D input_texture, vec2 uv, int type) {
	vec4 c = texture(input_texture, uv);
	if (type == 0) {
		return step(0.5, c.a);          // enemy pixel
	}
	return 1.0 - step(0.5, c.r);        // empty pixel of the mask
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	float max_distance = float(radius + 1);   // radius + 1 = no seed on this row

	if (pass_type == 0 || pass_type == 2) {
		// Horizontal 1D distance to the nearest seed, capped at radius + 1
		float distance_x = max_distance;
		for (int i = 0; i <= radius; i++) {
			vec2 offset = vec2(float(i) * texel.x, 0.0);
			if (is_seed(TEXTURE, UV + offset, pass_type) > 0.5 || is_seed(TEXTURE, UV - offset, pass_type) > 0.5) {
				distance_x = float(i);
				break;
			}
		}
		COLOR = vec4(distance_x / max_distance, 0.0, 0.0, 1.0);
	} else {
		// Vertical pass: a seed lies inside the disc if distance_x^2 + dy^2 <= radius^2 on some row
		float radius_squared = float(radius * radius);
		float hit = 0.0;
		for (int dy = -radius; dy <= radius; dy++) {
			vec2 offset = vec2(0.0, float(dy) * texel.y);
			float distance_x = round(texture(TEXTURE, UV + offset).r * max_distance);
			if (distance_x * distance_x + float(dy * dy) <= radius_squared) {
				hit = 1.0;
				break;
			}
		}
		// pass 1: dilated = hit ; pass 3: closed = no empty pixel within the disc
		COLOR = vec4(pass_type == 1 ? hit : 1.0 - hit, 0.0, 0.0, 1.0);
	}
}