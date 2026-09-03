extends Node2D

const COMING_FORMAT := "res://assets/character/coming/sprite_%03d.png"
const IDLE_FORMAT := "res://assets/character/coming/sprite_%03d.png"
const COMING_FRAME_COUNT := 13
const IDLE_FRAME_COUNT := 47
const COMING_FPS := 8.0
const IDLE_FPS := 8.0

const START_POSITION := Vector2(390, 503)

@export var target_position := Vector2(372, 503)
@export var walk_duration := 1.5

@onready var sprite: AnimatedSprite2D = $Sprite

var _walk_tween: Tween

func _ready():
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("coming")
	frames.set_animation_loop("coming", false)
	frames.set_animation_speed("coming", COMING_FPS)
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", IDLE_FPS)
	for i in range(1, COMING_FRAME_COUNT + 1):
		frames.add_frame("coming", load(COMING_FORMAT % i))
	for i in range(COMING_FRAME_COUNT + 1, COMING_FRAME_COUNT + IDLE_FRAME_COUNT + 1):
		frames.add_frame("idle", load(IDLE_FORMAT % i))
	sprite.sprite_frames = frames
	position = target_position

func walk_in():
	if _walk_tween and _walk_tween.is_valid():
		_walk_tween.kill()
	position = START_POSITION
	sprite.play("coming")
	_walk_tween = create_tween()
	_walk_tween.tween_property(self, "position", target_position, walk_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_walk_tween.tween_callback(_on_walk_finished)

func _on_walk_finished():
	sprite.play("idle")
