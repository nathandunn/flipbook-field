## Player — third-person block character, camera-relative movement.
class_name Player
extends CharacterBody3D

signal interact_pressed

@export var walk_speed: float = 3.2
@export var run_speed: float = 5.8
@export var acceleration: float = 14.0
@export var turn_speed: float = 12.0
@export var mouse_sensitivity: float = 0.0032
@export var pitch_min: float = -0.95
@export var pitch_max: float = 0.45
## Screen-space ink pass. Needs the normal-roughness buffer, which only exists in
## Forward+ — it is switched off automatically under Mobile/Compatibility rather
## than rendering as a magenta shader error.
@export var ink_post_enabled: bool = true

## Face 0 is the drawing cast as the player; face 1 is the nemesis. The rest
## of the deck is dealt out to the crowd by [Game].
const PLAYER_FACE := 0

var rig: BlockFigure
## The job you chose at the start. Dressing happens in [method dress].
var role: int = Arch.Role.STAFF
var input_locked: bool = false

## When set, the character walks itself there and ignores the stick entirely.
## Cleared on arrival, which is how [Game] knows a queued leg is done. Autopilot
## deliberately overrides [member input_locked]: a planned route plays out while
## the controls are locked, which is the whole point of watching it.
var auto_target: Variant = null
## Brisk but still readable — the walk is the thing being watched.
@export var auto_speed: float = 4.4
const AUTO_ARRIVE := 0.55

## Set by TouchControls on phones; added to the keyboard stick each frame.
var touch_move := Vector2.ZERO
## Accumulated look delta in pixels from a touch drag, consumed each frame.
var touch_look := Vector2.ZERO

var touch_mode: bool = false

@onready var cam_yaw: Node3D = $CamYaw
@onready var spring: SpringArm3D = $CamYaw/SpringArm3D
@onready var camera: Camera3D = $CamYaw/SpringArm3D/Camera3D

var _gravity: float = 18.0
var _move_amt: float = 0.0


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * 1.8
	# Same as Person: stand on the world, pass through people.
	collision_layer = 2
	collision_mask = 1

	dress(role)

	_setup_ink_pass()

	# Slight downward tilt: looking very slightly down on the group reads as a
	# comic panel's establishing angle rather than a shooter's eyeline.
	spring.rotation.x = deg_to_rad(-12.0)

	# The camera arm must not collide with the character it is attached to.
	spring.add_excluded_object(get_rid())

	# Browsers only grant pointer lock from inside a user gesture, so on web the
	# capture has to wait for a click rather than happening here. On a touchscreen
	# it never happens at all — TouchControls drives the camera instead.
	touch_mode = DisplayServer.is_touchscreen_available()
	if not touch_mode and not _is_web():
		_capture_mouse(true)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Put on a class's costume. Rebuilds the rig, so it is safe to call after the
## setup screen has decided who you are.
func dress(p_role: int) -> void:
	role = p_role
	if rig:
		remove_child(rig)
		rig.queue_free()
	rig = BlockFigure.create(
		Ink.SKINS[2], Color("c4614f"), Ink.PANTS[0], Ink.HAIRS[1], 1.0, 0.0,
		PLAYER_FACE, role
	)
	rig.name = "Rig"
	add_child(rig)


func _is_web() -> bool:
	return OS.get_name() == "Web"


## The full-screen ink pass needs the normal-roughness buffer, which exists only
## under Forward+. Check the *live* renderer, not the project setting: launching
## with --rendering-driver opengl3 leaves the setting saying "forward_plus" while
## the actual device is a Compatibility one, and the material is then assigned
## only if it can compile — an unassignable shader still renders as an opaque
## sheet across the whole camera.
func _setup_ink_pass() -> void:
	var ink_pass := get_node_or_null("CamYaw/SpringArm3D/Camera3D/InkPass") as MeshInstance3D
	if ink_pass == null:
		return

	var has_device := RenderingServer.get_rendering_device() != null
	var method := str(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "forward_plus"
	))
	var ok: bool = ink_post_enabled and has_device and method == "forward_plus"

	ink_pass.visible = ok
	ink_pass.material_override = load("res://materials/ink_post.tres") if ok else null
	if not ok and ink_post_enabled:
		push_warning("Ink post-pass off: needs the Forward+ renderer. Outlines still draw.")


func _capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	# Never grab the pointer while a panel owns the screen. A click that misses a
	# button would otherwise lock the cursor and leave the panel unclickable,
	# with no way back that the player would ever guess. Esc and T stay live.
	if not input_locked and not touch_mode and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse(true)
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		cam_yaw.rotation.y -= mm.relative.x * mouse_sensitivity
		spring.rotation.x = clampf(
			spring.rotation.x - mm.relative.y * mouse_sensitivity, pitch_min, pitch_max
		)

	if event.is_action_pressed("toggle_mouse"):
		_capture_mouse(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("toggle_ink"):
		var ink_pass := get_node_or_null("CamYaw/SpringArm3D/Camera3D/InkPass") as MeshInstance3D
		if ink_pass and ink_pass.material_override:
			ink_pass.visible = not ink_pass.visible

	if event.is_action_pressed("interact"):
		interact_pressed.emit()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var dir := Vector3.ZERO
	var auto := false
	if auto_target != null:
		var t: Vector3 = auto_target
		var to := Vector3(t.x - global_position.x, 0.0, t.z - global_position.z)
		if to.length() <= AUTO_ARRIVE:
			auto_target = null
		else:
			dir = to.normalized()
			auto = true

	if not auto and not input_locked:
		var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		stick += touch_move
		if stick.length() > 1.0:
			stick = stick.normalized()
		# Movement is relative to where the camera is looking, not where the
		# character is facing — the character turns to follow, which is what gives
		# the walk its lag and weight.
		var cam_basis := cam_yaw.global_transform.basis
		dir = (cam_basis.x * stick.x + cam_basis.z * stick.y)
		dir.y = 0.0
		if dir.length() > 0.001:
			dir = dir.normalized()
		else:
			dir = Vector3.ZERO

	var speed := auto_speed if auto else (run_speed if Input.is_action_pressed("run") else walk_speed)
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	move_and_slide()

	var planar := Vector2(velocity.x, velocity.z)
	if planar.length() > 0.15:
		var want := atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, want, clampf(turn_speed * delta, 0.0, 1.0))

	_move_amt = clampf(planar.length() / run_speed, 0.0, 1.0)
	if rig:
		rig.animate(delta, _move_amt)


func _process(_delta: float) -> void:
	# Touch look is applied here rather than in the input handler so a drag and a
	# frame aren't fighting over the same rotation.
	if touch_look != Vector2.ZERO:
		cam_yaw.rotation.y -= touch_look.x
		spring.rotation.x = clampf(spring.rotation.x - touch_look.y, pitch_min, pitch_max)
		touch_look = Vector2.ZERO


## World-space point roughly at the mouth — where a speech bubble tail should land.
func speech_anchor() -> Vector3:
	return global_position + Vector3(0, 1.62, 0)
