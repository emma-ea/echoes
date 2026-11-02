# Playtest Release Checklist: v0.1 (friends)

**Goal:** get Chapter One onto friends' phones and learn:
1. Does the street prelude teach the game without help?
2. Where do people get stuck?
3. Is the main deduction too hard or too easy?
4. Does the atmosphere (visuals, music, ghosts) land?
5. Which phones have problems?

`[x]` done · `[ ]` to do · **(you)** needs your accounts, devices or decisions · **(code)** a change in the project

---

## 1. Decisions

- [x] **Platform:** Android first, by sending the APK file directly. iOS (TestFlight) and desktop builds come later if needed.
- [x] **Package name:** `com.oddlycodes.echoesoftheforgottencity`. This is permanent once on the Play Store.
- [x] **Launcher name:** Echoes of the Forgotten City
- [x] **Version:** `0.1.1`, `version/code` 2 (the first Play build; testers had `0.1.0`, code 1).
  Raise `version/code` by 1 for every build you send or upload.
  Also set as the project version (`application/config/version`), so the game can show it.
- [x] **Renderer:** Mobile (Vulkan). Godot's *Fallback to OpenGL 3* setting is on (the default), so phones
  without working Vulkan drop to OpenGL instead of showing a black screen. When testing on an older
  phone, check that the lighting still looks right.

## 2. Fix in the game before sending (code)

- [x] **End-of-demo screen.** Shown once, a few seconds after the valve is reopened. Options: *Keep exploring*
  or *Main menu*, plus the build number.
  - [ ] **(you)** Once your feedback form exists, put its link in `data/world.json` → `demo_end.feedback_url`.
	A *Share your feedback* button then appears on the end screen.
- [x] **Version label** `0.1.0 playtest` on the title screen. It comes from the project version; change the
  word "playtest" in `scripts/ui/build_info.gd`.
- [x] **Safe areas.** On phones, the top bar and tip card move in from notches and camera cutouts, and adjust
  when the phone is turned round. (Only phones report a cutout, so check it on the device.)
- [x] **Dev tools left out of the build.** The preset excludes `tools/*`. Checked by exporting the game data
  with the Android preset: no tool files inside, and the game runs from that file on its own.
- [x] **Boot splash.** The lantern with the game's name below, on the game's night colour, for at least
  1.5 s. Android's own launch screen uses the same colour and the lantern icon, so the two hand over cleanly.
- [x] Launcher icons: generated in `icons/` and set in the Android preset and as the project icon.
- [x] Anonymous analytics through GameAnalytics (see README → Analytics). The game still plays fully
  offline; events wait and send later. Needs the `INTERNET` and `ACCESS_NETWORK_STATE` permissions
  (both set). No advertising ID: the build has no `AD_ID` permission, so answer "No" to Play's
  advertising ID question. Opt-in: the title screen asks once before anything is sent (GameAnalytics'
  terms require consent first), and *Share play data* in the Menu changes it.
  - [ ] **(you)** Put your GameAnalytics keys in `analytics_keys.json` before exporting.
  - [ ] **(you)** A privacy policy (required by Google Play for apps that collect data), and the
    Play Console *Data safety* form. See section 8.
- [x] Progress saves automatically; there's a pause menu, music on/off and volume.

## 3. Test on a real phone (you)

The game has only been run on desktop so far. Before sending:

- [ ] Run the smoke test: `godot --headless --path . res://tools/smoke_test.tscn` should print `SMOKE TEST PASSED`.
- [ ] Install on your own Android phone (and a cheap or old one if you can borrow it). Check:
  - [ ] Tapping to walk goes where you tap; markers and doors are easy to hit with a thumb.
  - [ ] Text is readable: tips, dialogue, the Chronicle drop-downs.
  - [ ] Back button: closes dialogs, opens the pause menu in game, quits from the title screen.
  - [ ] Switch to another app mid-conversation and come back. Lock and unlock the screen.
  - [ ] Turn the phone the other way round (the game should flip to the other landscape orientation).
  - [ ] Music volume and on/off are remembered after quitting.
  - [ ] Phone isn't hot and battery drain is reasonable after 15 minutes.
- [ ] Do one full playthrough from a fresh install to the lamps being lit (~15–25 minutes).

## 4. Build for Android (you)

1. **Export templates:** 4.7.2 is already installed.
2. **Tools:** in *Editor Settings → Export → Android*, set the **Java SDK** (JDK 17) and **Android SDK** paths.
   Android Studio installs the SDK.
