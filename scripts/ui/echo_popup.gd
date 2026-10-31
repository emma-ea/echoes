extends "res://scripts/ui/modal.gd"
## Shows one Echo: what it is, what it says, and (when new) the terms it adds to the Chronicle.


func setup(echo_id: String, newly_found: bool) -> void:
	var echo: Dictionary = ContentDB.echoes[echo_id]
	panel.custom_minimum_size = Vector2(820, 0)

	var kind := add_label(str(echo.get("kind", "")).to_upper(), 18)
	kind.modulate = Color(1, 1, 1, 0.6)
	add_label(echo.get("title", ""), 34)
	add_label(GameState.format_text(echo.get("text", "")))

	if newly_found:
		var labels := PackedStringArray()
		for term_id in echo.get("terms", []):
			labels.append(ContentDB.terms[term_id].get("label", term_id))
		var added := add_label("Added to your Chronicle: " + ", ".join(labels), 20)
		added.modulate = Color(0.95, 0.8, 0.45)

	add_button("Close", close)
