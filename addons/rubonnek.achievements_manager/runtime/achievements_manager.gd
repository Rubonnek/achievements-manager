#============================================================================
#  achievements_manager.gd                                                  |
#============================================================================
#                         This file is part of:                             |
#                       ACHIEVEMENTS MANAGER                                |
#============================================================================
# Copyright (c) 2025 Wilson Enrique Alvarez Torres                          |
#                                                                           |
# Permission is hereby granted, free of charge, to any person obtaining     |
# a copy of this software and associated documentation files (the           |
# "Software"), to deal in the Software without restriction, including       |
# without limitation the rights to use, copy, modify, merge, publish,       |
# distribute, sublicense, and/or sell copies of the Software, and to        |
# permit persons to whom the Software is furnished to do so, subject to     |
# the following conditions:                                                 |
#                                                                           |
# The above copyright notice and this permission notice shall be            |
# included in all copies or substantial portions of the Software.           |
#                                                                           |
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,           |
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF        |
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.    |
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY      |
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,      |
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE         |
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                    |
#============================================================================
extends RefCounted

class_name AchievementsManager
## Manager for tracking and managing player achievements.
##
## This class provides a centralized system for registering, tracking, and unlocking achievements
## in your game. Achievement data is stored efficiently as an array of dictionaries, with each
## achievement identified by a unique integer ID (its array index).[br]
## [br]
## The manager internally manages an array of dictionaries each of which can be accessed as an [AchievementEntry].
## Achievement entries are cached and emit their own signals when state changes occur.[br]
## [br]
## [b]Key Features:[/b][br]
## * Progress-based achievements using metadata for customizable tracking[br]
## * Hidden achievements that remain concealed until unlocked[br]
## * String IDs for integration with external platforms (Steam, Epic Games, etc.)[br]
## * Custom metadata support for extended achievement properties[br]
## * Achievement entries emit signals for unlock and progress update events[br]
## * Both low-level optimized accessors and high-level [AchievementEntry] wrapper objects[br]
## [br]
## [b]Basic Usage:[/b][br]
## [codeblock]
## var manager = AchievementsManager.new()
##
## # Register an achievement with metadata for progress tracking
## var metadata = {"target": 1, "progress": 0}
## var entry = manager.add_achievement(
##     "First Steps",
##     "Complete the tutorial",
##     "",     # string_id
##     false,  # not hidden
##     null,   # icon
##     metadata
## )
##
## # Listen to signals
## entry.achievement_unlocked.connect(func(achievement): print("Unlocked!"))
##
## # Track progress using metadata
## var current = entry.get_metadata("progress", 0)
## entry.set_metadata("progress", current + 1)
## if entry.get_metadata("progress", 0) >= entry.get_metadata("target", 1):
##     entry.unlock()
## [/codeblock]
## [br]

# Internal storage for all achievement data including runtime state.[br]
# Array of dictionaries containing field values indexed by [AchievementEntry._key] enum.[br]
# The achievement ID is the index in this array.[br]
# Each achievement dictionary contains: [code]NAME[/code], [code]DESCRIPTION[/code],
# [code]HIDDEN[/code], [code]UNLOCKED[/code], [code]STRING_ID[/code], [code]ICON[/code], [code]METADATA[/code].[br]
# Progress and target values should be stored in [code]METADATA[/code] if needed.
var _achievements: Array[Dictionary] = []

# Cached achievement entries for efficient access and signal management.
var _achievement_entries: Array[AchievementEntry] = []


func _init() -> void:
	if EngineDebugger.is_active():
		# Register with the debugger
		var current_script: Resource = get_script()
		var path: String = current_script.get_path()
		var name: String = get_name()
		EngineDebugger.send_message("achievements_manager:register_manager", [get_instance_id(), name, path])


# Validates that an achievement ID is within bounds.[br]
# [br]
# [param p_id]: The unique ID of the achievement (array index).[br]
# [br]
# [b]Returns:[/b] [code]true[/code] if the ID is valid, [code]false[/code] otherwise.
func __is_valid_id(p_id: int) -> bool:
	return p_id >= 0 and p_id < _achievements.size()


