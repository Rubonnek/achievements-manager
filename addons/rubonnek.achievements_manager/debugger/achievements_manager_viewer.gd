#============================================================================
#  achievements_manager_viewer.gd                                           |
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

@tool
extends PanelContainer

@export var achievements_manager_viewer_manager_selection_line_edit_ : LineEdit
@export var achievements_manager_viewer_manager_selection_tree_ : Tree
@export var achievements_manager_viewer_achievement_entries_tree_ : Tree
@export var achievements_manager_viewer_achievement_entries_view_warning_label_ : Label
@export var achievements_manager_viewer_achievement_data_view_text_edit_ : TextEdit
@export var achievements_manager_viewer_achievement_data_view_warning_label_ : Label
@export var achievements_manager_viewer_achievement_metadata_view_text_edit_ : TextEdit
@export var achievements_manager_viewer_achievement_metadata_view_warning_label_ : Label

var _m_original_achievement_entry_view_warning_text : String
var _m_original_achievement_data_view_warning_text : String
var _m_original_achievement_metadata_view_warning_text : String

var _m_remote_achievements_manager_id_to_tree_item_map_cache : Dictionary
var _m_achievement_id_to_tree_item_map_cache : Array[TreeItem]

func _ready() -> void:
	# Connect AchievementsManager tree signals
	var _success : int = achievements_manager_viewer_manager_selection_tree_.item_selected.connect(__on_achievements_manager_selection_tree_item_selected)
	_success = achievements_manager_viewer_manager_selection_tree_.nothing_selected.connect(__on_achievements_manager_selection_tree_nothing_selected)

	# Connect AchievementEntry tree signals
	_success = achievements_manager_viewer_achievement_entries_tree_.item_selected.connect(__on_achievement_view_selection_item_selected)
	_success = achievements_manager_viewer_achievement_entries_tree_.nothing_selected.connect(__on_achievement_view_selection_nothing_selected)

	# Connect line edit for filtering the AchievementsManagers list
	_success = achievements_manager_viewer_manager_selection_line_edit_.text_changed.connect(__on_achievements_manager_selection_line_edit_text_changed)

	# Grab the original metadata warning text -- we'll need this to restore their state once the debugger session is stopped
	_m_original_achievement_entry_view_warning_text = achievements_manager_viewer_achievement_entries_view_warning_label_.get_text()
	_m_original_achievement_data_view_warning_text = achievements_manager_viewer_achievement_data_view_warning_label_.get_text()
	_m_original_achievement_metadata_view_warning_text = achievements_manager_viewer_achievement_metadata_view_warning_label_.get_text()


