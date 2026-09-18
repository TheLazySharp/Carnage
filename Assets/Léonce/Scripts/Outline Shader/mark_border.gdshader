shader_type canvas_item;

uniform sampler2D source : filter_nearest, repeat_disable;

void fragment() {
    vec4 src = texture(source, UV);
    vec2 texel = 1.0 / vec2(textureSize(source, 0));
    bool on_border = UV.x < texel.x || UV.x > 1.0 - texel.x || UV.y < texel.y || UV.y > 1.0 - texel.y;
    float outside = (src.a < 0.5 && on_border) ? 1.0 : 0.0;
    COLOR = vec4(outside, 0.0, 0.0, 1.0);
}