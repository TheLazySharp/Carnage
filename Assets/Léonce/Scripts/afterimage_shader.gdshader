shader_type canvas_item;

// Couleur vers laquelle le sprite est recolorisé (ex: blanc, cyan, orange).
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 0 = couleurs d'origine du sprite, 1 = couleur "tint_color" pleine.
uniform float tint_strength : hint_range(0.0, 1.0) = 0.55;
// Opacité maximale de l'effet (réglée une fois à la création du fantôme).
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
// Piloté image par image par le script : 1 = pleinement visible, 0 = disparu.
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 tinted_rgb = mix(tex_color.rgb, tint_color.rgb, tint_strength);
	COLOR = vec4(tinted_rgb, tex_color.a * fade * alpha);
}
