extends Node

@export var notification_label: Label

var manager := AchievementsManager.new()


func _ready() -> void:
	# Add a progress achievement
	var entry: AchievementEntry = manager.add_achievement(
		"Skilled Hunter",
		"Defeat 10 enemies",
		"",
		10,
		false,
		null,
		{ },
	)

	# Connect to its signals
	entry.achievement_updated.connect(__on_achievement_updated)
	entry.achievement_unlocked.connect(__on_achievement_unlocked)

	var target: int = entry.get_progress_max()
	print("Press SPACE to add progress (current: 0/%d)" % target)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		# Update progress using the new progress API
		var entry := manager.get_achievement_entry(0)
		if not entry.is_unlocked():
			entry.add_progress(1)

			# Must emit the updated signal manually
			entry.set_updated()


func __on_achievement_updated(p_achievement: AchievementEntry) -> void:
	var progress: int = p_achievement.get_progress_current()
	var target: int = p_achievement.get_progress_max()
	print("Progress: %d/%d" % [progress, target])
	notification_label.set_text("Progress: %d/%d" % [progress, target])
	if p_achievement.is_progress_complete():
		p_achievement.unlock()


func __on_achievement_unlocked(p_achievement: AchievementEntry) -> void:
	print("🏆 Achievement Unlocked: ", p_achievement.get_name())
	print("   ", p_achievement.get_description())
	notification_label.set_text("🏆 Achievement Unlocked: " + p_achievement.get_name() + "\n\nDemo complete!")
