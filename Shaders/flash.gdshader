shader_type canvas_item;

uniform bool active = false;
uniform vec4 blood_tint : source_color = vec4(0.55, 0.12, 0.12, 1.0);
uniform float blood_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 previous_color = texture(TEXTURE, UV);
	vec4 white_color = vec4(1.0, 1.0, 1.0, previous_color.a);
	vec4 new_color = previous_color;
	if (active == true)
	{
		new_color = white_color;
	}
	COLOR = new_color;
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * blood_tint.rgb, blood_amount);
}