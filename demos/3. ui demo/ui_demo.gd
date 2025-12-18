extends Node

@export var demo_notification_label : Label
@export var achievements_notification_ui : AchievementsNotificationsUIDemo

var achievements_manager : AchievementsManager = AchievementsManager.new()

func _ready() -> void:
	# Set a name for the manager so it appears in the debugger viewer
	achievements_manager.set_name("Test Achievement Manager")

	# Add some test achievements
	var first_steps_entry : AchievementEntry = achievements_manager.add_achievement(
		"First Steps",
		"Complete your first action",
		"first_steps",
		false,
		null,
		{"target": 1, "progress": 0}
	)

	var second_steps_entry : AchievementEntry = achievements_manager.add_achievement(
		"Second Steps",
		"Complete your second action",
		"second_steps",
		false,
		null,
		{"target": 1, "progress": 0}
	)

	var explorer_entry : AchievementEntry = achievements_manager.add_achievement(
		"Explorer",
		"Discover 10 locations",
		"explorer",
		false,
		null,
		{"target": 10, "progress": 0}
	)

	var hidden_treasure_entry : AchievementEntry = achievements_manager.add_achievement(
		"Hidden Treasure",
		"Find the secret treasure",
		"hidden_treasure",
		true,
		null,
		{"target": 1, "progress": 0}
	)

	var collector_entry : AchievementEntry = achievements_manager.add_achievement(
		"Collector",
		"Collect 100 items",
		"collector",
		false,
		null,
		{"target": 100, "progress": 0}
	)

	# Connect signals from each achievement entry
	for entry : AchievementEntry in achievements_manager:
		entry.achievement_unlocked.connect(achievements_notification_ui.on_achievement_unlocked)

	print("Achievement Test: Press ENTER to add progress, SPACE to unlock all")
	print("Registered %d achievements. Open the debugger to view them!" % achievements_manager.size())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event : InputEventKey = event
		if key_event.pressed and key_event.keycode == KEY_ENTER:
			# Add progress to achievements
			for entry : AchievementEntry in achievements_manager:
				if not entry.is_unlocked():
					var current_progress: int = entry.get_metadata("progress", 0)
					var target: int = entry.get_metadata("target", 1)
					var new_progress: int = mini(current_progress + 1, target)
					entry.set_metadata("progress", new_progress)

					# Set the quest as updated -- this will emit its achievement_updated signal
					entry.set_updated()

					var message : String = "Progress for '%s': %d/%d" % [entry.get_name(), new_progress, target]
					print(message)
					demo_notification_label.set_text(message)

					# Check if we should unlock
					if new_progress >= target:
						entry.unlock()
					break

		elif key_event.pressed and key_event.keycode == KEY_SPACE:
			# Unlock all achievements
			demo_notification_label.set_text("")
			for entry : AchievementEntry in achievements_manager:
				if not entry.is_unlocked():
					entry.unlock()
					var message : String = "Unlocked achievement: %s" % entry.get_name()
					print(message)
					demo_notification_label.set_text(demo_notification_label.get_text() + "\n" + message)
