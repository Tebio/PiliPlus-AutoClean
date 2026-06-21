# Fullscreen Clock Overlay

Prepared branch for adding a player fullscreen clock.

Goal:
- Show current time in video fullscreen.
- Works in portrait fullscreen and landscape fullscreen.
- Position: top-left, where the back button normally appears.
- Keep visible when player controls are hidden.
- Hide after leaving fullscreen.
- Do not block player gestures.
- Add settings for enable, font size, and style.

Notes:
- Existing player header code already has a clock mixin.
- A standalone overlay above the player is preferred because header controls can be hidden.
- Some simple files were written successfully on this branch.
- Larger source patches were blocked by the ChatGPT GitHub writer, so Codex should finish the source edits.

Suggested files:
- lib/utils/storage_key.dart
- lib/utils/storage_pref.dart
- lib/pages/setting/models/play_settings.dart
- lib/pages/video/view.dart

Validation:
- Run flutter analyze.
- Test fullscreen portrait, fullscreen landscape, hidden controls, and fullscreen exit.
