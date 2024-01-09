@tool
extends EditorPlugin

var plugin_container: VBoxContainer
var currentAnimationPlayer: AnimationPlayer
@onready var forms_hidden: bool = true;

func _enter_tree():
	setup_gui()

func _exit_tree():
	if plugin_container:
		for child in plugin_container.get_children():
			child.queue_free()
		plugin_container.queue_free()

func _edit(object):
	if object and object is AnimationPlayer:
		currentAnimationPlayer = object
		plugin_container.show()
	else:
		currentAnimationPlayer = null
		plugin_container.hide()

func handles(object):
	return object is AnimationPlayer

func _handles(object):
	return object is AnimationPlayer
	
func setup_gui():
	plugin_container = VBoxContainer.new()
	plugin_container.hide()
	
	var form_container = VBoxContainer.new()
	plugin_container.hide()
	
	var head_container = HBoxContainer.new();
	
	var headline_label = Label.new()
	headline_label.text = "Generate frame tracks"
	head_container.add_child(headline_label)
	
	var toggle_button = Button.new()
	toggle_button.set_button_icon(get_icon("ArrowDown"))
	toggle_button.pressed.connect(self.on_toggle_form_button_pressed)
	
	head_container.add_child(toggle_button)
	
	var delete_button = Button.new()
	delete_button.text = "Delete Animations"
	delete_button.pressed.connect(self.on_delete_animations_button_pressed)
	form_container.add_child(delete_button)

	form_container.add_child(generate_text_input_section("Animation Library Name", "[Global]"))
	form_container.add_child(generate_text_input_section("Animation Name", "STANDING_SOUTH"))
	
	form_container.add_child(generate_spin_box_section("Frame Duration", .35, .1))
	form_container.add_child(generate_spin_box_section("Row", 1, 1))
	form_container.add_child(generate_spin_box_section("From (Frames start with 0)", 0, 1))
	form_container.add_child(generate_spin_box_section("To (Frames start with 0)", 0, 1))
	
	form_container.add_child(generate_checkbox_section("Alternate", false))
	form_container.add_child(generate_checkbox_section("Loop", true))
	
	var action_button = Button.new()
	action_button.text = "Generate"
	action_button.pressed.connect(self.on_auto_generate_button_pressed)
	form_container.add_child(action_button)
	
	form_container.hide();

	plugin_container.add_child(head_container)
	plugin_container.add_child(form_container)
	add_control_to_container(EditorPlugin.CONTAINER_INSPECTOR_BOTTOM, plugin_container)


func on_toggle_form_button_pressed():
	var forms:VBoxContainer = plugin_container.get_children()[1];
	var toggle_button:Button = plugin_container.get_children()[0].get_children()[1];
	if forms_hidden:
		forms.show()
		forms_hidden = false;
		toggle_button.set_button_icon(get_icon("ArrowUp"))
	else:
		forms.hide()
		forms_hidden = true;
		toggle_button.set_button_icon(get_icon("ArrowDown"))

func on_delete_animations_button_pressed():
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Confirm deletion"
	confirm_dialog.dialog_text = "Are you sure you want to delete all animations of " + currentAnimationPlayer.name + "?"
	get_editor_interface().get_base_control().add_child(confirm_dialog)
	confirm_dialog.popup_centered()
	confirm_dialog.connect("confirmed", self.delete_animations)

func delete_animations(): 
	var lib_names = currentAnimationPlayer.get_animation_library_list()
	var animation_names = currentAnimationPlayer.get_animation_list()
	for lib_name in lib_names:
		var lib: AnimationLibrary = currentAnimationPlayer.get_animation_library(lib_name)
		for animation_name in animation_names:
			if lib.has_animation(animation_name):
				lib.remove_animation(animation_name)
				if lib_name == "":
					lib_name = "[Global]"
				print(animation_name + " was successfully removed in " + lib_name)

