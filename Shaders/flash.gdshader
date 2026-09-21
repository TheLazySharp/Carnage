shader_type canvas_item;

uniform bool active = false;
uniform vec4 blood_tint : source_color = vec4(0.466, 0.094, 0.0, 1.0);
uniform float blood_amount : hint_range(0.0, 1.0) = 0.0;
// Shading range of the visible blood color (kept <= 1.0, does not glow on its own)
uniform float shade_min : hint_range(0.0, 1.0) = 0.35;
uniform float shade_max : hint_range(0.5, 1.0) = 1.0;
// HDR emission added on top of the tint: only this part feeds the glow
uniform float glow_energy : hint_range(0.0, 30.0) = 6.0;

void fragment() {
	vec4 previous_color = texture(TEXTURE, UV);
	vec3 base_rgb = previous_color.rgb;
	if (active) {
		base_rgb = vec3(1.0);
	}
	// Perceptual brightness from the dominant channel: a dark blue body still reads as bright,
	// sqrt() converts linear (HDR 2D) values back to a perceptual scale
	float lum = sqrt(max(base_rgb.r, max(base_rgb.g, base_rgb.b)));
	// Visible blood color, keeps the sprite shading
	vec3 blood_rgb = blood_tint.rgb * mix(shade_min, shade_max, lum);
	vec3 tinted = mix(base_rgb, blood_rgb, blood_amount);
	// Emission weighted by luminance: bright body parts glow, dark parts stay readable
	vec3 emission = blood_tint.rgb * (glow_energy * lum * blood_amount);
	COLOR = vec4(tinted + emission, previous_color.a);
}