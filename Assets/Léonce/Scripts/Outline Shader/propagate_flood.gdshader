shader_type canvas_item;

uniform sampler2D previous_pass : filter_nearest, repeat_disable;
uniform sampler2D original_texture : filter_nearest, repeat_disable;
uniform int step_radius : hint_range(1, 4) = 1;

void fragment() {
    vec4 src = texture(original_texture, UV);

    if (src.a >= 0.5) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        float outside = texture(previous_pass, UV).r;
        vec2 texel = 1.0 / vec2(textureSize(previous_pass, 0));
        for (int y = -step_radius; y <= step_radius; y++) {
            for (int x = -step_radius; x <= step_radius; x++) {
                if (x == 0 && y == 0) continue;
                outside = max(outside, texture(previous_pass, UV + vec2(float(x), float(y)) * texel).r);
            }
        }
        COLOR = vec4(outside, 0.0, 0.0, 1.0);
    }
}