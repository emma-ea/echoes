extends "res://scripts/ui/modal.gd"
## The Chronicle: assign who / what / when to each event from the terms you've learned.
## An event is only confirmed when every slot is right; the board never says which slot is wrong.

signal echo_requested(echo_id: String)

const NO_CHOICE := "(choose)"


func _ready() -> void:
	panel.custom_minimum_size = Vector2(1120, 0)
	_rebuild()


func _rebuild() -> void:
	clear_content()
	add_label("Chronicle", 34)

	# Scrolls once there are more Echoes and events than fit on screen.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1056, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 40)
	scroll.add_child(columns)
	columns.add_child(_build_echo_list())

	var events_box := VBoxContainer.new()
	events_box.size_flags_horizontal = SIZE_EXPAND_FILL
	events_box.add_theme_constant_override("separation", 24)
	columns.add_child(events_box)
	# Open questions first, solved ones after; events stay hidden until the story reaches them.
	var open_events: Array = []
	var solved_events: Array = []
	for event_id in ContentDB.events:
		if GameState.is_event_visible(event_id):
			(solved_events if GameState.has_discovery(event_id) else open_events).append(event_id)
	for event_id in open_events + solved_events:
		events_box.add_child(_build_event(event_id))

	add_button("Close", close)


func _build_echo_list() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_child(make_label("Echoes", 26))
	if GameState.echoes.is_empty():
		box.add_child(make_label("Nothing yet. Explore to find Echoes.", 20))
	for echo_id in GameState.echoes:
		var title: String = ContentDB.echoes[echo_id].get("title", echo_id)
		add_button(title, func(): echo_requested.emit(echo_id), box)
	return box


func _build_event(event_id: String) -> Control:
	var event: Dictionary = ContentDB.events[event_id]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(make_label(event.get("title", event_id), 28))

	if GameState.has_discovery(event_id):
		var discovery: Dictionary = event.get("discovery", {})
		var heading := make_label("Discovery: " + str(discovery.get("title", "")), 24)
		heading.modulate = Color(0.95, 0.8, 0.45)
		box.add_child(heading)
		box.add_child(make_label(GameState.format_text(discovery.get("text", ""))))
		return box

	var slots: Dictionary = event.get("slots", {})
	var placed: Dictionary = GameState.placements.get(event_id, {})
	var confirm := Button.new()
	var feedback := make_label("", 20)

	for slot in ContentDB.SLOTS:
		if not slots.has(slot):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var slot_label := make_label(slot.capitalize())
		slot_label.custom_minimum_size = Vector2(110, 0)
		row.add_child(slot_label)

		var picker := OptionButton.new()
		picker.size_flags_horizontal = SIZE_EXPAND_FILL
		picker.custom_minimum_size = Vector2(0, 64)
		picker.add_item(NO_CHOICE)
		picker.set_item_metadata(0, "")
		for term_id in GameState.known_terms(slot):
			picker.add_item(ContentDB.terms[term_id].get("label", term_id))
			picker.set_item_metadata(picker.item_count - 1, term_id)
			if placed.get(slot, "") == term_id:
				picker.select(picker.item_count - 1)
		picker.item_selected.connect(_on_term_selected.bind(event_id, slot, picker, confirm, feedback))
		row.add_child(picker)
		box.add_child(row)

	confirm.text = "This is what happened"
	confirm.custom_minimum_size = Vector2(0, 72)
	confirm.disabled = not GameState.is_event_filled(event_id)
	confirm.pressed.connect(_on_confirm.bind(event_id, feedback))
	box.add_child(confirm)
	box.add_child(feedback)
	return box


func _on_term_selected(index: int, event_id: String, slot: String, picker: OptionButton, confirm: Button, feedback: Label) -> void:
	GameState.place_term(event_id, slot, str(picker.get_item_metadata(index)))
	feedback.text = ""
	confirm.disabled = not GameState.is_event_filled(event_id)


func _on_confirm(event_id: String, feedback: Label) -> void:
	if GameState.try_resolve(event_id):
		_rebuild()
	else:
		feedback.text = "Something doesn't fit. Look again."