# ==== EDITOR DEBUGGER PLUGIN PASSTHROUGH FUNCTIONS BEGIN ======
func on_editor_debugger_plugin_capture(p_message : String, p_data : Array) -> bool:
	var column : int = 0
	match p_message:
		"achievements_manager:register_manager":
			var achievements_manager_id : int = p_data[0]
			var achievements_manager_name : String = p_data[1]
			var achievements_manager_path : String = p_data[2]

			# Generate name
			var target_name : String
			if not achievements_manager_name.is_empty():
				target_name = achievements_manager_name
			else:
				if not achievements_manager_path.is_empty():
					target_name = achievements_manager_path.trim_prefix(achievements_manager_path.get_base_dir().path_join("/"))
				else:
					target_name = "Manager"
			target_name = target_name + ":" + String.num_uint64(achievements_manager_id)

			# Create the associated tree_item and add it as metadata against the tree itself so that we can extract it easily when we receive messages from this specific AchievementsManager instance id
			var achievements_manager_tree_item : TreeItem = achievements_manager_viewer_manager_selection_tree_.create_item()
			achievements_manager_tree_item.set_text(column, target_name)
			_m_remote_achievements_manager_id_to_tree_item_map_cache[achievements_manager_id] = achievements_manager_tree_item

			# Store a local AchievementsManager as metadata -- reuse one if provided.
			var achievements_manager : AchievementsManager = AchievementsManager.new()
			achievements_manager_tree_item.set_metadata(column, achievements_manager)
			return true

		"achievements_manager:set_name":
			var achievements_manager_id : int = p_data[0]
			var achievements_manager_tree_item : TreeItem = _m_remote_achievements_manager_id_to_tree_item_map_cache[achievements_manager_id]
			var remote_name : String = p_data[1]
			achievements_manager_tree_item.set_text(column, remote_name)
			return true

		"achievements_manager:set_data":
			var achievements_manager_id : int = p_data[0]
			var achievements_manager_tree_item : TreeItem = _m_remote_achievements_manager_id_to_tree_item_map_cache[achievements_manager_id]
			var stored_achievements_manager : AchievementsManager = achievements_manager_tree_item.get_metadata(column)
			var p_array : Array = p_data[1]
			var p_manager_data : Array[Dictionary] = Array(p_array, TYPE_DICTIONARY, "", null)
			stored_achievements_manager.set_data(p_manager_data)

			# Refresh the achievement entries if needed:
			__refresh_achievement_entries_if_needed(stored_achievements_manager)
			return true

		"achievements_manager:sync_entry":
			var achievements_manager_id : int = p_data[0]
			var achievements_manager_tree_item : TreeItem = _m_remote_achievements_manager_id_to_tree_item_map_cache[achievements_manager_id]
			var stored_achievements_manager : AchievementsManager = achievements_manager_tree_item.get_metadata(column)

			# Inject the remote achievement entry data:
			var remote_achievement_entry_id : int = p_data[1]
			var remote_achievement_entry_data : Dictionary = p_data[2]

			# Convert the image bytes back into the image object:
			if remote_achievement_entry_data.has(AchievementEntry._key.ICON):
				var bytes : PackedByteArray = remote_achievement_entry_data[AchievementEntry._key.ICON]
				var image : Image = bytes_to_var_with_objects(bytes)
				image.resize(16,16)
				var texture : ImageTexture = ImageTexture.create_from_image(image)
				remote_achievement_entry_data[AchievementEntry._key.ICON] = texture

			stored_achievements_manager.__inject(remote_achievement_entry_id, remote_achievement_entry_data)

			# Refresh the achievement entries if needed:
			__refresh_achievement_entries_if_needed(stored_achievements_manager)
			return true

		"achievements_manager:deregister_manager":
			var achievements_manager_id : int = p_data[0]
			if _m_remote_achievements_manager_id_to_tree_item_map_cache.has(achievements_manager_id):
				var achievements_manager_tree_item : TreeItem = _m_remote_achievements_manager_id_to_tree_item_map_cache[achievements_manager_id]
				var selected_tree_item : TreeItem = achievements_manager_viewer_manager_selection_tree_.get_selected()
				if is_instance_valid(selected_tree_item):
					if achievements_manager_tree_item == selected_tree_item:
						__on_achievements_manager_selection_tree_nothing_selected()
				var _success : bool = _m_remote_achievements_manager_id_to_tree_item_map_cache.erase(achievements_manager_id)
				achievements_manager_tree_item.free()
			else:
				push_warning("ArchiveManagerViewer: Could not find achievements manager with instance id '%d' to deregister it." % achievements_manager_id )
			return true

	push_warning("AchievementsManagerViewer: This should not happen. Unmanaged capture: %s %s" % [p_message, p_data])
	return false
# ==== EDITOR DEBUGGER PLUGIN PASSTHROUGH FUNCTIONS ENDS ======


