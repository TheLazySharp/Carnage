extends Node







#---------- PUBLIC API -----------

func get_text_from_key(p_key_text : String) -> String :
	return tr(p_key_text)

func get_translated_text(p_key_text : String, p_language : String) -> String :
	return TranslationServer.get_translation_object(p_language).get_message(p_key_text)
