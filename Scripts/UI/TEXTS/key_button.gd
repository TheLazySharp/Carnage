@tool
class_name KeyButton
extends Button
# Button whose text is a translation key picked from the TextKeys registry, styled by FontManager

@export var text_key: StringName = &"":
	set(value):
		text_key = value
		# Auto-translate displays the text for this key
		text = text_key
		update_configuration_warnings()

# Base type: BUTTON and MENU also get their FOCUS / PRESSED / HOVER variants
@export var font_type: FontManager.types = FontManager.types.BUTTON


func _validate_property(property: Dictionary) -> void:
	if property.name == "text_key":
		# Dropdown of known keys, still editable as free text
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = TextKeys.KEY_LIST

# Yellow warning icon in the scene tree if the key no longer exists
func _get_configuration_warnings() -> PackedStringArray:
	if text_key.is_empty() or TextKeys.KEY_LIST.split(",").has(String(text_key)):
		return PackedStringArray()
	return PackedStringArray(["Unknown text key: " + text_key])

func _ready() -> void:
	# FontManager is an autoload: it only exists at runtime, not in the editor
	if Engine.is_editor_hint():
		return
	apply_font_type(font_type)

func apply_font_type(new_type: FontManager.types) -> void:
	font_type = new_type
	var font_settings: Array = FontManager.FONTS.get(new_type, [])
	# DEFAUT has no entry: keep the theme's default style
	if font_settings.is_empty():
		return
	add_theme_font_override("font", font_settings[0])
	add_theme_font_size_override("font_size", font_settings[1])
	add_theme_color_override("font_color", font_settings[2])
	add_theme_constant_override("h_separation", FontManager.button_H_sep)
	if new_type == FontManager.types.BUTTON:
		_apply_state_colors(FontManager.types.BUTTON_FOCUS, FontManager.types.BUTTON_PRESSED, FontManager.types.BUTTON_HOVER)
	elif new_type == FontManager.types.MENU:
		_apply_state_colors(FontManager.types.MENU_FOCUS, FontManager.types.MENU_PRESSED, FontManager.types.MENU_HOVER)
	else:
		# Single-style types: same color in every state, so the theme's state colors never show
		_apply_state_colors(new_type, new_type, new_type)

func _apply_state_colors(focus_type: FontManager.types, pressed_type: FontManager.types, hover_type: FontManager.types) -> void:
	add_theme_color_override("font_focus_color", FontManager.FONTS[focus_type][2])
	add_theme_color_override("font_pressed_color", FontManager.FONTS[pressed_type][2])
	add_theme_color_override("font_hover_color", FontManager.FONTS[hover_type][2])
	add_theme_color_override("font_hover_pressed_color", FontManager.FONTS[pressed_type][2])
