shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float max_radius_px = 300.0;
uniform float ring_width_px = 60.0;
uniform float distortion_strength = 0.02;
uniform vec2 center_screen_uv = vec2(0.5, 0.5);

// À partir de quel % du progress le fade commence (0.7 = commence à 70% du parcours)
uniform float fade_start : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixel_pos = SCREEN_UV * screen_size;
	vec2 center_pixel = center_screen_uv * screen_size;

	vec2 diff_px = pixel_pos - center_pixel;
	float dist_px = length(diff_px);

	float current_radius_px = progress * max_radius_px;
	float dist_to_ring = abs(dist_px - current_radius_px);
	float ring_mask = 1.0 - smoothstep(0.0, ring_width_px, dist_to_ring);

	// Facteur de fade : reste à 1.0 jusqu'à fade_start, puis descend à 0.0 quand progress atteint 1.0
	float fade = 1.0 - smoothstep(fade_start, 1.0, progress);
	ring_mask *= fade;

	vec2 dir = normalize(diff_px);
	vec2 offset = dir * ring_mask * distortion_strength;

	vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV + offset);
	COLOR = color;
}