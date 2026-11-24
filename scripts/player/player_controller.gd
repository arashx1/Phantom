extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_speed: float = 7.0
@export var gravity_strength: float = 20.0
@export var mouse_sensitivity: float = 0.002

@onready var head: Node3D = $Head
@onready var visual: Node3D = $Visual
@onready var first_camera: Camera3D = $Head/Camera3D
@onready var third_camera: Camera3D = $Head/SpringArm3D/ThirdPersonCamera
@onready var arm: SpringArm3D = $Head/SpringArm3D
var third_person: bool = true
var stride: float = 0.0
var sit_held := false
var crawl_held := false
var grace := 0.0
var vault_time := 0.0
var vault_direction := Vector3.ZERO
var buffered_jump := 0.0
var stable_time := 0.0
var safe_position: Vector3
var safe_basis := Basis.IDENTITY
var gravity_turn_rate := 0.0
var pending_up := Vector3.UP
var pending_time := 0.0
var turn_axis := Vector3.RIGHT
var field_up := Vector3.UP
var gravity_map: Node
var climbing := false
var climb_start := Vector3.ZERO
var climb_top := Vector3.ZERO
var climb_forward := Vector3.ZERO
var climb_time := 0.0
var next_grab := 0.0
var climbing_hand: Node3D
var gait_weight := 0.0
var breath := 0.0
var body_heading := 0.0
var previous_speed := 0.0
var airborne_time := 0.0
var landing := 0.0
@onready var left_leg: Node3D = $Visual/LeftLeg
@onready var right_leg: Node3D = $Visual/RightLeg
@onready var left_arm: Node3D = $Visual/Torso/LeftArm
@onready var right_arm: Node3D = $Visual/Torso/RightArm
@onready var scarf: Node3D = $Visual/Torso/ScarfSwing

enum Posture { STAND, SIT, CRAWL }
var posture := Posture.STAND
@onready var collider: CollisionShape3D = $CollisionShape3D

func change_posture(next: Posture) -> void:
	if not is_on_floor():
		return
	var height := 2.36 if next == Posture.STAND else (1.55 if next == Posture.SIT else 0.84)
	var capsule := collider.shape as CapsuleShape3D
	if height > capsule.height:
		var check := PhysicsShapeQueryParameters3D.new()
		var taller := capsule.duplicate() as CapsuleShape3D
		taller.height = height
		check.shape = taller
		check.transform = Transform3D(global_basis, global_position + up_direction*(height*0.5+0.04))
		check.exclude = [get_rid()]
		check.collision_mask = collision_mask
		if not get_world_3d().direct_space_state.intersect_shape(check,1).is_empty():
			return
	posture = next
	capsule.height = height
	collider.position.y = height*0.5

var lantern_arm: Node3D

func _ready() -> void:
	safe_position = global_position
	floor_snap_length = 0.22
	lantern_arm = right_arm.duplicate() as Node3D
	first_camera.add_child(lantern_arm)
	lantern_arm.position = Vector3(0.52,-0.10,-0.48)
	lantern_arm.rotation = Vector3(1.35,0.57,0.10)
	lantern_arm.scale = Vector3.ONE * 0.82
	lantern_arm.get_node("Lantern").rotation.x = -1.35
	climbing_hand = left_arm.duplicate() as Node3D
	first_camera.add_child(climbing_hand)
	climbing_hand.scale = Vector3.ONE * 0.82
	climbing_hand.position = Vector3(-0.40,-0.13,-0.47)
	arm.add_excluded_object(get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_view()

func update_view() -> void:
	visual.visible = third_person
	lantern_arm.visible = not third_person
	climbing_hand.visible = climbing and not third_person
	lantern_arm.get_node("Lantern").visible = not climbing
	right_arm.get_node("Lantern").visible = not climbing
	first_camera.current = not third_person
	third_camera.current = third_person

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode == KEY_V:
			third_person = not third_person
			update_view()
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var yaw: float = -event.relative.x * mouse_sensitivity
		rotate_object_local(Vector3.UP, yaw)
		if third_person:
			body_heading = wrapf(body_heading - yaw, -PI, PI)
		head.rotation.x = clampf(
			head.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-75), deg_to_rad(75)
		)

