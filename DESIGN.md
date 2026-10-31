# Echoes of the Forgotten City — One-Page Design

**Genre:** 2D exploration and deduction mystery · **Platform:** Mobile (iOS/Android), fully offline · **Team:** Solo

## Pitch

A city was abandoned overnight, and no one remembers why. You explore its empty streets, collect echoes of the people who lived there, and piece together what happened. Each decision you make reshapes the district, and the truth you put together decides how it ends.

## Target Player

Mystery and adventure fans who like *Return of the Obra Dinn*, *Her Story*, *Gorogoa* and *The Room*. They want deduction that feels earned, not hand-holding. Play happens in 10–20 minute mobile sessions.

## Core Loop

1. **Explore:** guide a lantern-carrying explorer through dark side-view rooms. Tap to walk, tap objects to walk over and use them (landscape).
2. **Collect:** inspect objects to gather *Echoes* (letters, photos, carvings, voice fragments).
3. **Deduce:** place Echoes on the **Chronicle**, a timeline and cast board. Correct groups of 3 lock in and reveal a *Discovery*.
4. **Unlock:** Discoveries supply what you need for puzzles, such as a name, a date or a symbol order. Knowledge is the key, not inventory.
5. **Decide:** at key moments, choose what to do with the truth. The district changes as a result.

## Signature Mechanic: The Chronicle

- A board with slots for **Who**, **What**, **When** and **Where** for each event.
- The game confirms a slot only once a full group of 3 is correct, so players can't brute-force it one slot at a time.
- Ghost guides (see below) keep it accessible without spoiling answers.

## Ghosts and Guidance

The city's former inhabitants linger as ghosts. They are the hint system, written as part of the story:
- **Guides** (e.g. Pell, the night porter) answer "Where should I look next?" with a hint chosen by the
  player's progress, so the hint never spoils anything beyond the next step.
- **Witnesses** (e.g. Wren, a child) add testimony and atmosphere that support the Chronicle deductions,
  sometimes with red herrings.
- Ghosts react to what the player has done (new lines once the lamps are relit).

## Music

Dark ambient loops per state (a minor-key drone with distant bells while the city is dark, a warmer
major-key theme once the lamps return), crossfading on progress. Placeholder loops are synthesised;
composed tracks can replace the files directly.

## Replayability (Authored, Not Generated)

The mystery is hand-written. Each new run randomises **variables**, not the story:

- Which of 3 factions caused the abandonment (3 authored variants of the key Echoes)
- Where clues are placed within each scene
- Codes, symbol orders and dates used in puzzles

## Decisions and City State

- 3 major decisions per chapter, each a visible change to the world (e.g. drain the canal / seal the archive / light the beacon).
- Each decision is stored as a flag. Scenes swap art layers based on those flags (no separate copies of each scene).
- The decision flags plus how complete your Chronicle is lead to one of **2 endings** in the MVP.

## MVP Scope (Chapter 1, Free)

| Item | Target |
|---|---|
| Explorable district | 1 (about 12 scenes) |
| Puzzles | 15 (mostly single-screen) |
| Echoes | ~30 |
| Major Discoveries | 5 |
| Major decisions | 3 |
| Endings | 2 |
| Playtime | 60–90 min |
| Save | Local, auto-save on every state change |

## Monetization

- **Chapter 1:** free, a complete story arc with a hook into the wider city.
- **Full Story Unlock:** a single purchase (~$4.99) for Chapters 2–4, all released before launch or on a committed schedule.
- **Expansions (post-launch, only if it sells):** new districts or side mysteries.
- No ads, no cosmetics, no energy timers.
- Purchases are checked offline: the receipt is validated once, then cached on the device. Restore Purchases is required.

## Tech

- **Engine:** Godot 4 (2D, free, exports to both iOS and Android, suits a solo developer).
- **Content as data:** Echoes, puzzles and Chronicle answers live in JSON/Resource files, so writing content doesn't require code changes.
- **Save:** one versioned JSON file (flags, Echoes, Chronicle state, run seed).
- **IAP:** Godot plugins for Google Play Billing and StoreKit.

## Milestones

1. **Vertical slice (4–6 wks):** 1 building, 3 Echoes, 1 Chronicle deduction, 1 puzzle. *Test: does the "aha" moment land?*
2. **Systems (6–8 wks):** full Chronicle, save, decision flags, art-layer swapping, hints.
3. **Chapter 1 content (10–14 wks):** all 12 scenes, 15 puzzles, 5 Discoveries, 2 endings.
4. **Beta (4 wks):** TestFlight / Play internal testing, tune difficulty, measure where players stall.

## Key Risks

| Risk | Mitigation |
|---|---|
| Art workload for a solo developer | Limited palette, reusable tilesets, layered scenes, a consistent stylised look over detail |
| Deduction too hard or too easy | Track stall points in beta; add hint tiers |
| Players drop off before paying | Make Chapter 1 satisfying on its own, with a strong closing hook |
| Writing branches multiply | Cap at 3 decisions per chapter; flags change scenes, not the whole story |

## Success Criteria for the Slice

- 4 out of 5 playtesters solve the deduction without help, and say it felt clever.
- Testers want to keep going after the slice ends.
