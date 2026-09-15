shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float edge_sharpness : hint_range(0.0, 0.5) = 0.05;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;

void fragment() {
    vec3 behind = texture(screen_texture, SCREEN_UV).rgb;
    float raw_alpha = texture(TEXTURE, UV).a;

    float text_alpha = smoothstep(0.5 - edge_sharpness, 0.5 + edge_sharpness, raw_alpha);

    vec3 inverted = vec3(1.0) - behind;
    inverted = clamp((inverted - 0.5) * contrast + 0.5, 0.0, 1.0);

    COLOR.rgb = inverted;
    COLOR.a = text_alpha * opacity;
}