# ===== VISUALIZATION FUNCTIONS BEGIN ====
func __on_session_started() -> void:
	# Clear all the caches
	_m_remote_achievements_manager_id_to_tree_item_map_cache.clear()
	_m_achievement_id_to_tree_item_map_cache.clear()

	# Clear the achievements manager tree
	achievements_manager_viewer_manager_selection_tree_.clear()
	var _root : TreeItem = achievements_manager_viewer_manager_selection_tree_.create_item() # need to recreate the root TreeItem which gets ignored

	# Clear the achievement entry tree view
	achievements_manager_viewer_achievement_entries_tree_.clear()
	achievements_manager_viewer_achievement_entries_view_warning_label_.set_text("Select an AchievementsManager to display its achievement entries.")
	achievements_manager_viewer_achievement_entries_view_warning_label_.show()

	# Clear the data view
	achievements_manager_viewer_achievement_data_view_text_edit_.set_text("")
	achievements_manager_viewer_achievement_data_view_warning_label_.set_text("Select an AchievementEntry to display its data.")
	achievements_manager_viewer_achievement_data_view_warning_label_.show()

	# Clear the metadata view
	achievements_manager_viewer_achievement_metadata_view_text_edit_.set_text("")
	achievements_manager_viewer_achievement_metadata_view_warning_label_.set_text("Select an AchievementEntry to display its metadata.")
	achievements_manager_viewer_achievement_metadata_view_warning_label_.show()

func __on_session_stopped() -> void:
	if not is_instance_valid(achievements_manager_viewer_manager_selection_tree_.get_root()) or achievements_manager_viewer_manager_selection_tree_.get_root().get_child_count() == 0:
		achievements_manager_viewer_achievement_entries_view_warning_label_.set_text(_m_original_achievement_entry_view_warning_text)
	if not is_instance_valid(achievements_manager_viewer_achievement_entries_tree_.get_root()) or achievements_manager_viewer_achievement_entries_tree_.get_root().get_child_count() == 0:
		achievements_manager_viewer_achievement_metadata_view_warning_label_.set_text(_m_original_achievement_metadata_view_warning_text)


func __on_achievements_manager_selection_line_edit_text_changed(p_filter : String) -> void:
	# Hide the TreeItem that don't match the filter
	var root : TreeItem = achievements_manager_viewer_manager_selection_tree_.get_root()
	var column : int = 0
	for child : TreeItem in root.get_children():
		if p_filter.is_empty() or p_filter in child.get_text(column):
			child.set_visible(true)
		else:
			child.set_visible(false)

	# Select an item (if any):
	achievements_manager_viewer_manager_selection_tree_.deselect_all()
	var did_select_item : bool = false
	for child : TreeItem in root.get_children():
		if child.is_visible():
			achievements_manager_viewer_manager_selection_tree_.set_selected(child, column) # emits item_selected signal
			child.select(column) # highlights the item on the Tree
			did_select_item = true
			break
	if not did_select_item:
		__on_achievements_manager_selection_tree_nothing_selected()


func __on_achievements_manager_selection_tree_nothing_selected() -> void:
	# Deselect
	achievements_manager_viewer_manager_selection_tree_.deselect_all()

	# Clear the achievement view
	achievements_manager_viewer_achievement_entries_tree_.clear()
	achievements_manager_viewer_achievement_entries_view_warning_label_.set_text("Select an AchievementsManager to display its achievement entries.")
	achievements_manager_viewer_achievement_entries_view_warning_label_.show()

	# Clear the data view
	achievements_manager_viewer_achievement_data_view_text_edit_.set_text("")
	achievements_manager_viewer_achievement_data_view_warning_label_.set_text("Select an AchievementEntry to display its data.")
	achievements_manager_viewer_achievement_data_view_warning_label_.show()

	# Clear the metadata view
	achievements_manager_viewer_achievement_metadata_view_text_edit_.set_text("")
	achievements_manager_viewer_achievement_metadata_view_warning_label_.set_text("Select an AchievementEntry to display its metadata.")
	achievements_manager_viewer_achievement_metadata_view_warning_label_.show()


func __refresh_achievement_entries_if_needed(p_updated_achievements_manager : AchievementsManager) -> void:
	var selected_tree_item : TreeItem = achievements_manager_viewer_manager_selection_tree_.get_selected()
	if is_instance_valid(selected_tree_item):
		var column : int = 0
		var stored_achievements_manager : AchievementsManager = selected_tree_item.get_metadata(column)
		if p_updated_achievements_manager == stored_achievements_manager:
			__refresh_achievement_entries()


