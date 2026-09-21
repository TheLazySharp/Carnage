shader_type canvas_item;

// TEXTURE = SourceViewport (enemies inside a mass, as rendered) -> used for colors (eyes, flash).
// filled_mask = output of mass_holes.gdshader: 1 where the mass is (opaque pixels + enclosed holes).
// Inside the mass -> fill_color, except eyes and the white damage flash.
// Outline: mass pixels with a non-mass pixel within outline_width (inside), or non-mass pixels
// with a mass pixel within outline_width (outline_outside = true).
uniform sampler2D filled_mask : filter_nearest, repeat_disable;
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int outline_width : hint_range(0, 4) = 1;
uniform bool outline_outside = false;
uniform vec4 eye_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float eye_tolerance : hint_range(0.0, 1.0) = 0.3;
uniform float flash_min_brightness : hint_range(0.0, 1.0) = 0.95;
uniform bool show_mask = false;

// true if a mask pixel with the requested state exists within width (disc)
bool has_neighbor(sampler2D mask, vec2 uv, vec2 texel, int width, bool look_for_inside) {
	int width_squared = width * width;
	for (int y = -width; y <= width; y++) {
		for (int x = -width; x <= width; x++) {
			if (x == 0 && y == 0) continue;
			if (x * x + y * y > width_squared) continue;
			bool neighbor_inside = texture(mask, uv + vec2(float(x), float(y)) * texel).r >= 0.5;
			if (neighbor_inside == look_for_inside) return true;
		}
	}
	return false;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	bool inside = texture(filled_mask, UV).r >= 0.5;
	vec2 texel = TEXTURE_PIXEL_SIZE;

	if (show_mask) {
		// yellow = sprite pixels, red = filled holes
		COLOR = vec4(inside ? 1.0 : 0.0, original.a >= 0.5 ? 1.0 : 0.0, 0.0, 1.0);
	} else if (!inside) {
		bool ring = outline_outside && outline_width > 0 && has_neighbor(filled_mask, UV, texel, outline_width, true);
		COLOR = ring ? outline_color : vec4(0.0);
	} else {
		bool opaque = original.a >= 0.5;
		bool is_eye = opaque && distance(original.rgb, eye_color.rgb) < eye_tolerance;
		bool is_flash = opaque && max(original.r, max(original.g, original.b)) >= flash_min_brightness;
		if (is_eye || is_flash) {
			COLOR = original;
		} else {
			bool ring = !outline_outside && outline_width > 0 && has_neighbor(filled_mask, UV, texel, outline_width, false);
			COLOR = ring ? outline_color : fill_color;
		}
	}
}