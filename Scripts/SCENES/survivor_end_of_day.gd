extends Control

@export var confirm_button : Button

@onready var icon: TextureRect = $Resume/SurvivorBio/Portrait/Icon
@onready var survivor_name: Label = $Resume/SurvivorName
@onready var pnj_age: Label = $Resume/SurvivorBio/PNJAge
@onready var pnj_job_name: Label = $Resume/SurvivorBio/PNJJobName
@onready var pnj_job_descr: Label = $Resume/SurvivorBio/PNJJobDescr
@onready var pnj_bio: Label = $Resume/SurvivorBio/PNJBio
@onready var weapon_icon: TextureRect = $Resume/Weapon/ColorRect/WeaponIcon
@onready var weapon_descr: Label = $Resume/Weapon/WeaponDescr
@onready var pnj_weapon: Label = $Resume/Weapon/PNJWeapon


@export_group("Car full")
@export var crew_choice : Control          # shown only when the car has more survivors than seats
@export var crew_title : Label
@export var passenger_template : Button    # duplicated per choice (children: Icon, Name, Job, Weapon)

const LEFT_BEHIND_COLOR : Color = Color(0.45, 0.45, 0.45)

var leaving : bool = false
var crew_candidates : Array[SurvivorData] = []  # everyone but the driver, newcomer included
var crew_cards : Array[Button] = []
var crew_kept : Array[bool] = []                 # true = stays on board

func _ready() -> void:
	var survivor : SurvivorData = SurvivorsManager.rescued_survivor
	if survivor == null:
		SceneManager.load_post_raid()
		return
	BloodBars.hide()
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.grab_focus()
	icon.texture = survivor.icon
	survivor_name.text = survivor.name
	pnj_age.text = str(survivor.age) + " years old"
	pnj_job_name.text = tr(survivor.job_ressource.name)
	pnj_job_descr.text = tr(survivor.job_ressource.description)
	pnj_bio.text = survivor.bio
	weapon_icon.texture = survivor.weapon.weapon_icon
	weapon_descr.text = survivor.weapon.description
	pnj_weapon.text = survivor.weapon.weapon_name

	if SurvivorsManager.is_car_overloaded():
		_build_crew_choice(survivor)
	else:
		crew_choice.hide()


func _on_confirm_pressed() -> void:
	if leaving:
		return
	leaving = true
	confirm_button.disabled = true
	# Car full: the ones not kept stay on the road, newcomer included when he was not taken
	for i : int in crew_candidates.size():
		if !crew_kept[i]:
			SurvivorsManager.drop_survivor(crew_candidates[i])
	SurvivorsManager.confirm_rescue()  # nothing to do when the newcomer was the one left behind
	SceneManager.load_post_raid()


## Car full: the player picks who stays on board. Every passenger starts on board, the newcomer on the road
func _build_crew_choice(newcomer : SurvivorData) -> void:
	crew_choice.show()
	passenger_template.hide()
	var cards_parent : Node = passenger_template.get_parent()
	var newcomer_card : Button = null
	# [0] = the driver: always on board, not a choice
	for i : int in range(1, SurvivorsManager.on_board_survivors.size()):
		var passenger : SurvivorData = SurvivorsManager.on_board_survivors[i]
		var card : Button = passenger_template.duplicate() as Button
		cards_parent.add_child(card)
		card.show()
		# owned = false: the children of a duplicated card have no owner, the default search skips them
		(card.find_child("Icon", true, false) as TextureRect).texture = passenger.icon
		(card.find_child("Name", true, false) as Label).text = passenger.name
		(card.find_child("Job", true, false) as Label).text = tr(passenger.job_ressource.name)
		(card.find_child("Weapon", true, false) as Label).text = passenger.weapon.weapon_name
		card.pressed.connect(_on_crew_card_pressed.bind(crew_cards.size()))
		crew_candidates.append(passenger)
		crew_cards.append(card)
		crew_kept.append(passenger != newcomer)
		if passenger == newcomer:
			newcomer_card = card
	_refresh_crew_choice()
	if newcomer_card != null:
		newcomer_card.grab_focus()


func _on_crew_card_pressed(index : int) -> void:
	crew_kept[index] = !crew_kept[index]
	_refresh_crew_choice()


## Passenger seats = car seats minus the driver: Ok only with exactly that many kept
func _refresh_crew_choice() -> void:
	var passenger_seats : int = CarManager.selected_car.seats - 1
	var kept_count : int = crew_kept.count(true)
	for i : int in crew_cards.size():
		var card : Button = crew_cards[i]
		(card.find_child("Status", true, false) as Label).text = tr("CREW_ON_BOARD") if crew_kept[i] else tr("CREW_LEFT_BEHIND")
		card.modulate = Color.WHITE if crew_kept[i] else LEFT_BEHIND_COLOR
	crew_title.text = "%s\n%d / %d" % [tr("CREW_FULL_CHOOSE"), kept_count, passenger_seats]
	confirm_button.disabled = kept_count != passenger_seats
