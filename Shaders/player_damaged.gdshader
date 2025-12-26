shader_type canvas_item;

uniform vec4 flash_color: source_color;
uniform float flash_value: hint_range(0.0, 1.0, 0.1);

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV); //je recupere la couleur de base des pixels
	COLOR = mix(texture_color, flash_color,flash_value); // on appliquera un mix de la couleur de base et leflash
	COLOR.a = texture_color.a;// on laisse transparent ce qui l'est déjà
}
