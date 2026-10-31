extends RefCounted
## The game's typefaces (both SIL Open Font License; licences in res://fonts).
## Body: Alegreya, a warm book face that stays readable at small sizes. It's also the project's
## default font (Project Settings > GUI > Theme > Custom Font), so every Control uses it.
## Display: IM FELL English, a weathered 17th-century letterpress face, for titles, headings,
## names and narration.

const BODY := preload("res://fonts/Alegreya-Variable.ttf")
const DISPLAY := preload("res://fonts/IMFellEnglish-Regular.ttf")
const DISPLAY_ITALIC := preload("res://fonts/IMFellEnglish-Italic.ttf")
