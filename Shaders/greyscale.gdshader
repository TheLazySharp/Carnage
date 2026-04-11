shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    float lum = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
    COLOR = vec4(mix(col.rgb, vec3(lum), intensity), col.a);
}