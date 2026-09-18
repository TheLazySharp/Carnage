shader_type canvas_item;

// TEXTURE = SourceViewport (enemies as rendered). closed_mask = output of the last disc pass.
// Inside the closed mask everything is painted fill_color except the eyes (and the white damage flash).
// One outline_color ring is drawn around the periphery of the mass.
uniform sampler2D closed_mask : filter_nearest, repeat_disable;
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int outline_width : hint_range(0, 4) = 1;
uniform vec4 eye_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float eye_tolerance : hint_range(0.0, 1.0) = 0.3;
uniform float flash_min_brightness : hint_range(0.0, 1.0) = 0.95;
uniform bool show_mask = false;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float inside = texture(closed_mask, UV).r;

	if (show_mask) {
		COLOR = vec4(inside, step(0.5, original.a), 0.0, 1.0);
	} else if (inside > 0.5) {
		bool opaque = original.a >= 0.5;
		bool is_eye = opaque && distance(original.rgb, eye_color.rgb) < eye_tolerance;
		bool is_flash = opaque && max(original.r, max(original.g, original.b)) >= flash_min_brightness;
		COLOR = (is_eye || is_flash) ? original : fill_color;
	} else {
		// Periphery: any closed-mask pixel within outline_width (disc)
		float near_mask = 0.0;
		vec2 texel = TEXTURE_PIXEL_SIZE;
		int width_squared = outline_width * outline_width;
		for (int y = -outline_width; y <= outline_width; y++) {
			for (int x = -outline_width; x <= outline_width; x++) {
				if (x * x + y * y > width_squared) continue;
				near_mask = max(near_mask, texture(closed_mask, UV + vec2(float(x), float(y)) * texel).r);
			}
		}
		COLOR = near_mask > 0.5 ? outline_color : vec4(0.0);
	}
}