3. **Gradle build:** on, and required: it adds the GameAnalytics Android library. The build template
   is installed in `android/` (git-ignored; reinstall with *Project → Install Android Build Template*
   on a fresh clone). The first export downloads dependencies, so it needs internet.
   - **AAB for Google Play:** *Export Format* AAB, *Compress Native Libraries* off (Google recommends
     uncompressed; Play compresses the download itself). This is how the preset is set now:
     `godot --headless --path . --export-release Android build/echoes-<version>.aab`
   - **APK for testers:** set *Export Format* to APK and turn *Compress Native Libraries* on (~32 MB).
   - **Minimum Android 10 (API 29):** Godot requires it for the Mobile renderer in Gradle builds.
     Older phones would need the Compatibility renderer.
4. **Signing:** Godot can sign with its debug keystore, which is fine for friends. For anything that
   might go to the Play Store later, make a release keystore once:
   ```sh
   keytool -genkey -v -keystore ~/keys/echoes-release.keystore -alias echoes -keyalg RSA -keysize 2048 -validity 10000
   ```
   Keep it **outside the repo** and **back it up**. Lose it and you can never update the app.
   Godot stores the keystore passwords in `.godot/export_credentials.cfg`, which git already ignores.
5. **Architectures:** arm64-v8a only (already set) covers nearly every phone from the last ~8 years.
6. **Export:** *Project → Export → Android → Export Project*. Name it like `echoes-0.1.0.apk`.
   Untick *Export With Debug* for the build you send.
7. **Install and check it yourself first:** `adb install -r echoes-0.1.0.apk`. If it crashes,
   `adb logcat -s godot` shows why.

## 5. Send it to testers (you)

- **Android, simplest:** upload the APK to Google Drive or Dropbox and share the link. Testers allow
  *Install unknown apps* for Drive or their browser when prompted.
  Sign every later build with **the same keystore** and a higher `version/code`, or testers must
  uninstall first, which deletes their save.
- **Android, more testers or frequent builds:** Google Play *Internal testing* ($25 one-time developer
  account, up to 100 testers by email, automatic updates). This needs an AAB, so turn the Gradle build on.
- **iOS:** Apple Developer Program → Godot iOS export → Xcode → *Archive* → TestFlight.
  Use `icons/icon.png` as the 1024×1024 App Store icon (it has no transparency, as Apple requires).
- **Desktop fallback:** export macOS or Windows. Unsigned macOS apps open via right-click → *Open*.
- [ ] Tag the build in git: `git tag v0.1.0 && git push --tags` (if you use a remote).

## 6. Feedback (you)

- [ ] Make a short feedback form (e.g. Google Forms):
  1. Phone model and Android version
  2. Did you finish? About how long did it take?
  3. Was there a moment you didn't know what to do? Which objective was showing?
  4. Did the street section teach you how to play? (yes / mostly / no)
  5. Working out who sent the letter: clear or confusing?
  6. The main mystery, from 1 (too easy) to 5 (too hard)
  7. Did you ask Pell where to look? Did it help?
  8. Atmosphere: visuals, music and ghosts, from 1 to 5
  9. Bugs, or anything weird (screenshots help)
  10. Would you play Chapter Two?
- [ ] **Watch at least one person play** without helping. Note every pause, wrong tap and question.
  It's the most useful feedback you'll get.

### Message to testers (template)

> Hey! I'm making a small mystery game for phones: *Echoes of the Forgotten City*. Chapter One takes about
> 20 minutes. You explore an abandoned guildhall, talk to the ghosts and work out why every lamp in the
> city went out.
>
> It's an early test build, so expect rough edges. Please play it without looking anything up, then fill in
> this 2-minute form: [link]. Screenshots of anything odd are very welcome.
>
> Install (Android): open this link on your phone → download the APK → allow the install when asked: [link]

## 7. After the playtest

- [ ] Sort feedback into: **blockers** (crashes, stuck), **confusion** (where people got lost),
  **balance** (too easy or hard), and **polish**.
- [ ] Fix blockers and confusion first, then send `0.1.1` with a higher `version/code` and the same keystore.

## 8. Google Play: privacy (you)

Everything is in [PRIVACY.md](PRIVACY.md): the privacy policy, the Data safety answers and the ads
answers.

- [x] Contact email in `PRIVACY.md`: support@oddlycodes.com.
- [ ] **Privacy policy URL** in Play Console → *App content*: the GitHub link to `PRIVACY.md` on
  `main`. The repository must stay public for Google and players to open it.
- [ ] **Data safety form:** copy the answers from the *Google Play: Data safety answers* section.
- [ ] **Ads:** *Contains ads* No; *Advertising ID* not used.
- [ ] **Target audience:** choose 16 and over. The policy says the game isn't for children under 16,
  and GameAnalytics needs parental consent for players under 16.
- [ ] If you change what the game sends (`autoload/analytics.gd`), update `PRIVACY.md` and the form.
