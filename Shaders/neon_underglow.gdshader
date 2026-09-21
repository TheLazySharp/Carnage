shader_type canvas_item;
render_mode blend_add, unshaded;

// Higher = light more concentrated on the strip center line
uniform float falloff : hint_range(0.5, 4.0) = 1.8;

void fragment() {
	// Rect aspect ratio (width / height), independent of rotation and zoom
	float aspect = fwidth(UV.y) / fwidth(UV.x);
	// Position from the rect center, in units where the short side = 1
	vec2 extent = aspect >= 1.0 ? vec2(aspect, 1.0) : vec2(1.0, 1.0 / aspect);
	vec2 p = (UV - 0.5) * extent;
	// Capsule: segment along the long axis, radius = half the short side
	float half_len = (max(extent.x, extent.y) - 1.0) * 0.5;
	vec2 q = aspect >= 1.0
		? vec2(max(abs(p.x) - half_len, 0.0), p.y)
		: vec2(p.x, max(abs(p.y) - half_len, 0.0));
	// 0 on the center line, 1 on the capsule edge
	float d = length(q) * 2.0;
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), falloff);
	// COLOR includes the parent modulate animated by the tween
	COLOR = vec4(COLOR.rgb, COLOR.a * glow);
}