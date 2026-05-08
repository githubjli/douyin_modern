# AGENTS.md — Meow Media Project Guardrails

## Product Identity
- Product identity is **Meow / Meow Media**.
- Repository naming may contain legacy names, but product-facing work must align to Meow Media.

## Current Information Architecture (IA) Contract
- Bottom navigation IA is:
  - **Home**
  - **Shorts**
  - **+** (center action; opens create sheet)
  - **Membership**
  - **Profile**
- The center **+** is **not** a normal tab page.
- **Home** is a content portal page.
- **Shorts** is the immersive vertical video/short-drama experience.
- **Membership** is a first-class tab.
- **Profile** is the user center.

## UI Style Guide
- For UI work, read `UI_STYLE_GUIDE.md` first.
- Treat Home as the visual baseline.
- Keep the logo size and header placement consistent with Home.

## Prohibited Changes (Unless Explicitly Requested)
Do **not** change the following unless a task explicitly requests it:
- Launcher icons
- iOS/Android project files
- Bundle identifiers / signing settings
- App display name
- Dart package rename
- Native splash

## Shorts Constraint
- Do **not** change `video_player` playback lifecycle unless explicitly tasked.

## Backend Policy
- Do **not** add backend APIs yet.
- Planned backend integration target (later phase): `githubjli/django-auth-core`.

## Change Policy
- Keep changes small, focused, and easy to review.
- Avoid unrelated refactors.

## Testing Policy
- Run before finalizing changes:
  - `flutter analyze`
  - `flutter test`
