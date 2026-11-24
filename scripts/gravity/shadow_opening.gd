extends Node3D

const COURIER := preload("res://scenes/player/courier.tscn")
const DESTINATION := Vector3(30, 0, 0)
const CHECKPOINT := &"east_wing_shadow_checkpoint"
@onready var player: CharacterBody3D = $"../Player"
var shadow: Node3D
var objective := Label.new()
var arrived := false
var finished := false
var started_at := 0
const EXIT := Vector3(0, 0, 12)

func _ready() -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("#ff4234")
	var globe := SphereMesh.new()
	globe.radius = 0.24
	globe.height = 0.65
	globe.material = glow
	for index in 3:
		var lantern := MeshInstance3D.new()
		lantern.mesh = globe
		lantern.position = DESTINATION + Vector3(0, 3.2, (index - 1) * 0.85)
		add_child(lantern)
	player.get_node("HUD").add_child(objective)
	objective.position = Vector2(20, 55)
	objective.add_theme_constant_override("outline_size", 5)
	started_at = Time.get_ticks_msec()
	if get_tree().has_meta(CHECKPOINT):
		started_at = get_tree().get_meta(&"shadow_start", started_at)
		objective.text = "Shadow reclaimed! Escape to the starting balcony."
		player.global_position = get_tree().get_meta(CHECKPOINT)
		arrived = true
		return
	objective.text = "Follow your shadow to the three red lanterns."
	shadow = COURIER.instantiate()
	add_child(shadow)
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color("#36284e")
	for mesh in shadow.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = ink
	for light in shadow.find_children("*", "Light3D", true, false):
		light.hide()
	shadow.position = player.position + Vector3(0, 0, -1.3)
	var flight := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var launch := shadow.position
	flight.tween_property(shadow, "scale", Vector3(1.06, 0.81, 1.06), 0.24)
	flight.tween_property(shadow, "scale", Vector3.ONE, 0.13)
	flight.tween_method(func(t: float):
		shadow.position = launch.lerp(DESTINATION, t) + Vector3.UP * sin(PI*t)*5.2
		shadow.rotation.z = sin(TAU*t)*0.16
		shadow.get_node("LeftLeg").rotation.x = sin(PI*t)*0.82
		shadow.get_node("RightLeg").rotation.x = -sin(PI*t)*0.52
		shadow.get_node("Torso/ScarfSwing").rotation.x = -sin(PI*t)*0.85
	, 0.0, 1.0, 2.0)
	flight.tween_property(shadow, "scale", Vector3(1.06, 0.85, 1.06), 0.12)
	flight.tween_property(shadow, "scale", Vector3.ONE, 0.23)

func _physics_process(_delta: float) -> void:
	if finished or not player.is_on_floor():
		return
	if arrived:
		if player.global_position.distance_to(EXIT) < 2.2:
			finished = true
			var seconds := (Time.get_ticks_msec() - started_at) / 1000.0
			var best := minf(seconds, get_tree().get_meta(&"shadow_best", seconds))
			get_tree().set_meta(&"shadow_best", best)
			get_tree().remove_meta(CHECKPOINT)
			get_tree().remove_meta(&"shadow_start")
			objective.text = "ESCAPED   %.1fs   |   Session best %.1fs   |   R to race again" % [seconds, best]
			for ghost in get_tree().get_nodes_in_group("castle_ghosts"):
				ghost.set_physics_process(false)
		return
	if player.global_position.distance_to(DESTINATION) < 2.0:
		arrived = true
		get_tree().set_meta(CHECKPOINT, player.global_position + Vector3.UP * 0.15)
		shadow.hide()
		get_tree().set_meta(&"shadow_start", started_at)
		objective.text = "Shadow reclaimed! Escape to the starting balcony."

func _unhandled_key_input(event: InputEvent) -> void:
	if finished and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()