func on_auto_generate_button_pressed():
	var parent = currentAnimationPlayer.get_parent();
	if parent is Sprite2D:
		var forms = plugin_container.get_children()[1].get_children();
		var animationLibraryName:String = forms[1].get_children()[1].text;
		if animationLibraryName == "[Global]":
			animationLibraryName = "";
		var animationName:String = forms[2].get_children()[1].text;
		var frameDuration:float = forms[3].get_children()[2].value;
		var row:int = forms[4].get_children()[2].value;
		var from:int = forms[5].get_children()[2].value;
		var to:int = forms[6].get_children()[2].value;
		var alternate:bool = forms[7].get_children()[2].is_pressed()
		var loop:bool = forms[8].get_children()[2].is_pressed();
		if from > to:
			push_error("From (" + str(from) + ") is higher then To (" + str(to) + "). Generating frames aborted.")
		elif from > row * parent.hframes:
			push_error("From (" + str(from) + ") is higher then the row frame count (" + str(row * parent.hframes) + "). Generating frames aborted.")
		else: 
			var animation = Animation.new()
			var track_index = animation.add_track(Animation.TYPE_VALUE)
			var framesRange = get_frame_range(from, to, row, alternate)
			var animation_length:float = framesRange.size() * frameDuration
			animation.resource_name = animationName
			animation.length = animation_length
			animation.track_set_path(track_index, NodePath(".:frame"))
			animation.value_track_set_update_mode(track_index, animation.UPDATE_DISCRETE)
			var index = 0;
			for itemPos in framesRange:
				animation.track_insert_key(track_index, frameDuration * index, itemPos)
				index = index + 1
			if loop:
				animation.set_loop_mode(Animation.LOOP_LINEAR)
			else:
				animation.set_loop_mode(Animation.LOOP_NONE)

			var animation_lib: AnimationLibrary;
			if currentAnimationPlayer.has_animation_library(animationLibraryName):
				animation_lib = currentAnimationPlayer.get_animation_library(animationLibraryName)
			else: 
				animation_lib = AnimationLibrary.new();
				currentAnimationPlayer.add_animation_library(animationLibraryName, animation_lib)

			if animation_lib.has_animation(animationName):
				animation_lib.remove_animation(animationName)

			animation_lib.add_animation(animationName, animation)
			
			print("Creating frames for " + animationName + " was successfull! Check the animation tab on the bottom.") 
	else:
		push_error("Parent must be a Sprite2D")
		

func generate_text_input_section(title: String, defaultValue: String) -> HBoxContainer:
	var container = HBoxContainer.new()
	var label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = title
	container.add_child(label)
	
	var input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text = defaultValue
	container.add_child(input)
	return container
	

func generate_spin_box_section(title: String, defaultValue: float, step: float) -> HBoxContainer:
	var container = HBoxContainer.new()
	var label = Label.new()
	label.text = title
	container.add_child(label)
	
	container.add_child(generate_spacer())
	
	var input = SpinBox.new()
	input.step = step
	input.min_value = 0
	input.value = defaultValue
	container.add_child(input)
	return container


func generate_checkbox_section(title: String, checked: bool) -> HBoxContainer:
	var container = HBoxContainer.new()
	var label = Label.new()
	label.text = title
	container.add_child(label)
	
	container.add_child(generate_spacer())
	
	var input = CheckButton.new()
	input.set_pressed(checked)
	container.add_child(input)
	return container

func generate_spacer() -> Control:
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer;
	
func get_frame_range(from: int, to: int, row: int, alternate: bool) -> Array:
	var alternated_range = []
	var sprite: Sprite2D = currentAnimationPlayer.get_parent();
	var frames_per_row = sprite.hframes
	var frame_offset = frames_per_row * (row - 1)
	var initial_range = range(from + frame_offset, (to + frame_offset) + 1);
	for index in initial_range:
		alternated_range.append(index);
	if alternate:
		initial_range.reverse()
		for index in initial_range:
			if index != to && index != from:
				alternated_range.append(index);
	return alternated_range;


func get_icon(icon: String) -> Texture2D:
	var gui = get_editor_interface().get_base_control()
	return gui.get_theme_icon(icon, "EditorIcons")
