shader_type canvas_item;

uniform sampler2D target_mask : filter_nearest, repeat_disable;      // flood_result, recalculé chaque frame
uniform sampler2D previous_frame : filter_nearest, repeat_disable;   // SmoothViewport lui-même, frame précédente
uniform float blend_speed = 6.0;   // plus haut = transition plus rapide
uniform float delta_time = 0.016;  // mis à jour depuis le script chaque frame

void fragment() {
    float target = texture(target_mask, UV).r;
    float prev = texture(previous_frame, UV).r;
    float t = clamp(blend_speed * delta_time, 0.0, 1.0);
    float smoothed = mix(prev, target, t);
    COLOR = vec4(smoothed, 0.0, 0.0, 1.0);
}