## Adds a new achievement to the manager.[br]
## [br]
## The achievement ID is automatically assigned as the next available index in the array.
## Use progress_max for progress tracking or metadata for custom properties.[br]
## [br]
## [param p_name]: Display name (optional)[br]
## [param p_description]: Description text (optional)[br]
## [param p_string_id]: String identifier for external achievement systems (optional)[br]
## [param p_progress_max]: Maximum progress value for the achievement (optional, default: 0)[br]
## [param p_hidden]: Whether to hide until unlocked (default: false)[br]
## [param p_icon]: Icon texture for the achievement (optional)[br]
## [param p_metadata]: Additional metadata dictionary (optional)[br]
## [br]
## [b]Returns:[/b] The AchievementEntry for the newly added achievement.
func add_achievement(p_name: String = "", p_description: String = "", p_string_id: String = "", p_progress_max: int = 1, p_hidden: bool = false, p_icon: Texture2D = null, p_metadata: Dictionary = { }) -> AchievementEntry:
	assert(p_progress_max >= 1, "AchievementsManager: the achievement's max progress should be one or greater.")

	# Only store non-default values to reduce memory usage
	var achievement_data: Dictionary = { }

	if not p_name.is_empty():
		achievement_data[AchievementEntry._key.NAME] = p_name
	if not p_description.is_empty():
		achievement_data[AchievementEntry._key.DESCRIPTION] = p_description
	if p_hidden:
		achievement_data[AchievementEntry._key.HIDDEN] = p_hidden
	if not p_string_id.is_empty():
		achievement_data[AchievementEntry._key.STRING_ID] = p_string_id
	if p_icon != null:
		achievement_data[AchievementEntry._key.ICON] = p_icon
	if p_progress_max != 1:
		achievement_data[AchievementEntry._key.PROGRESS_MAX] = p_progress_max
	if not p_metadata.is_empty():
		achievement_data[AchievementEntry._key.METADATA] = p_metadata

	var achievement_id: int = _achievements.size()
	_achievements.append(achievement_data)

	# Create and cache the achievement entry
	var achievement_entry: AchievementEntry = AchievementEntry.new(achievement_id, achievement_data, self)
	_achievement_entries.push_back(achievement_entry)

	# Send to debugger viewer
	achievement_entry.__send_entry_to_manager_viewer()

	return achievement_entry


## Unlocks an achievement.[br]
## [br]
## If the achievement is already unlocked, this method does nothing.
## Signals are emitted by the [AchievementEntry] itself.[br]
## [br]
## [param p_id]: The unique ID of the achievement to unlock.
func unlock_achievement(p_id: int) -> void:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return

	var achievement_entry: AchievementEntry = get_achievement_entry(p_id)
	achievement_entry.unlock()


## Checks if an achievement is unlocked.[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [br]
## [b]Returns:[/b] [code]true[/code] if the achievement is unlocked, [code]false[/code] otherwise.
func is_achievement_unlocked(p_id: int) -> bool:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return false

	var achievement: Dictionary = _achievements[p_id]
	var is_unlocked: bool = achievement.get(AchievementEntry._key.UNLOCKED, false)
	return is_unlocked


## Gets the name of an achievement (optimized accessor).[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [br]
## [b]Returns:[/b] The achievement name, or empty string if not found.
func get_achievement_name(p_id: int) -> String:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return ""

	var achievement: Dictionary = _achievements[p_id]
	var name: String = achievement.get(AchievementEntry._key.NAME, "")
	return name


## Gets the description of an achievement (optimized accessor).[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [br]
## [b]Returns:[/b] The achievement description, or empty string if not found.
func get_achievement_description(p_id: int) -> String:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return ""

	var achievement: Dictionary = _achievements[p_id]
	var description: String = achievement.get(AchievementEntry._key.DESCRIPTION, "")
	return description


## Checks if an achievement is hidden (optimized accessor).[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [br]
## [b]Returns:[/b] [code]true[/code] if the achievement is hidden, [code]false[/code] otherwise.
func is_achievement_hidden(p_id: int) -> bool:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return false

	var achievement: Dictionary = _achievements[p_id]
	var is_hidden: bool = achievement.get(AchievementEntry._key.HIDDEN, false)
	return is_hidden


