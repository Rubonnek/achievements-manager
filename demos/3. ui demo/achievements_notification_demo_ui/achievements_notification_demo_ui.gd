extends FlowContainer
class_name AchievementsNotificationsUIDemo

@export var achievement_shader : Shader
@export var time_to_appear : float = 0.5  # Time for fade-in animation
@export var time_to_display : float = 3.0 # Time to display before fading out
@export var time_to_disappear : float = 0.5  # Time for fade-out animation

# Here's how this works overall:
# 1) Achievement gets pushed
# 2) Animation starts - achievement will be displayed for X amount of time
# 3) If a new achievement gets pushed while the previous achievement is disappearing, kill the disappearing timer and restart it for all the notifications.

var _m_current_notifications_showing : Array[Button]
var _m_disappear_notifications_tween : Tween = null

const animation_started_tag : StringName = &"animation_started"


func on_achievement_unlocked(p_achievement_entry : AchievementEntry) -> void:
	if is_instance_valid(_m_disappear_notifications_tween):
		# Kill the disappearing animation
		_m_disappear_notifications_tween.kill()

		# And reset all the nodes affected by the disappearance animation
		for achievement_notification : Button in _m_current_notifications_showing:
			if achievement_notification.has_meta(animation_started_tag):
				achievement_notification.set_self_modulate(Color.WHITE)
				var notification_shader_material : ShaderMaterial = achievement_notification.get_material()
				notification_shader_material.set_shader_parameter(&"offset", Vector2(0, 0))

	# Initialize the achievement
	var achivement_notification : Button = Button.new()
	var achievement_text : String = achivement_notification.get_text()
	var achievement_name : String = p_achievement_entry.get_name()
	if achievement_name.is_empty():
		push_warning("AchievementsNotificationUI: achievement name is empty for achievement with id '%d'." % p_achievement_entry.get_id())
		achievement_name = "Achievement ID: %d" % p_achievement_entry.get_id()

	achivement_notification.set_text(achievement_text + "\n" + achievement_name)
	var shader_material : ShaderMaterial = ShaderMaterial.new()
	shader_material.set_shader(achievement_shader)
	achivement_notification.set_material(shader_material)

	# ====== APPEARANCE ANIMATION START =====
	var appear_tween : Tween = create_tween()
	appear_tween = appear_tween.set_parallel(true)
	var _ignore_property_tweener : PropertyTweener = appear_tween.tween_property(achivement_notification, ^"self_modulate", Color.WHITE, time_to_appear).from(Color.TRANSPARENT)
	shader_material.set_shader_parameter(&"offset", Vector2(0, 20))
	_ignore_property_tweener = appear_tween.tween_property(shader_material, ^"shader_parameter/offset", Vector2(0, 0), time_to_appear)
	# TODO: Report bug? Something is going wrong here in the "from" call -- tween_property also returns null which should return a pointer but the tweening works without the "from"
	#_ignore_property_tweener = appear_tween.tween_property(shader_material, ^"shader_parameter/offset", Vector2(0, 0), time_to_appear).from(Vector2(0, 20))

	# Store the tween reference so we can cancel it if a new achievement arrives
	achivement_notification.set_meta(&"appear_tween", appear_tween)

	# Add to queue and scene tree
	_m_current_notifications_showing.push_back(achivement_notification)
	add_child(achivement_notification)
	move_child(achivement_notification, get_parent().get_child_count()-1)


	# ====== DISAPPEARANCE ANIMATION START =====
	_m_disappear_notifications_tween = create_tween()

	# Let the notifications display for the specified amount of time
	var _ignore_tween_interval : IntervalTweener = _m_disappear_notifications_tween.tween_interval(time_to_appear + time_to_display)

	# Animate all achievements disappearance:
	# Here we tag all the all the achievement notifications whose disappearance animation started -- if the disappearance started and a new notification shows up, we cancel the disappearance and reset the state of these nodes.
	var _ignore_callback_tweener : CallbackTweener = _m_disappear_notifications_tween.tween_callback(__tag_nodes_being_animated)
	_m_disappear_notifications_tween = _m_disappear_notifications_tween.set_parallel(true)
	for achievement_notification : Button in _m_current_notifications_showing:
		_ignore_property_tweener = _m_disappear_notifications_tween.tween_property(achievement_notification, ^"self_modulate", Color.TRANSPARENT, time_to_disappear).from(Color.WHITE)
		var notification_material : ShaderMaterial = achievement_notification.get_material()
		_ignore_property_tweener = _m_disappear_notifications_tween.tween_property(notification_material, ^"shader_parameter/offset", Vector2(0, -20), time_to_disappear).from(Vector2(0, 0))

	# Animation finished -- remove the nodes and clean the memory
	_m_disappear_notifications_tween = _m_disappear_notifications_tween.set_parallel(false)
	_ignore_callback_tweener = _m_disappear_notifications_tween.tween_callback(__pop_achievements)


func __tag_nodes_being_animated() -> void:
	for achievement_notification : Button in _m_current_notifications_showing:
		achievement_notification.set_meta(&"animation_started", true)


func __pop_achievements() -> void:
	for achievement_notification : Button in _m_current_notifications_showing:
		achievement_notification.queue_free()
	_m_current_notifications_showing.clear()
