shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int outline_width : hint_range(1, 4) = 1;

// géométrie du type affiché par CE MultiMeshInstance2D
uniform int my_total_rows = 1;
uniform int my_max_cols = 4;

// données globales, partagées entre tous les MultiMeshInstance2D de la horde
uniform sampler2D entity_data : filter_nearest, repeat_disable;
uniform sampler2D neighbor_data : filter_nearest, repeat_disable;

// atlas + géométrie de CHAQUE type existant (ajouter une paire si un 3e type arrive)
uniform sampler2D atlas_0 : filter_nearest, repeat_disable;
uniform sampler2D atlas_1 : filter_nearest, repeat_disable;
uniform float cell_size_0 = 19.0;
uniform float cell_size_1 = 24.0;
uniform int rows_0 = 1;
uniform int cols_0 = 4;
uniform int rows_1 = 1;
uniform int cols_1 = 1;

varying vec2 world_pos;
varying flat vec4 my_data;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    my_data = INSTANCE_CUSTOM;
}

bool sample_neighbor_alpha(int other_type, vec2 local01, int row, int col) {
    vec4 c;
    if (other_type == 0) {
        vec2 cs = vec2(1.0 / float(cols_0), 1.0 / float(rows_0));
        vec2 uv = local01 * cs + vec2(float(col) * cs.x, float(row) * cs.y);
        c = texture(atlas_0, uv);
    } else {
        vec2 cs = vec2(1.0 / float(cols_1), 1.0 / float(rows_1));
        vec2 uv = local01 * cs + vec2(float(col) * cs.x, float(row) * cs.y);
        c = texture(atlas_1, uv);
    }
    return c.a > 0.5;
}

void fragment() {
    int my_row   = int(my_data.r + 0.5);
    int my_col   = int(my_data.g + 0.5);
    int my_index = int(my_data.b + 0.5);
    bool my_flip = my_data.a > 0.5;

    vec2 local_uv = UV;
    if (my_flip) {
        local_uv.x = 1.0 - local_uv.x;
    }

    vec2 my_cs = vec2(1.0 / float(my_max_cols), 1.0 / float(my_total_rows));
    vec2 atlas_uv = local_uv * my_cs + vec2(float(my_col) * my_cs.x, float(my_row) * my_cs.y);

    vec4 col = texture(TEXTURE, atlas_uv);

    if (col.a >= 0.5) {
        // pixel opaque : on affiche le sprite normalement
        COLOR = col;
    } else {
        // pixel transparent : est-ce un bord de MA propre silhouette ?
        vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));
        float found = 0.0;
        for (int y = -outline_width; y <= outline_width; y++) {
            for (int x = -outline_width; x <= outline_width; x++) {
                if (x == 0 && y == 0) continue;
                if (texture(TEXTURE, atlas_uv + vec2(float(x), float(y)) * texel).a > 0.5) {
                    found = 1.0;
                }
            }
        }

        if (found < 0.5) {
            // pas un bord : rien à dessiner
            COLOR = vec4(0.0);
        } else {
            // bord confirmé : un VRAI pixel de voisin recouvre-t-il cet endroit du monde ?
            vec4 nbr_a = texelFetch(neighbor_data, ivec2(my_index, 0), 0);
            vec4 nbr_b = texelFetch(neighbor_data, ivec2(my_index, 1), 0);
            float neighbor_ids[8] = float[8](nbr_a.r, nbr_a.g, nbr_a.b, nbr_a.a, nbr_b.r, nbr_b.g, nbr_b.b, nbr_b.a);

            bool covered = false;
            for (int n = 0; n < 8; n++) {
                float nid_f = neighbor_ids[n];
                if (nid_f < -0.5) continue; // slot vide

                int nid = int(nid_f + 0.5);
                vec4 pos_data  = texelFetch(entity_data, ivec2(nid, 0), 0);
                vec4 anim_data = texelFetch(entity_data, ivec2(nid, 1), 0);

                vec2 other_pos = pos_data.rg;
                int other_type = int(pos_data.b + 0.5);
                int o_row = int(anim_data.r + 0.5);
                int o_col = int(anim_data.g + 0.5);

                float o_cell = (other_type == 0) ? cell_size_0 : cell_size_1;
                vec2 o_local = (world_pos - other_pos) / o_cell + 0.5;

                if (o_local.x >= 0.0 && o_local.x <= 1.0 && o_local.y >= 0.0 && o_local.y <= 1.0) {
                    if (sample_neighbor_alpha(other_type, o_local, o_row, o_col)) {
                        covered = true;
                    }
                }
            }

            COLOR = covered ? vec4(0.0) : outline_color;
        }
    }
}