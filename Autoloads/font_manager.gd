extends Node

enum types {
	DEFAUT,TITLE,TITLE_LOW,
	MENU,MENU_FOCUS,MENU_PRESSED,MENU_HOVER,
	BUTTON,BUTTON_FOCUS,BUTTON_PRESSED,BUTTON_HOVER,
	TEXT,TEXT_TITLE,TEXT_TITLE_LOW,
	UX,UX_M,UX_S,UX_XS,
	SFX
}

var purple : Color = Color(0.686, 0.067, 0.435)
var dark_yellow : Color = Color(1.0, 0.776, 0.0)
var UX_outline : int = 8
var UX_color : Color = Color.BLACK

var FONTS : Dictionary = {
	types.TITLE:[preload("uid://ka3caedu5yxc"),72,dark_yellow],
	types.TITLE_LOW:[preload("uid://ka3caedu5yxc"),64,dark_yellow],
	
	types.MENU:[preload("uid://ka3caedu5yxc"),48,dark_yellow],
	types.MENU_FOCUS:[preload("uid://ka3caedu5yxc"),48,Color.WHITE],
	types.MENU_PRESSED:[preload("uid://ka3caedu5yxc"),48,dark_yellow],
	types.MENU_HOVER:[preload("uid://ka3caedu5yxc"),48,dark_yellow],
	
	types.BUTTON:[preload("uid://ka3caedu5yxc"),24,Color.BLACK],
	types.BUTTON_FOCUS:[preload("uid://ka3caedu5yxc"),24,Color.BLACK],
	types.BUTTON_PRESSED:[preload("uid://ka3caedu5yxc"),24,Color.BLACK],
	types.BUTTON_HOVER:[preload("uid://ka3caedu5yxc"),24,Color.BLACK],
	
	types.TEXT_TITLE:[preload("uid://ka3caedu5yxc"),40,Color.WHITE],
	types.TEXT_TITLE_LOW:[preload("uid://ka3caedu5yxc"),32,Color.WHITE],
	types.TEXT:[preload("uid://ka3caedu5yxc"),24,Color.WHITE],
	
	types.UX:[preload("uid://ka3caedu5yxc"),64,Color.WHITE],
	types.UX_M:[preload("uid://ka3caedu5yxc"),48,Color.WHITE],
	types.UX_S:[preload("uid://ka3caedu5yxc"),32,Color.WHITE],
	types.UX_XS:[preload("uid://ka3caedu5yxc"),16,Color.WHITE],
	
	types.SFX:[preload("uid://ka3caedu5yxc"),32,dark_yellow],
}