## Gets the string identifier of an achievement (optimized accessor).[br]
## [br]
## Used for interfacing with external achievement systems (e.g., Steam, Epic Games).[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [br]
## [b]Returns:[/b] The achievement string ID, or empty string if not found.
func get_achievement_string_id(p_id: int) -> String:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return ""

	var achievement: Dictionary = _achievements[p_id]
	var string_id: String = achievement.get(AchievementEntry._key.STRING_ID, "")
	return string_id


## Gets the icon of an achievement (optimized accessor).[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [br]
## [b]Returns:[/b] The achievement icon texture, or [code]null[/code] if not found or not set.
func get_achievement_icon(p_id: int) -> Texture2D:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return null

	var achievement: Dictionary = _achievements[p_id]
	var icon: Texture2D = achievement.get(AchievementEntry._key.ICON, null)
	return icon


## Gets the metadata dictionary of an achievement (optimized accessor).[br]
## [br]
## Metadata can store arbitrary key-value pairs for custom achievement data.[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [br]
## [b]Returns:[/b] The achievement metadata dictionary, or empty dictionary if not found.
func get_achievement_metadata(p_id: int) -> Dictionary:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return { }

	var achievement: Dictionary = _achievements[p_id]
	var metadata: Dictionary = achievement.get(AchievementEntry._key.METADATA, { })
	return metadata


## Sets the progress for an achievement.[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [param p_current]: The current progress value.[br]
func set_achievement_progress(p_id: int, p_current: int, p_max: int) -> void:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return
	var achievement_entry: AchievementEntry = get_achievement_entry(p_id)
	achievement_entry.set_progress(p_current, p_max)


## Sets the current progress for an achievement.[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
func set_achievement_progress_current(p_id: int, p_current: int) -> void:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return
	var achievement_entry: AchievementEntry = get_achievement_entry(p_id)
	achievement_entry.set_progress_current(p_current)


## Sets the max progress for an achievement.[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
func set_achievement_progress_max(p_id: int, p_max: int) -> void:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return
	var achievement_entry: AchievementEntry = get_achievement_entry(p_id)
	achievement_entry.set_progress_max(p_max)


## Adds the specified amount to the progress of an achievement.[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [param p_amount]: The amount to add to the progress.
func add_achievement_progress(p_id: int, p_amount: int) -> void:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return
	var achievement_entry: AchievementEntry = get_achievement_entry(p_id)
	achievement_entry.add_progress(p_amount)


## Gets an achievement as an [AchievementEntry] object.[br]
## [br]
## This returns a cached [AchievementEntry] instance that wraps the internal dictionary reference.[br]
## [br]
## [param p_id]: The unique ID of the achievement.[br]
## [br]
## [b]Returns:[/b] [AchievementEntry] instance, or [code]null[/code] if not found.
func get_achievement_entry(p_id: int) -> AchievementEntry:
	if not (p_id < _achievements.size() && p_id >= 0):
		push_error("AchievementsManager: achievement entry with id '%d' does not exist." % p_id)
		return null
	return _achievement_entries[p_id]


## Returns true if an achievement ID is present.
func has_achievement(p_id: int) -> bool:
	return p_id < _achievements.size()


## Gets all achievements as an array of [AchievementEntry] objects.[br]
## [br]
## [b]Returns:[/b] Array containing all registered achievements as [AchievementEntry] instances.
func get_all_achievement_entries() -> Array[AchievementEntry]:
	return _achievement_entries.duplicate()


## Gets all achievement IDs.[br]
## [br]
## [b]Returns:[/b] Array of all registered achievement IDs (array indices).
func get_all_achievement_ids() -> Array[int]:
	return Array(range(_achievements.size()), TYPE_INT, "", null)


## Gets the number of unlocked achievements.[br]
## [br]
## [b]Returns:[/b] Count of unlocked achievements.
func get_unlocked_count() -> int:
	var count: int = 0
	for achievement: Dictionary in _achievements:
		var is_unlocked: bool = achievement.get(AchievementEntry._key.UNLOCKED, false)
		if is_unlocked:
			count += 1
	return count


