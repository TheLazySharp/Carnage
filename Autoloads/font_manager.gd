extends Node

enum types {
	DEFAUT,TITLE,TITLE_LOW,
	MENU,MENU_FOCUS,MENU_PRESSED,MENU_HOVER,
	BUTTON,BUTTON_FOCUS,BUTTON_PRESSED,BUTTON_HOVER,
	TEXT,TEXT_TITLE,TEXT_TITLE_LOW,
	UX,UX_M,UX_S,UX_XS,
	VFX, VFX_SMALL,
	SOLD_OUT
}

const BUTTON_ICON = preload("uid://bqlx6iu4ihme6")
#const OXANIUM = preload("uid://cmmoqli2ds5yo")
const OXANIUM = preload("uid://clqmp3rgaclrm")

var button_H_sep : int = 8

var purple : Color = Color(0.686, 0.067, 0.435)
var dark_yellow : Color = Color(1.0, 0.776, 0.0)
var UX_outline : int = 8
var UX_color : Color = Color.BLACK

var background_color : Color = 080503

var FONTS : Dictionary = {
	types.TITLE:[OXANIUM,72,dark_yellow],
	types.TITLE_LOW:[OXANIUM,64,dark_yellow],
	
	types.MENU:[OXANIUM,48,dark_yellow],
	types.MENU_FOCUS:[OXANIUM,48,Color.WHITE],
	types.MENU_PRESSED:[OXANIUM,48,dark_yellow],
	types.MENU_HOVER:[OXANIUM,48,dark_yellow],
	
	types.BUTTON:[OXANIUM,24,Color.BLACK],
	types.BUTTON_FOCUS:[OXANIUM,24,Color.BLACK],
	types.BUTTON_PRESSED:[OXANIUM,24,Color.BLACK],
	types.BUTTON_HOVER:[OXANIUM,24,Color.BLACK],
	
	types.TEXT_TITLE:[OXANIUM,40,Color.WHITE],
	types.TEXT_TITLE_LOW:[OXANIUM,32,Color.WHITE],
	types.TEXT:[OXANIUM,24,Color.WHITE],
	
	types.UX:[OXANIUM,54,Color.WHITE],
	types.UX_M:[OXANIUM,48,Color.WHITE],
	types.UX_S:[OXANIUM,32,Color.WHITE],
	types.UX_XS:[OXANIUM,16,Color.WHITE],
	
	types.VFX:[OXANIUM,32,dark_yellow],
	types.VFX_SMALL:[OXANIUM,16,dark_yellow],
	
	types.SOLD_OUT:[OXANIUM,38,Color.RED],
	
}
