extends RefCounted
## What build this is, for the title screen and the end screen ("0.1.0 playtest").

const CHANNEL := "playtest"  # change to "" for a public release


static func label() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	return ("%s %s" % [version, CHANNEL]).strip_edges()