func can_vault(direction: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var extension := direction * 1.05
	var feet := global_position
	var detected := false
	for height in [0.55, 1.22, 1.75, 2.45]:
		var start: Vector3 = feet + up_direction * height
		var query := PhysicsRayQueryParameters3D.create(start, start + extension, collision_mask, [get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			if height > 1.5:
				return false
			detected = true
	return detected

func align_to_floor(delta: float) -> void:
	if gravity_map == null:
		gravity_map = get_tree().get_first_node_in_group("castle_gravity")
	if gravity_map == null:
		return
	var candidate: Vector3 = gravity_map.sample_up(global_position + up_direction * 0.25, field_up)
	# A briefly overlapping field should not reverse a turn already in progress.
	if candidate.dot(pending_up) < 0.9999:
		pending_time = 0
	pending_up = candidate
	pending_time += delta
	if pending_time >= 0.065:
		field_up = pending_up
	var angle := up_direction.angle_to(field_up)
	if angle < 0.0001:
		gravity_turn_rate = 0.0
		return
	var axis := up_direction.cross(field_up)
	if axis.length_squared() > 0.000001:
		turn_axis = axis.normalized()
	elif absf(up_direction.dot(turn_axis)) > 0.01:
		turn_axis = global_basis.x
	# Limit angular acceleration on entry and brake progressively near alignment.
	var desired_rate := minf(3.0, angle * 5.8)
	gravity_turn_rate = move_toward(gravity_turn_rate, desired_rate, 9.0 * delta)
	global_basis = global_basis.rotated(turn_axis,minf(angle,gravity_turn_rate*delta)).orthonormalized()
	up_direction = global_basis.y

func try_grab(direction: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var chest := global_position + up_direction * 1.44
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, chest + direction*0.9, collision_mask, [get_rid()]))
	if wall.is_empty() or absf(wall.normal.dot(up_direction)) > 0.32:
		return false
	var inward: Vector3 = -wall.normal.slide(up_direction).normalized()
	var over_lip: Vector3 = wall.position + inward*0.47
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(over_lip+up_direction*1.50, over_lip-up_direction*0.12, collision_mask, [get_rid()]))
	if top.is_empty() or top.normal.dot(up_direction) < 0.86:
		return false
	var arrival: Vector3 = top.position+up_direction*0.055
	var room := PhysicsShapeQueryParameters3D.new()
	room.shape = collider.shape
	room.transform = Transform3D(global_basis, arrival + up_direction*collider.position.y)
	room.collision_mask = collision_mask
	room.exclude = [get_rid()]
	if not space.intersect_shape(room,1).is_empty():
		return false
	climb_start = global_position
	climb_top = arrival
	climb_forward = inward
	climb_time = 0
	climbing = true
	velocity = Vector3.ZERO
	grace = 0
	buffered_jump = 0
	update_view()
	return true

func finish_climb() -> void:
	climbing = false
	next_grab = 0.25
	lantern_arm.rotation = Vector3(1.35,0.57,0.10)
	update_view()

func advance_climb(delta: float) -> void:
	climb_time = minf(climb_time + delta/1.05, 1)
	var height := (climb_top-climb_start).dot(up_direction)
	var rise := smoothstep(0.08,0.70,climb_time)
	var inward := smoothstep(0.69,1.0,climb_time)
	var next := climb_start + up_direction*height*rise + (climb_top-climb_start).slide(up_direction)*inward
	var motion := next-global_position
	var hit := move_and_collide(motion)
	if hit and hit.get_remainder().length() > 0.015:
		finish_climb()
		return
	var relative := global_basis.inverse()*climb_forward
	body_heading = rotate_toward(body_heading, atan2(-relative.x,-relative.z), delta*10)
	visual.rotation.y = body_heading
	var reach := sin(climb_time*TAU)
	var pull := smoothstep(0.59,1.0,climb_time)
	var mix_pose := 1-exp(-18*delta)
	for i in 2:
		var arm_node := left_arm if i == 0 else right_arm
		var leg_node := left_leg if i == 0 else right_leg
		var beat := reach if i == 0 else -reach
		arm_node.rotation.x = lerpf(arm_node.rotation.x, (2.50+0.43*beat)*(1-pull)+0.40*pull, mix_pose)
		arm_node.rotation.z = lerpf(arm_node.rotation.z, (-0.19 if i==0 else 0.19)*(1-pull), mix_pose)
		leg_node.rotation.x = lerpf(leg_node.rotation.x, (0.62-0.43*beat)*(1-pull), mix_pose)
		var knee := leg_node.get_node("Knee") as Node3D
		knee.rotation.x = lerpf(knee.rotation.x, (-1.0+0.4*beat)*(1-pull), mix_pose)
	climbing_hand.rotation = Vector3(2.26+0.47*reach, -0.35, 0.18)
	lantern_arm.rotation = Vector3(2.26-0.47*reach, 0.35, -0.18)
	if climb_time >= 1:
		finish_climb()

func _physics_process(delta: float) -> void:
	if climbing:
		advance_climb(delta)
		return
	next_grab = maxf(0, next_grab-delta)
	align_to_floor(delta)
	var grounded := is_on_floor()
	var playing := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
	if playing:
		if Input.is_physical_key_pressed(KEY_C) and not sit_held:
			change_posture(Posture.STAND if posture == Posture.SIT else Posture.SIT)
		elif Input.is_physical_key_pressed(KEY_Z) and not crawl_held:
			change_posture(Posture.STAND if posture == Posture.CRAWL else Posture.CRAWL)
	sit_held = Input.is_physical_key_pressed(KEY_C)
	crawl_held = Input.is_physical_key_pressed(KEY_Z)
	var movement := Vector2.ZERO
	if playing:
		movement = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	buffered_jump = maxf(0.0, buffered_jump - delta)
	if playing and posture == Posture.STAND and Input.is_action_just_pressed("jump"):
		buffered_jump = 0.14
	grace = 0.11 if grounded else maxf(0.0, grace - delta)
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if posture == Posture.SIT:
		speed = 0.0
	elif posture == Posture.CRAWL:
		speed = 1.45
	var target := global_basis * Vector3(movement.x, 0, movement.y) * speed
	if playing and posture == Posture.STAND and movement.y < -0.55 and Input.is_action_pressed("jump") and vault_time <= 0 and next_grab <= 0:
		next_grab = 0.10
		if try_grab(target.normalized()):
			advance_climb(delta)
			return
	var acceleration := 38.0 if grounded else 14.0
	if grounded and movement.is_zero_approx():
		acceleration = 48.0
	vault_time = maxf(0.0, vault_time - delta)
	if vault_time > 0:
		target = vault_direction.slide(up_direction) * 6.4
		acceleration = 75.0
	var horizontal := velocity.slide(up_direction).move_toward(target, acceleration * delta)
	var vertical := velocity.dot(up_direction)
	if buffered_jump > 0 and grace > 0:
		vertical = jump_speed
		if grounded and movement.length_squared() > 0.04 and can_vault(target.normalized()):
			vault_direction = target.normalized()
			vault_time = 0.60
			vertical = 9.7
		grace = 0.0
		buffered_jump = 0.0
	elif not grounded:
		var fall_multiplier := 1.38 if vertical < 0 else 1.0
		if vault_time <= 0 and vertical > 0 and not Input.is_action_pressed("jump"):
			fall_multiplier = 1.8
		vertical = maxf(-40.0, vertical - gravity_strength * fall_multiplier * delta)
	velocity = horizontal + up_direction*vertical
	var approach_y := vertical
	move_and_slide()
	if is_on_floor():
		stable_time += delta
		if stable_time > 0.25 and get_floor_normal().dot(up_direction) > 0.85:
			safe_basis = global_basis
			safe_position = global_position + up_direction * 0.12
		if not grounded:
			landing = clampf(-approach_y * 0.014, 0, 0.14)
	else:
		stable_time = 0
	if global_position.distance_to(Vector3(0,0,-28)) > 260:
		vault_time = 0.0
		global_basis = safe_basis
		up_direction = safe_basis.y
		field_up = up_direction
		pending_up = field_up
		pending_time = 0.0
		gravity_turn_rate = 0.0
		global_position = safe_position
		velocity = Vector3.ZERO
		reset_physics_interpolation()
	var on_gallery := false
	if is_on_floor():
		for index in get_slide_collision_count():
			if get_slide_collision(index).get_collider().is_in_group("return_gallery"):
				on_gallery = true
				break
	$HUD/ReturnPrompt.visible = on_gallery
	if on_gallery and playing and Input.is_physical_key_pressed(KEY_E):
		global_transform = Transform3D(Basis.IDENTITY,Vector3(0,0.3,12))
		up_direction = Vector3.UP
		field_up = up_direction
		pending_up = up_direction
		gravity_turn_rate = 0
		velocity = Vector3.ZERO
		reset_physics_interpolation()
	animate_courier(delta, get_real_velocity().slide(up_direction))

func animate_courier(delta: float, horizontal: Vector3) -> void:
	var speed := horizontal.length()
	var blend := 1.0 - exp(-12.0 * delta)
	var run := clampf(speed / sprint_speed, 0.0, 1.0)
	var grounded := is_on_floor()
	var turn := 0.0
	if speed > 0.2 and grounded:
		var local_direction := global_basis.inverse()*horizontal
		var desired := atan2(-local_direction.x, -local_direction.z)
		turn = angle_difference(body_heading, desired)
		body_heading = rotate_toward(body_heading, desired, delta * lerpf(10.0, 7.0, run))
	visual.rotation.y = body_heading
	gait_weight = lerpf(gait_weight, run if grounded else 0.0, blend)
	breath = fmod(breath + delta * 2.4, TAU)
	stride = fmod(stride + delta * speed * lerpf(3.0, 1.94, run), TAU)
	var phase := sin(stride)
	var rising := clampf(velocity.dot(up_direction) / jump_speed, -1.0, 1.0)
	airborne_time = 0.0 if grounded else airborne_time + delta
	var airborne := smoothstep(0.015, 0.13, airborne_time) if posture == Posture.STAND else 0.0
	var descent := smoothstep(0.1, 9.0, -velocity.dot(up_direction)) * airborne
	var lift_pose := smoothstep(-0.2, 0.8, rising) * airborne
	var tuck := airborne * 0.50 + lift_pose * 0.48 - descent * 0.32
	var impact := smoothstep(0.01, 0.14, landing)
	if vault_time > 0:
		tuck += 0.70 * sin(PI * vault_time / 0.60)
	# Each foot lifts during recovery and extends through contact.
	for i in 2:
		var leg := left_leg if i == 0 else right_leg
		var cycle := stride + PI * i
		var lift := maxf(0, cos(cycle)) * gait_weight
		leg.position.y = lerpf(leg.position.y, 0.97 + 0.15 * lift + tuck * (0.15 if i == 0 else 0.07), blend)
		leg.rotation.x = lerpf(leg.rotation.x, impact*0.58 + sin(cycle)*0.77*gait_weight + tuck*(0.72 if i == 0 else -0.36), blend)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, -phase*gait_weight*0.61 - tuck*0.36, blend)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, phase*gait_weight*0.39 - tuck*0.25, blend)
	left_arm.rotation.z = lerpf(left_arm.rotation.z, 0.30-tuck*0.48-descent*1.45, blend)
	right_arm.rotation.z = lerpf(right_arm.rotation.z, -0.30+tuck*0.48+descent*1.29, blend)
	var acceleration := clampf((speed-previous_speed)/maxf(delta,0.001),-35,35)
	previous_speed = speed
	visual.rotation.x = lerpf(visual.rotation.x, -0.095*run - acceleration*0.002 - impact*0.27 - descent*0.16, blend)
	visual.rotation.z = lerpf(visual.rotation.z, clampf(turn,-1,1)*run*0.15 + phase*gait_weight*0.033, blend)
	landing = move_toward(landing, 0, delta*0.48)
	visual.position.y = lerpf(visual.position.y, -landing + cos(2*stride)*0.038*gait_weight + sin(breath)*0.003*(1-gait_weight), blend)
	scarf.rotation.x = lerpf(scarf.rotation.x, -run*0.49 + sin(stride-0.6)*gait_weight*0.08 - tuck*0.18 - descent*(1.08 + 0.11*sin(breath*4.1)), 1-exp(-6*delta))
	var vault_blend := sin(PI*vault_time/0.60)
	left_arm.rotation.z -= vault_blend*blend*0.65
	right_arm.rotation.z += vault_blend*blend*0.45
	scarf.rotation.z = lerpf(scarf.rotation.z,clampf(turn,-1,1)*run*0.23,blend)
	var seated := posture == Posture.SIT
	var crawling := posture == Posture.CRAWL
	$Visual/Torso/Skirt1.rotation.x = lerpf($Visual/Torso/Skirt1.rotation.x, gait_weight*phase*.22 - descent*.16 + (0.92 if seated else 0.0),blend)
	$"Visual/Torso/Skirt-1".rotation.x = lerpf($"Visual/Torso/Skirt-1".rotation.x, -gait_weight*phase*.22 - descent*.16 + (0.92 if seated else 0.0),blend)
	var eye_height := 1.37 if seated else (0.58 if crawling else 2.13)
	head.position.y = lerpf(head.position.y, eye_height, blend)
	var hip := Vector3(0,0.97,0)
	var tilt := -1.36 if crawling else 0.0
	var drop := 0.65 if seated else (0.61 if crawling else 0.0)
	var torso: Node3D = $Visual/Torso
	torso.rotation.x = lerpf(torso.rotation.x, tilt, blend)
	torso.position = hip + Basis(Vector3.RIGHT,torso.rotation.x)*(Vector3(0,0.49,0)-hip) - Vector3.UP*drop
	for i in 2:
		var leg := left_leg if i == 0 else right_leg
		var wave := sin(stride + PI*i)
		var knee := leg.get_node("Knee") as Node3D
		var bend := -impact*0.92 - tuck*(1.13 if i == 0 else 0.69) - descent*(0.25 if i == 0 else 0.49) - maxf(0,cos(stride+PI*i))*gait_weight*0.83
		if seated or crawling:
			leg.position.y = hip.y-drop
			leg.rotation.x = 1.43 if seated else -0.92+wave*0.41*minf(speed,1)
			bend = -0.66 if seated else -0.53+wave*0.24
			var limb := left_arm if i == 0 else right_arm
			limb.rotation.x = 0.58 if seated else 2.28-wave*0.45*minf(speed,1)
		knee.rotation.x = lerpf(knee.rotation.x,bend,blend)
