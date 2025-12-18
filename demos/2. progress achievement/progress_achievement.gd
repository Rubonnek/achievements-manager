extends Node

@export var notification_label : Label

var manager := AchievementsManager.new()

func _ready() -> void:
	# Add a progress achievement with metadata for tracking
	var metadata := {"target": 10, "progress": 0}
	var entry : AchievementEntry = manager.add_achievement(
		"Skilled Hunter",
		"Defeat 10 enemies",
		"",
		false,
		null,
		metadata
	)

	# Connect to its signals
	entry.achievement_updated.connect(__on_achievement_updated)
	entry.achievement_unlocked.connect(_on_achievement_unlocked)

	var target: int = entry.get_metadata("target", 1)
	print("Press SPACE to add progress (current: 0/%d)" % target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		# Update progress manually using metadata
		var entry := manager.get_achievement_entry(0)
		if not entry.is_unlocked():
			var current_progress: int = entry.get_metadata("progress", 0)
			var target: int = entry.get_metadata("target", 1)
			var new_progress: int = mini(current_progress + 1, target)
			entry.set_metadata("progress", new_progress)

			# Emit progress updated signal manually
			entry.set_updated()

			# Check if we should unlock
			if new_progress >= target:
				entry.unlock()

func __on_achievement_updated(achievement: AchievementEntry) -> void:
	var progress: int = achievement.get_metadata("progress", 0)
	var target: int = achievement.get_metadata("target", 1)
	print("Progress: %d/%d" % [progress, target])
	notification_label.set_text("Progress: %d/%d" % [progress, target])

func _on_achievement_unlocked(achievement: AchievementEntry) -> void:
	print("🏆 Achievement Unlocked: ", achievement.get_name())
	print("   ", achievement.get_description())
	notification_label.set_text("🏆 Achievement Unlocked: " + achievement.get_name() + "\n\nDemo complete!")
