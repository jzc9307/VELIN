# Changelog

## [Unreleased]

- Hide VELIN’s Dock/app-switcher and menu-bar icons in hidden mode; restore both when disabled, with keyboard/Finder recovery.
- Animate the eye-button mode change to a slightly smaller assistant, respecting Reduce Motion.

- Add a 140 ms fade/shrink/slide transition for assistant hide and show, with reduced-motion support.
- Add an eye control and dashed border for hidden mode (best-effort capture exclusion).
- Protect rapid visibility toggles from stale animation completions without changing the bar's saved position.

## [0.1.0]

- Introduce the original native VELIN workspace, icon, guided setup, and five-step practice tutorial.
- Connect up to five AI profiles with provider/model selection and macOS Keychain storage.
- Stream responses from OpenAI, Claude, Gemini, OpenRouter, Groq, and compatible local/custom services.
- Listen to microphone and computer audio with on-device Apple speech recognition by default.
- Attach a reviewed screenshot, personalize modes and context, generate notes, and export local session history.
- Add global shortcuts, menu-bar controls, transparent capture-exclusion limitations, and versioned release tools.

### Initial build verification fixes

- Keep workspace and assistant windows alive after closing so History, Preferences and app reopen remain safe.
- Preserve saved keys when an editor is reopened or saved with a blank replacement field.
- Keep long errors within the compact bar and collapse empty failed responses.
- Align the compact page header with the native window controls and restore curved sidebar/page seams.
- Use tactile hover/press feedback, VELIN menu-bar controls, Command-arrow movement and a single-instance guard.
