shader_type canvas_item;
render_mode blend_add;

// Vitesse à laquelle la teinte tourne dans le temps (cycles/s).
uniform float hue_speed : hint_range(0.0, 3.0) = 0.15;
// Amplitude de variation de teinte le long du ruban (0 = couleur uniforme,
// 1+ = plusieurs teintes visibles simultanément sur la longueur).
uniform float uv_hue_spread : hint_range(0.0, 2.0) = 0.6;
uniform float saturation : hint_range(0.0, 1.0) = 0.55;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

vec3 hue_to_rgb(float h) {
	vec3 rgb = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return rgb;
}

void fragment() {
	// UV.x : 0 = point le plus ancien (queue), 1 = point le plus récent (tête, près de l'orbe).
	float t = clamp(UV.x, 0.0, 1.0);

	float hue = fract(t * uv_hue_spread + TIME * hue_speed);
	vec3 col = mix(vec3(1.0), hue_to_rgb(hue), saturation) * brightness;

	// UV.y : 0.5 = centre du ruban, 0 et 1 = bords -> on adoucit pour un effet halo.
	float w = abs(UV.y - 0.5) * 2.0;
	float edge = smoothstep(1.0, 0.0, w);

	float alpha = t * edge;
	COLOR = vec4(col, alpha);
}
