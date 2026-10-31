# Echoes of the Forgotten City

Vertical slice (Milestone 1 in [DESIGN.md](DESIGN.md)): one building, 3 Echoes, 1 Chronicle deduction, 1 puzzle.
Godot 4.7, 2D side-view, mobile renderer, landscape. A hooded explorer with a lantern walks through
dark rooms; all art is drawn in code as placeholders until real art exists.

The game opens on a title screen, then (for a new game) a short narrated intro: a letter has
summoned you to the abandoned city of Veyl. A **prelude** on the street outside the guildhall teaches
one thing at a time, with an on-screen objective and tip cards: walking, reading Echoes, the Chronicle,
a two-part practice deduction (the night door only opens once you've worked out who sent the letter),
doors, and talking to people. Objectives then carry on through the main mystery without tips.
The **Menu** button (or Esc / Android back) pauses the game.

Two ghosts haunt the guildhall: **Pell** the night porter (foyer), who guides you with hints that follow
your progress, and **Wren** (Watch Office), a child who saw what happened. Dark ambient music plays
throughout and crossfades to a warmer theme once the lamps are relit. Music on/off and volume (1-5)
are in the in-game Menu and saved in `user://settings.cfg`.

**Controls:** tap/click the floor to walk, tap an object or ghost to walk over and use / talk to it.
In conversations, tap (or E / Space) to continue.
Desktop testing: A/D or arrow keys to walk, E or Space to use whatever is nearby.

## Run it

1. Install Godot 4.7 (standard build, not .NET): https://godotengine.org/download or `brew install --cask godot`
2. Open Godot, **Import** this folder (`project.godot`), press **F5**. It starts at the title screen.

Smoke test (validates content and plays through the slice headless):

```sh
godot --headless --path . --import          # first time only, builds the .godot cache
godot --headless --path . res://tools/smoke_test.tscn
```

It prints `SMOKE TEST PASSED` and exits 0, or lists each failure and exits 1.

Regenerate the music (synthesised by a script, ~30 s; needs `ffmpeg`):

```sh
godot --headless --path . -s res://tools/make_music.gd -- --out=/tmp/music
for f in /tmp/music/*.wav; do ffmpeg -y -i "$f" -c:a libvorbis -q:a 4 "audio/$(basename "${f%.wav}").ogg"; done
```

Screenshots of key moments (needs a window, so no `--headless`):

```sh
godot --path . res://tools/screenshots.tscn -- --out=$HOME/Desktop
```
Content problems also show up as red errors in the editor's Output panel every time you run the game.

## Layout

```
data/               All authored content (edit these to make the game)
  world.json        Title, intro narration, start scene and starting Echoes, music, run variables
  quests.json       Objectives in order, with tutorial tips, each done when its conditions pass
  scenes.json       Locations: background, art layers, hotspots
  echoes.json       Clues the player collects, and the terms each one teaches
  chronicle.json    Terms (who/what/when/where) and the events to deduce
  puzzles.json      Puzzles, their answers and effects
  npcs.json         Ghost NPCs: name, look, colour, which dialogue they use
  dialogue.json     Conversations: lines, choices, progress-based branches
audio/              Music loops (.ogg)
autoload/
  content_db.gd     Loads + validates data/ (read-only at runtime)
  game_state.gd     The player's run: rules, conditions, dialogue branching, local save
  music.gd          Picks and crossfades music by progress; on/off and volume 1-5 kept in user://settings.cfg
scenes/             title.tscn (main scene) -> intro.tscn (new game) -> main.tscn (the game)
scripts/
  title.gd, title_backdrop.gd   Main menu and its night-city backdrop
  intro.gd          Opening narration
  main.gd           Root: world + UI layer (HUD, overlays, toasts, room fades); routes interactions
  world/
    world.gd        Room, explorer, camera, ambient light, tap/keyboard input, hotspot markers
    room.gd         Builds a room from data: wall, floor, props, dust; fades lights on flag changes
    prop.gd         Placeholder-art vocabulary (window, door, desk, valve...) + "sprite" for real art
    player.gd       The explorer: walking, animation, lantern light
    ghost.gd        Ghost NPCs: hover, flicker, glow, watch the explorer
    skyline.gd      Parallax sky and rooftops for outdoor rooms (and the title screen)
    hotspot_marker.gd, tap_ripple.gd, lighting.gd
  ui/               Modal base, Echo popup, Chronicle board, dial puzzle, dialogue box,
                    pause menu, confirm dialog, volume control
tools/
  smoke_test.*      Headless test (content, rules, save, walking, every screen)
  screenshots.*     Renders key moments to PNG
  make_music.gd     Synthesises the music loops
art/                Final art goes here
```

Game rules live in `GameState`; UI only reads state and calls its methods. Every change saves to `user://save.json` (written to a temp file first, then renamed).

## Data formats

**Conditions** are strings used by `visible_if`, `requires`, `if` and `done_if`:
`flag:<name>`, `echo:<id>`, `discovery:<event id>`, `puzzle:<id>`, `visited:<scene id>`. Prefix `!` to negate. Empty means always true.

**Text** anywhere can use `{variable}` placeholders, filled from this run's rolled `world.json` variables.

**world.json → variables**: rolled from the run seed, so the same seed always gives the same details.
- `{ "type": "digits", "length": 4, "min": 1, "max": 6 }` produces e.g. `"3514"`
- `{ "type": "choice", "options": ["guild", "council", "smugglers"] }` picks one

**scenes.json** describes side-view rooms. Rooms are 720 tall and at least 1600 wide (so wide phones
never see past the edge); the camera follows the explorer. Coordinates are room pixels, y down.
```json
"scene_id": {
  "name": "Shown in the HUD",
  "width": 2200, "floor_y": 600,          // the explorer walks along floor_y
  "walk": [70, 2130], "spawn_x": 260,     // walkable x range; where you appear on load / new run
  "style": "interior" | "street",        // street: night sky, parallax rooftops, cobbles
  "npcs": [{ "id": "pell", "x": 430, "visible_if": "..." }],
  "triggers": [{ "x": [520, 2200], "set_flags": ["walked_street"] }],  // walking into the range sets flags
  "palette": { "wall": "#5b5262", "trim": "#6b5a5e", "floor": "#3b3230" },
  "ambient": [{ "color": "#e6dccd", "if": "flag:valve_opened" }, { "color": "#7a84a6" }],
  "props":    [{ "type": "window", "rect": [x, y, w, h], "visible_if": "...", "lit_if": "...",
				 "front": true, "flip": true }],
  "hotspots": [{ "label": "...", "rect": [x, y, w, h], "action": "...", "stand_x": 690,
				 "visible_if": "...", "requires": "...", "locked_text": "shown if requires fails" }]
}
```
- **ambient** tints the whole room: the first entry whose `if` passes wins. Dark tint + lights = atmosphere.
- **props** are drawn scenery. Types: `window door archway desk lectern chandelier sconce pillar chalk
  valve pipes crate rubble banner shelf cobweb street_lamp facade notice_board`, or `sprite` with `"texture": "res://art/x.png"` for real art.
  `lit_if` gives a prop a light that fades in when the condition becomes true. `front` draws it in front
  of the explorer. `flip` mirrors it.
- **hotspots** are what the explorer can use. Tapping one walks to `stand_x` (default: middle of the rect),
  then triggers the action. Actions: `echo` (+ `"echo": id`), `goto` (+ `"target": scene`, `"arrive_x"`),
  `puzzle` (+ `"puzzle": id`), `examine` (+ `"text"`).
- A city change is a pair of props or hotspots with `visible_if` / `lit_if` set to `flag:x` and `!flag:x`.

**quests.json**: `{ "steps": [{ "id", "objective", "tip", "highlight": "chronicle", "done_if": "cond" or ["cond", ...] }] }`.
The current objective is the first step whose `done_if` isn't met yet; give the last step no `done_if`.
`tip` shows a dismissable tip card while the step is current; `highlight` pulses the Chronicle button.
The flag `opened_chronicle` is set by the game itself when the Chronicle is opened.

**chronicle.json → events** can have `visible_if` to stay off the Chronicle until the story reaches them.

**world.json → music**: `[{ "track": "res://audio/x.ogg", "if": "flag:..." }, ...]`. The first entry whose
`if` passes plays; changes crossfade over 3 s. Drop in composed `.ogg` files any time.

**npcs.json**: `{ "name", "look": "porter" | "child", "color": "#hex", "dialogue": id }`. Placing an NPC in a
room (`"npcs"` above) makes it a tappable "talk" hotspot automatically.

**dialogue.json**: one entry per conversation, each a set of nodes; talking starts at `"start"`.
```json
"start":  { "branch": [{ "if": "!flag:met_pell", "goto": "first_meeting" }, { "goto": "greeting" }] },
"first_meeting": { "lines": ["...", "..."], "effects": { "set_flags": ["met_pell"] }, "next": "menu" },
"menu":   { "choices": [{ "text": "Who was Ilsa?", "goto": "about_ilsa", "if": "echo:echo_letter" },
                        { "text": "Goodbye.", "goto": "farewell" }] },
"farewell": { "lines": ["Mind the dark."] }
```
- `branch` jumps to the first option whose `if` passes; the last option must have no `if`.
- `lines` are spoken one at a time. Then `choices` are shown (filtered by `if`), or it goes to `next`.
  No `next` and no choices ends the conversation. A choices-only node keeps the previous line on screen.
- Branching on progress (`!echo:...`, `!discovery:...`) is how Pell gives hints that never spoil ahead.

**echoes.json**: `{ "title", "kind", "text", "terms": [term ids] }`. Reading an Echo teaches its terms.

**chronicle.json**:
- `terms`: `{ "label": "Ilsa Varn", "category": "who" | "what" | "when" | "where" }`
- `events`: `{ "title", "slots": { "who": term, ... }, "discovery": { "title", "text" }, "effects": {} }`.
  An event resolves only when every slot is correct; the board never says which slot is wrong.

**puzzles.json**: `dial_code` puzzles use `dials`, `min`, `max` (single digits), `solution_var`, `prompt`, `fail_text`, `solved_text` and `effects`.

**effects** (events and puzzles): `{ "set_flags": ["valve_opened"] }`.

## Adding a new puzzle type

1. Add the type name to `PUZZLE_TYPES` in `autoload/content_db.gd` (plus any validation it needs).
2. Write a screen extending `res://scripts/ui/modal.gd` with a `setup(puzzle_id)` method that calls `GameState.try_puzzle(id, answer)`.
3. Register it in `PUZZLE_SCREENS` in `scripts/main.gd`.

## Not in the slice yet

Sound effects (footsteps, doors, the valve), voice blips for ghosts, major decisions/endings, faction variants (supported by `choice` variables, not used yet), audio and footsteps, real art and character animation frames, safe-area insets for notched phones, IAP.