func __refresh_achievement_entries() -> void:
	# Populate achievement entries

	# Update achievement view warning label:
	if achievements_manager_viewer_achievement_entries_view_warning_label_.is_visible():
		achievements_manager_viewer_achievement_entries_view_warning_label_.hide()

	# Grab the selected tree item and achievements manager:
	var achievements_manager_selected_tree_item : TreeItem = achievements_manager_viewer_manager_selection_tree_.get_selected()
	var column : int = 0
	var achievements_manager : AchievementsManager = achievements_manager_selected_tree_item.get_metadata(column)

	# Clear the achievement selection tree as well
	var selected_achievement_id : int = -1 # -1 is used as a sentinel value -- achievement IDs begin at 0
	if not _m_achievement_id_to_tree_item_map_cache.is_empty():
		var achievement_entry_selected_tree_item : TreeItem = achievements_manager_viewer_achievement_entries_tree_.get_selected()
		if is_instance_valid(achievement_entry_selected_tree_item):
			selected_achievement_id = _m_achievement_id_to_tree_item_map_cache.find(achievement_entry_selected_tree_item)
	achievements_manager_viewer_achievement_entries_tree_.clear()
	var _root : TreeItem = achievements_manager_viewer_achievement_entries_tree_.create_item()

	# Traverse all the achievements and add them to the tree (achievements are flat, not hierarchical):
	var _new_size : int = _m_achievement_id_to_tree_item_map_cache.resize(achievements_manager.get_total_count())
	for achievement_id : int in achievements_manager.get_total_count():
		var achievement_entry : AchievementEntry = achievements_manager.get_achievement_entry(achievement_id)

		# Create a TreeItem at the root level
		var parent_tree_item : TreeItem = achievements_manager_viewer_achievement_entries_tree_.get_root()
		var achievement_tree_item : TreeItem = achievements_manager_viewer_achievement_entries_tree_.create_item(parent_tree_item)

		# Install the achievement icon:
		var texture : Texture2D = achievement_entry.get_icon()
		print(achievement_entry.get_icon())
		if is_instance_valid(texture):
			achievement_tree_item.set_icon(column, texture)

		# Install the achievement tooltip:
		var achievement_name : String = achievement_entry.get_name()
		if achievement_name.is_empty():
			achievement_name = "(Empty Name)"
		var achievement_description : String = achievement_entry.get_description()
		if achievement_description.is_empty():
			achievement_description = "(Empty Description)"
		achievement_tree_item.set_text(column, achievement_name)
		var tooltip_string : String = "ID: %d\n" % achievement_id
		tooltip_string += "Description: %s\n" % achievement_description
		var achievement_string_id : String = achievement_entry.get_string_id()
		if achievement_string_id.is_empty():
			achievement_string_id = "(Empty Description)"
		tooltip_string += "String ID: %s\n" % achievement_string_id
		tooltip_string += "Hidden: %s\n" % achievement_entry.is_hidden()
		tooltip_string += "Progress: %d/%d\n" % [achievement_entry.get_progress_current(), achievement_entry.get_progress_max()]
		tooltip_string += "Has Metadata: %s\n" % str(achievement_entry.has_metadata())
		tooltip_string += "Unlocked: %s\n" % achievement_entry.is_unlocked()
		achievement_tree_item.set_tooltip_text(column, tooltip_string)

		# Store the achievements manager and achievement ID on its tree item so that we can retrieve its data easily later.
		# We shouldn't store the AchievementEntry directly as metadata because the achievement entry data will get deprecated/detached upon a achievements_manager:sync_entry message
		var achievement_tree_item_metadata : Array = [achievements_manager, achievement_id]
		achievement_tree_item.set_metadata(column, achievement_tree_item_metadata)

		# Also map the achievement id to their tree items
		_m_achievement_id_to_tree_item_map_cache[achievement_id] = achievement_tree_item

	# Restore selection if possible
	if selected_achievement_id >= 0:
		if selected_achievement_id < _m_achievement_id_to_tree_item_map_cache.size() :
			var tree_item_to_select : TreeItem = _m_achievement_id_to_tree_item_map_cache[selected_achievement_id]
			tree_item_to_select.select(column)
		else:
			__on_achievement_view_selection_nothing_selected()


