extends Node3D

enum State { PATROL, CHASE, SEARCH }
@export var patrol_offset := Vector3(8, 0, 0)
var state := State.PATROL
var home: Vector3
var destination: Vector3
var last_seen: Vector3
var toward_home := false
var sight_timer := 0.0
var sees_player := false
var search_time := 0.0
var phase := 0.0
@onready var player: CharacterBody3D = get_parent().get_node("Player")

func _ready() -> void:
	home = global_position
	destination = home + patrol_offset
	phase = fmod(home.length(), TAU)
	sight_timer = phase * 0.04

func clear_sight(target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, target, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
	if get_tree().current_scene == null or get_parent().has_meta("courier_caught"):
		return
	var target := player.global_position + player.up_direction * 1.2
	var distance := global_position.distance_to(target)
	sight_timer -= delta
	if sight_timer <= 0.0:
		sight_timer = 0.16
		sees_player = distance < (27.0 if state == State.CHASE else 17.0) and clear_sight(target)
	if sees_player:
		last_seen = target
		state = State.CHASE
		destination = target
	elif state == State.CHASE:
		state = State.SEARCH
		search_time = 5.0
		destination = last_seen
	if state == State.SEARCH:
		search_time -= delta
		if search_time <= 0:
			state = State.PATROL
			destination = home
			toward_home = true
	if state == State.PATROL and global_position.distance_to(destination) < 0.15:
		toward_home = not toward_home
		destination = home if toward_home else home + patrol_offset
	var speed := 3.9 if state == State.CHASE else 1.55
	var heading := destination - global_position
	if heading.slide(Vector3.UP).length_squared() > 0.02:
		rotation.y = lerp_angle(rotation.y, atan2(-heading.x, -heading.z), 1.0-exp(-4.0*delta))
	global_position = global_position.move_toward(destination, speed * delta)
	phase += delta * 2.2
	$Spirit.position.y = sin(phase)*0.12
	$Spirit.rotation.z = sin(phase*.7)*.045
	if distance < 1.0 and sees_player and clear_sight(target):
		get_parent().set_meta("courier_caught", true)
		var message := Label.new()
		player.get_node("HUD").add_child(message)
		message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		message.add_theme_font_size_override("font_size", 36)
		message.add_theme_constant_override("outline_size", 7)
		message.text = "Caught by a ghost"
		await get_tree().create_timer(1.1).timeout
		get_tree().reload_current_scene()
