extends Node

@export var notification_label : Label

var manager := AchievementsManager.new()

func _ready() -> void:
	# Add a simple achievement (target = 1)
	var entry : AchievementEntry = manager.add_achievement(
		"First Blood",
		"Defeat your first enemy"
	)

	# Connect to its signal
	entry.achievement_unlocked.connect(_on_achievement_unlocked)

	print("Press SPACE to unlock the achievement")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		# Unlock the achievement directly from the entry
		var entry := manager.get_achievement_entry(0)
		entry.unlock()

func _on_achievement_unlocked(achievement: AchievementEntry) -> void:
	print("🏆 Achievement Unlocked: ", achievement.get_name())
	print("   ", achievement.get_description())
	notification_label.set_text("🏆 Achievement Unlocked: " + achievement.get_name() + "\n\nDemo complete!")
