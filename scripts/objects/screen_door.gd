extends Node3D

const SHOP_DISPLAYS := [
	preload("res://scenes/world/sections/shopfront_0.res"),
	preload("res://scenes/world/sections/shopfront_1.res"),
	preload("res://scenes/world/sections/shopfront_2.res")
]

var target_open := false
var travel := 0.0
var occupants := {}

func _ready() -> void:
	var display := MeshInstance3D.new()
	display.name = "ShopDisplay"
	display.mesh = SHOP_DISPLAYS[hash(Vector3i(global_position.round())) % SHOP_DISPLAYS.size()]
	display.visibility_range_end = 75.0
	display.visibility_range_end_margin = 6.0
	add_child(display)
	$Approach.body_entered.connect(_enter)
	$Approach.body_exited.connect(_leave)
	set_physics_process(false)

func _enter(body: Node3D) -> void:
	if body is CharacterBody3D:
		occupants[body.get_instance_id()] = true
		set_open(true)

func _leave(body: Node3D) -> void:
	if not occupants.erase(body.get_instance_id()):
		return
	if occupants.is_empty():
		set_open(false)

func set_open(value: bool) -> void:
	target_open = value
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	travel = move_toward(travel,float(target_open),delta / (0.64 if target_open else 0.94))
	# The second screen follows a beat later. Reversals continue from the current pose.
	var left := smoothstep(0.0,0.91,travel)
	var right := smoothstep(0.09,1.0,travel)
	# Keep each outside hinge fixed in the room's local frame.
	var a := left * PI * 0.5
	var b := right * PI * 0.5
	$Left.position = Vector3(-1.46 + 0.73*cos(a), 1.775, -0.73*sin(a))
	$Left.rotation.y = a
	$Right.position = Vector3(1.46 - 0.73*cos(b), 1.775, -0.73*sin(b))
	$Right.rotation.y = -b
	if travel == float(target_open):
		set_physics_process(false)
