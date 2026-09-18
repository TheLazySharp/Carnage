shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int outline_width : hint_range(1, 4) = 1;
uniform sampler2D flood_result : filter_nearest, repeat_disable;   // maintenant = sortie de SmoothViewport
uniform sampler2D original_texture : filter_nearest, repeat_disable;

void fragment() {
    vec4 orig = texture(original_texture, UV);

    if (orig.a >= 0.5) {
        COLOR = orig;
    } else {
        float outside = texture(flood_result, UV).r;   // valeur lissée, entre 0 et 1

        vec2 texel = 1.0 / vec2(textureSize(original_texture, 0));
        float found = 0.0;
        for (int y = -outline_width; y <= outline_width; y++) {
            for (int x = -outline_width; x <= outline_width; x++) {
                if (x == 0 && y == 0) continue;
                if (texture(original_texture, UV + vec2(float(x), float(y)) * texel).a > 0.5) {
                    found = 1.0;
                }
            }
        }

        if (found > 0.5) {
            // bord : fondu doux entre remplissage (trou qui se referme) et outline (extérieur)
            COLOR = mix(fill_color, outline_color, outside);
        } else {
            // pas un bord : fondu doux entre remplissage et transparence
            COLOR = mix(fill_color, vec4(0.0), outside);
        }
    }
}