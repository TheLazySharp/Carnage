shader_type canvas_item;

varying vec4 instance_custom;

void vertex() {
    instance_custom = INSTANCE_CUSTOM;
    UV = vec2(
        instance_custom.x + UV.x * instance_custom.z,
        instance_custom.y + UV.y * instance_custom.w
    );
}

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    if (col.a < 0.01) discard;
    COLOR = vec4(1.0, 0.0, 0.0, col.a);  // rouge absolu, aucune condition
}