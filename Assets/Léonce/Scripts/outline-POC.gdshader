shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int outline_width : hint_range(1, 6) = 1;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));

    if (col.a < 0.5) {
        float found = 0.0;
        for (int y = -outline_width; y <= outline_width; y++) {
            for (int x = -outline_width; x <= outline_width; x++) {
                if (x == 0 && y == 0) continue;
                vec2 offset = vec2(float(x), float(y)) * texel;
                if (texture(TEXTURE, UV + offset).a > 0.5) {
                    found = 1.0;
                }
            }
        }
        COLOR = (found > 0.5) ? outline_color : vec4(0.0);
    } else {
        COLOR = col;
    }
}