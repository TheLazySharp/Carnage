shader_type canvas_item;
render_mode blend_add;

// Pool de couleurs (rempli depuis TrailRibbon.gd). Taille fixe côté shader ;
// pool_size indique combien d'entrées sont réellement utilisées.
uniform vec4 color_pool[8] : source_color;
uniform int pool_size : hint_range(1, 8) = 4;

// Nombre de bandes de couleur discrètes le long de la traînée.
uniform int band_count : hint_range(1, 32) = 8;
// Vitesse à laquelle chaque bande change de couleur (façon scintillement).
uniform float flicker_speed : hint_range(0.0, 10.0) = 2.0;

// Netteté du bord du ruban (axe UV.y). Proche de 0 = bord dur/pixelisé.
uniform float edge_softness : hint_range(0.0, 0.5) = 0.02;
// Découpe le fondu d'opacité le long de la longueur en paliers nets.
uniform int fade_steps : hint_range(0, 16) = 6;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	float t = clamp(UV.x, 0.0, 1.0); // 0 = queue, 1 = tête (près de l'orbe)

	// Découpe la longueur en bandes discrètes et donne à chacune un
	// déphasage propre (hash de son index) pour qu'elles ne changent pas
	// toutes de couleur en même temps.
	float band_f = floor(t * float(band_count));
	float band_phase = hash(band_f * 13.17);
	float time_bucket = floor(TIME * flicker_speed + band_phase * 10.0);
	float pick = hash(band_f * 7.31 + time_bucket * 3.91);
	int idx = int(pick * float(pool_size)) % pool_size;

	vec3 col = color_pool[idx].rgb;

	// Fondu d'opacité le long de la longueur, en paliers pour rester "par blocs".
	if (fade_steps > 1) {
		t = floor(t * float(fade_steps)) / float(fade_steps - 1);
	}

	float w = abs(UV.y - 0.5) * 2.0; // 0 au centre, 1 sur les bords
	float edge = 1.0 - smoothstep(1.0 - edge_softness, 1.0, w);

	float alpha = t * edge;
	COLOR = vec4(col, alpha);
}