func __on_achievements_manager_selection_tree_item_selected() -> void:
	var selected_tree_item : TreeItem = achievements_manager_viewer_manager_selection_tree_.get_selected()
	if is_instance_valid(selected_tree_item):
		__refresh_achievement_entries()


func __on_achievement_view_selection_nothing_selected() -> void:
	if achievements_manager_viewer_achievement_entries_tree_.get_selected_column() != -1:
		# Deselect the achievement
		achievements_manager_viewer_achievement_entries_tree_.deselect_all()

		# Clear the data view
		achievements_manager_viewer_achievement_data_view_text_edit_.set_text("")
		achievements_manager_viewer_achievement_data_view_warning_label_.set_text("Select an AchievementEntry to display its data.")
		achievements_manager_viewer_achievement_data_view_warning_label_.show()

		# Clear the metadata view
		achievements_manager_viewer_achievement_metadata_view_text_edit_.set_text("")
		achievements_manager_viewer_achievement_metadata_view_warning_label_.set_text("Select an AchievementEntry to display its metadata.")
		achievements_manager_viewer_achievement_metadata_view_warning_label_.show()


func __on_achievement_view_selection_item_selected() -> void:
	var selected_tree_item : TreeItem = achievements_manager_viewer_achievement_entries_tree_.get_selected()
	if is_instance_valid(selected_tree_item):
		if achievements_manager_viewer_achievement_data_view_warning_label_.is_visible():
			achievements_manager_viewer_achievement_data_view_warning_label_.hide()

		var column : int = 0
		var achievement_tree_item_metadata : Array = selected_tree_item.get_metadata(column)
		var achievements_manager : AchievementsManager = achievement_tree_item_metadata[0]
		var achievement_id : int = achievement_tree_item_metadata[1]
		var achievement_entry : AchievementEntry = achievements_manager.get_achievement_entry(achievement_id)

		# Update the data view
		var data_view : String = ""
		data_view += "ID: %d\n" % achievement_id
		data_view += "Name: %s\n" % achievement_entry.get_name()
		data_view += "Description: %s\n" % achievement_entry.get_description()
		var achievement_string_id : String = achievement_entry.get_string_id()
		if achievement_string_id.is_empty():
			achievement_string_id = "(Empty Description)"
		data_view += "String ID: %s\n" % achievement_string_id
		data_view += "Hidden: %s\n" % str(achievement_entry.is_hidden())
		data_view += "Progress: %d/%d\n" % [achievement_entry.get_progress_current(), achievement_entry.get_progress_max()]
		data_view += "Has Metadata: %s\n" % str(achievement_entry.has_metadata())
		data_view += "Unlocked: %s\n" % str(achievement_entry.is_unlocked())

		achievements_manager_viewer_achievement_data_view_text_edit_.set_text(data_view.strip_edges(true,true))

		# Update the metadata view
		if not achievement_entry.has_metadata():
			achievements_manager_viewer_achievement_metadata_view_text_edit_.set_text("")
			achievements_manager_viewer_achievement_metadata_view_warning_label_.set_text("(Empty Metadata)")
			achievements_manager_viewer_achievement_metadata_view_warning_label_.show()
		else:
			achievements_manager_viewer_achievement_metadata_view_warning_label_.hide()
			var achievement_metadata : Dictionary = achievement_entry.get_metadata_data()
			var prettified_metadata : String = JSON.stringify(achievement_metadata, "\t").strip_edges(true,true)
			achievements_manager_viewer_achievement_metadata_view_text_edit_.set_text(prettified_metadata)
