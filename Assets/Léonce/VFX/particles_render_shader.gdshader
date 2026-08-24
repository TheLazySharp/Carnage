shader_type canvas_item;

uniform float h_frames : hint_range(1.0, 32.0) = 4.0;
uniform float v_frames : hint_range(1.0, 32.0) = 5.0;

varying flat vec4 v_instance_custom;
varying vec4 v_particle_tint;

void vertex() {
    v_instance_custom = INSTANCE_CUSTOM;
    v_particle_tint = COLOR; // capturé ICI, avant la multiplication auto par la texture par défaut
}

void fragment() {
    float row = floor(v_instance_custom.z);
    float progress = fract(v_instance_custom.z);

    float frame = min(floor(progress * h_frames), h_frames - 1.0);

    vec2 cell_size = vec2(1.0 / h_frames, 1.0 / v_frames);
    vec2 uv = UV * cell_size + vec2(frame * cell_size.x, row * cell_size.y);

    COLOR = texture(TEXTURE, uv) * v_particle_tint;
}