## Gets the total number of registered achievements.[br]
## [br]
## [b]Returns:[/b] Total count of achievements.
func get_total_count() -> int:
	return _achievements.size()


## Returns the number of achievement entries.
func size() -> int:
	return _achievements.size()


## Returns a number between 0 and 1 representing the percent of overall unlocked achievements.[br]
## [br]
## [b]Returns:[/b] Progress value from 0.0 to 1.0.
func get_progress() -> float:
	if _achievements.is_empty():
		return 1.0
	var unlocked: int = get_unlocked_count()
	var total: int = get_total_count()
	return float(unlocked) / float(total)


## Resets all achievements to their initial locked state with zero progress.[br]
## [br]
## This does not unregister achievements, only resets their unlock status, progress, and clears their metadata.
func reset() -> void:
	for achievement: Dictionary in _achievements:
		var _success: bool = achievement.erase(AchievementEntry._key.UNLOCKED)
		_success = achievement.erase(AchievementEntry._key.METADATA)
		_success = achievement.erase(AchievementEntry._key.PROGRESS_CURRENT)

	# Sync all entries with debugger
	for achievement_entry: AchievementEntry in _achievement_entries:
		achievement_entry.__send_entry_to_manager_viewer()


## Resets a specific achievement to its initial locked state with zero progress.[br]
## [br]
## This does not unregister the achievement, only resets its unlock status, progress, and clears its metadata.[br]
## [br]
## [param p_id]: The unique ID of the achievement to reset.
func reset_achievement(p_id: int) -> void:
	if not __is_valid_id(p_id):
		push_error("AchievementsManager: Achievement not registered: " + str(p_id))
		return

	var achievement: Dictionary = _achievements[p_id]
	var _success: bool = achievement.erase(AchievementEntry._key.UNLOCKED)
	_success = achievement.erase(AchievementEntry._key.METADATA)
	_success = achievement.erase(AchievementEntry._key.PROGRESS_CURRENT)

	# Sync with debugger
	var achievement_entry: AchievementEntry = get_achievement_entry(p_id)
	achievement_entry.__send_entry_to_manager_viewer()


## Returns a reference to the internal data.[br]
## [br]
## [color=yellow]Warning:[/color] Modifying this dictionary will modify the underlying data that achievements manager handles.
func get_data() -> Array[Dictionary]:
	return _achievements


## Overwrites the achievements manager data.[br]
## [br]
## This rebuilds the internal cache of achievement entries.[br]
## [br]
## [param p_data]: Array of achievement dictionaries to load. Expects the data from [method get_data].
func set_data(p_data: Array[Dictionary]) -> void:
	_achievements = p_data
	var _new_size: int = _achievement_entries.resize(_achievements.size())

	for achievement_id: int in p_data.size():
		var achievement_data: Dictionary = p_data[achievement_id]
		var achievement_entry: AchievementEntry = AchievementEntry.new(achievement_id, achievement_data, self)
		_achievement_entries[achievement_id] = achievement_entry

	if EngineDebugger.is_active():
		if not has_meta(&"deregistered"):
			EngineDebugger.send_message("achievements_manager:set_data", [get_instance_id(), p_data])


## Sets the string IDs for achievements based on the keys of an enum dictionary.[br]
## [br]
## The string IDs for each achievement will be the enum keys in snake_case format.[br]
## [br]
## [param p_enum]: Dictionary mapping string IDs to achievement IDs.
func set_string_ids_using_enum(p_enum: Dictionary) -> void:
	for string_id: String in p_enum:
		var snake_case_string_id: String = string_id.to_snake_case()
		var id: int = p_enum[string_id]
		if not __is_valid_id(id):
			push_error("AchievementsManager: Invalid achievement ID in enum: " + str(id))
			continue
		_achievements[id][AchievementEntry._key.STRING_ID] = snake_case_string_id


