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
		1,
		false,
		null,
		{}
	)

	var second_steps_entry : AchievementEntry = achievements_manager.add_achievement(
		"Second Steps",
		"Complete your second action",
		"second_steps",
		1,
		false,
		null,
		{}
	)

	var explorer_entry : AchievementEntry = achievements_manager.add_achievement(
		"Explorer",
		"Discover 10 locations",
		"explorer",
		10,
		false,
		null,
		{}
	)

	var hidden_treasure_entry : AchievementEntry = achievements_manager.add_achievement(
		"Hidden Treasure",
		"Find the secret treasure",
		"hidden_treasure",
		1,
		true,
		null,
		{}
	)

	var collector_entry : AchievementEntry = achievements_manager.add_achievement(
		"Collector",
		"Collect 100 items",
		"collector",
		100,
		false,
		null,
		{}
	)

	# Connect signals from each achievement entry
	for entry : AchievementEntry in achievements_manager:
		entry.achievement_unlocked.connect(achievements_notification_ui.on_achievement_unlocked)

	print("Achievement Test: Press SPACE to add progress, ENTER to unlock all")
	print("Registered %d achievements. Open the debugger to view them!" % achievements_manager.size())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event : InputEventKey = event
		if key_event.pressed and key_event.keycode == KEY_SPACE:
			# Add progress to achievements
			for entry : AchievementEntry in achievements_manager:
				if not entry.is_unlocked():
					entry.add_progress(1)

					var current_progress: int = entry.get_progress_current()
					var target: int = entry.get_progress_max()

					var message : String = "Progress for '%s': %d/%d" % [entry.get_name(), current_progress, target]
					print(message)
					demo_notification_label.set_text(message)

					if entry.is_progress_complete():
						entry.unlock()

					break
		elif key_event.pressed and key_event.keycode == KEY_ENTER:
			# Unlock all achievements
			demo_notification_label.set_text("")
			for entry : AchievementEntry in achievements_manager:
				if not entry.is_unlocked():
					entry.unlock()
					var message : String = "Unlocked achievement: %s" % entry.get_name()
					print(message)
					demo_notification_label.set_text(demo_notification_label.get_text() + "\n" + message)
