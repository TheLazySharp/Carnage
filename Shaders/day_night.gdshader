shader_type canvas_item;

render_mode unshaded;
uniform sampler2D gradient: source_color;
uniform float gradient_mix_amiunt = 1.0;


void fragment() {
	vec3 gradientColor = texture(gradient, UV).rgb;
	COLOR.rgb = gradientColor;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