## Returns a duplicated achievements array with internal keys replaced with strings for easier reading/debugging.
## [br]
## [b]Example[/b]:
## [codeblock]
## var achievements_manager : AchievementsManager = AchievementsManager.new()
## achievements_manager.add_achievement("First Achievement", "Complete the tutorial", "", true)
## print(JSON.stringify(achievements_manager.prettify(), "\t"))
## [/codeblock]
func prettify() -> Array[Dictionary]:
	var prettified_data: Array[Dictionary] = []

	for achievement_id: int in _achievements.size():
		var achievement: Dictionary = _achievements[achievement_id]
		var prettified_entry: Dictionary = { }

		prettified_entry["id"] = achievement_id

		if achievement.has(AchievementEntry._key.NAME):
			prettified_entry["name"] = achievement[AchievementEntry._key.NAME]
		if achievement.has(AchievementEntry._key.DESCRIPTION):
			prettified_entry["description"] = achievement[AchievementEntry._key.DESCRIPTION]
		if achievement.has(AchievementEntry._key.HIDDEN):
			prettified_entry["hidden"] = achievement[AchievementEntry._key.HIDDEN]
		if achievement.has(AchievementEntry._key.UNLOCKED):
			prettified_entry["unlocked"] = achievement[AchievementEntry._key.UNLOCKED]
		if achievement.has(AchievementEntry._key.STRING_ID):
			prettified_entry["string_id"] = achievement[AchievementEntry._key.STRING_ID]
		if achievement.has(AchievementEntry._key.ICON):
			prettified_entry["icon"] = str(achievement[AchievementEntry._key.ICON])
		if achievement.has(AchievementEntry._key.PROGRESS_CURRENT):
			prettified_entry["progress_current"] = achievement[AchievementEntry._key.PROGRESS_CURRENT]
		if achievement.has(AchievementEntry._key.PROGRESS_MAX):
			prettified_entry["progress_max"] = achievement[AchievementEntry._key.PROGRESS_MAX]
		if achievement.has(AchievementEntry._key.METADATA):
			prettified_entry["metadata"] = achievement[AchievementEntry._key.METADATA]

		prettified_data.push_back(prettified_entry)

	return prettified_data


## Sets a name to the manager in debug builds only. The manager name is only used for display by the achievements manager viewer in the debugger.
func set_name(p_name: String) -> void:
	if OS.is_debug_build():
		set_meta(&"name", p_name)
	if EngineDebugger.is_active():
		if not has_meta(&"deregistered"):
			EngineDebugger.send_message("achievements_manager:set_name", [get_instance_id(), p_name])


## Gets the name of the manager. Returns an empty string in release builds. The manager name is only used for display by the achievements manager viewer in the debugger.
func get_name() -> String:
	return get_meta(&"name", "")


## Deregisters the achievements manager from the debugger.
func deregister() -> void:
	if EngineDebugger.is_active():
		set_meta(&"deregistered", true)
		EngineDebugger.send_message("achievements_manager:deregister_manager", [get_instance_id()])


# Injects an achievement dictionary given an achievement ID. This is used in the debugger to synchronize AchievementEntries.
func __inject(p_achievement_id: int, p_achievement_dictionary: Dictionary) -> void:
	if _achievements.size() <= p_achievement_id:
		if _achievements.resize(p_achievement_id + 1) != OK:
			push_warning("AchievementsManager: Unable to inject achievement data array! The array won't be visualized properly.")
			return
		if _achievement_entries.resize(p_achievement_id + 1) != OK:
			push_warning("AchievementsManager: Unable to inject achievement entries array! The array won't be visualized properly.")
			return
	_achievements[p_achievement_id] = p_achievement_dictionary
	var achievement_entry: AchievementEntry = AchievementEntry.new(p_achievement_id, p_achievement_dictionary, self)
	_achievement_entries[p_achievement_id] = achievement_entry


func _to_string() -> String:
	return "<AchievementsManager#%d>" % get_instance_id()

# ==== ITERATOR ====
# Iterates over all achievement entries
var _m_iter_needle: int = 0


func _iter_init(_p_args: Array) -> bool:
	_m_iter_needle = 0
	return _m_iter_needle < _achievement_entries.size()


func _iter_next(_p_args: Array) -> bool:
	_m_iter_needle += 1
	return _m_iter_needle < _achievement_entries.size()


func _iter_get(_p_args: Variant) -> AchievementEntry:
	return _achievement_entries[_m_iter_needle]
# ==== ITERATOR ====
